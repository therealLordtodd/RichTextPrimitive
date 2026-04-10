#if canImport(UIKit)
import ClipboardPrimitive
import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class PlatformRichTextView: UITextView, UITextViewDelegate {
    private var bridge: RichTextContentBridge?
    private weak var editorState: RichTextState?
    private weak var observedDataSource: (any RichTextDataSource)?
    private var mutationObserverID: UUID?
    private var isApplyingUpdate = false
    private let clipboardManager = ClipboardManager()
    private let pasteHandler = PasteHandler()

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        delegate = self
        isScrollEnabled = true
        backgroundColor = .clear
        allowsEditingTextAttributes = true
        font = .systemFont(ofSize: 14)
        textContainerInset = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func paste(_ sender: Any?) {
        if shouldCustomHandleOriginalPaste, handlePasteAction(.original) {
            return
        }

        super.paste(sender)
    }

    override func pasteAndMatchStyle(_ sender: Any?) {
        if handlePasteAction(.plainText) {
            return
        }

        super.pasteAndMatchStyle(sender)
    }

    func configure(
        state: RichTextState,
        dataSource: any RichTextDataSource,
        styleSheet: TextStyleSheet,
        spellIssues: [RichTextSpellIssue]
    ) {
        editorState = state
        _ = spellIssues

        if bridge.map({ ObjectIdentifier($0.dataSource as AnyObject) }) != ObjectIdentifier(dataSource as AnyObject) {
            if let observedDataSource, let mutationObserverID {
                observedDataSource.removeMutationObserver(mutationObserverID)
            }
            bridge = RichTextContentBridge(dataSource: dataSource, styleSheet: styleSheet)
            observedDataSource = dataSource
            mutationObserverID = dataSource.addMutationObserver { [weak self] _ in
                guard let self else { return }
                self.syncFromBridge()
            }
        }

        bridge?.updateStyleSheet(styleSheet)
        if let textLayoutManager {
            bridge?.attachTextLayoutManager(textLayoutManager)
        }

        syncFromBridge()
    }

    func textViewDidChange(_ textView: UITextView) {
        guard !isApplyingUpdate, let bridge else { return }
        bridge.processAttributedText(textView.attributedText)
        syncSelectionState()
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        guard !isApplyingUpdate else { return }
        syncSelectionState()
    }

    @available(iOS 16.0, *)
    func textView(
        _ textView: UITextView,
        editMenuForTextIn range: NSRange,
        suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        _ = range
        guard textView === self else {
            return UIMenu(children: suggestedActions)
        }

        let extraActions = pasteSpecialMenuElements()
        guard !extraActions.isEmpty else {
            return UIMenu(children: suggestedActions)
        }

        return UIMenu(
            children: suggestedActions + [
                UIMenu(
                    title: "Paste Special",
                    options: .displayInline,
                    children: extraActions
                ),
            ]
        )
    }

    private func syncFromBridge() {
        guard let bridge else { return }
        isApplyingUpdate = true
        bridge.applyBlocks(bridge.dataSource.blocks)
        let rendered = editorState.map { bridge.attributedString(spellIssues: $0.spellIssues) }
            ?? bridge.cachedAttributedString
        bridge.applyRenderedAttributedString(rendered)

        if textLayoutManager?.textContentManager !== bridge.textContentStorage {
            attributedText = rendered
        }

        if let editorState {
            applySelection(from: editorState)
        }
        isApplyingUpdate = false
    }

    private func applySelection(from state: RichTextState) {
        guard let bridge else { return }
        switch state.selection {
        case let .caret(blockID, offset):
            if let location = bridge.characterOffset(for: blockID, offset: offset) {
                applySelectedRange(NSRange(location: location, length: 0))
            }
        case let .range(start, end):
            if let startLocation = bridge.characterOffset(for: start.blockID, offset: start.offset),
               let endLocation = bridge.characterOffset(for: end.blockID, offset: end.offset) {
                applySelectedRange(
                    NSRange(location: startLocation, length: max(endLocation - startLocation, 0))
                )
            }
        case .blockSelection:
            break
        }
    }

    private func applySelectedRange(_ range: NSRange) {
        selectedRange = range
        scrollRangeToVisible(range)
    }

    private func syncSelectionState() {
        guard let editorState, let bridge else { return }
        guard let start = bridge.blockPosition(forCharacterOffset: selectedRange.location) else { return }

        if selectedRange.length == 0 {
            editorState.selection = .caret(start.blockID, offset: start.offset)
            editorState.focusedBlockID = start.blockID
            return
        }

        if let end = bridge.blockPosition(forCharacterOffset: selectedRange.location + selectedRange.length) {
            editorState.selection = .range(start: start, end: end)
            editorState.focusedBlockID = start.blockID
        }
    }

    private func handlePasteAction(_ format: PasteFormat) -> Bool {
        Task { [weak self] in
            await self?.performCustomPaste(format)
        }
        return true
    }

    private var shouldCustomHandleOriginalPaste: Bool {
        let pasteboard = UIPasteboard.general
        let types = pasteboard.types.compactMap(UTType.init)

        if pasteboard.hasImages || pasteboard.hasURLs {
            return true
        }

        return types.contains(where: { $0.conforms(to: .fileURL) })
    }

    private func pasteSpecialMenuElements() -> [UIMenuElement] {
        let pasteboard = UIPasteboard.general
        guard pasteboard.hasStrings || pasteboard.hasURLs || pasteboard.hasImages || !pasteboard.types.isEmpty else {
            return []
        }

        return [
            UIAction(title: "Markdown") { [weak self] _ in
                _ = self?.handlePasteAction(.markdown)
            },
            UIAction(title: "HTML") { [weak self] _ in
                _ = self?.handlePasteAction(.html)
            },
            UIAction(title: "Rich Text") { [weak self] _ in
                _ = self?.handlePasteAction(.rtf)
            },
            UIAction(title: "CSV") { [weak self] _ in
                _ = self?.handlePasteAction(.csv)
            },
        ]
    }

    private func performCustomPaste(_ format: PasteFormat) async {
        do {
            guard let content = try await clipboardManager.paste(as: format) else {
                return
            }

            let blocks = pasteHandler.blocks(from: content)
            guard !blocks.isEmpty else {
                return
            }

            await MainActor.run { [weak self] in
                self?.insertPastedBlocks(blocks)
            }
        } catch {
            return
        }
    }

    @MainActor
    private func insertPastedBlocks(_ blocks: [Block]) {
        guard let bridge else { return }

        let selectedRange = self.selectedRange
        let fragment = wrappedPasteFragment(
            bridge.attributedString(for: blocks),
            for: blocks,
            replacing: selectedRange
        )

        textStorage.beginEditing()
        textStorage.replaceCharacters(in: selectedRange, with: fragment)
        textStorage.endEditing()

        let insertionLocation = selectedRange.location + fragment.length
        self.selectedRange = NSRange(location: insertionLocation, length: 0)
        scrollRangeToVisible(self.selectedRange)
        textViewDidChange(self)
    }

    @MainActor
    private func wrappedPasteFragment(
        _ fragment: NSAttributedString,
        for blocks: [Block],
        replacing selection: NSRange
    ) -> NSAttributedString {
        guard shouldInsertAsStandaloneBlocks(blocks) else {
            return fragment
        }

        let wrapped = NSMutableAttributedString()
        let boundaryAttributes = boundaryAttributesForSelection(selection)

        if needsLeadingBoundary(before: selection.location) {
            wrapped.append(NSAttributedString(string: "\n", attributes: boundaryAttributes))
        }

        wrapped.append(fragment)

        if needsTrailingBoundary(after: selection.location + selection.length) {
            wrapped.append(NSAttributedString(string: "\n", attributes: boundaryAttributes))
        }

        return wrapped
    }

    private func shouldInsertAsStandaloneBlocks(_ blocks: [Block]) -> Bool {
        blocks.count > 1 || blocks.contains(where: { $0.type != .paragraph })
    }

    @MainActor
    private func needsLeadingBoundary(before location: Int) -> Bool {
        guard location > 0 else { return false }
        let string = textStorage.string as NSString
        return string.substring(with: NSRange(location: location - 1, length: 1)) != "\n"
    }

    @MainActor
    private func needsTrailingBoundary(after location: Int) -> Bool {
        let string = textStorage.string as NSString
        guard location < string.length else { return false }
        return string.substring(with: NSRange(location: location, length: 1)) != "\n"
    }

    @MainActor
    private func boundaryAttributesForSelection(_ selection: NSRange) -> [NSAttributedString.Key: Any] {
        guard textStorage.length > 0 else {
            return typingAttributes
        }

        if selection.location > 0 {
            return textStorage.attributes(at: min(selection.location - 1, textStorage.length - 1), effectiveRange: nil)
        }

        return textStorage.attributes(at: 0, effectiveRange: nil)
    }
}

struct PlatformRichTextViewRepresentable: UIViewRepresentable {
    var state: RichTextState
    let dataSource: any RichTextDataSource
    let styleSheet: TextStyleSheet
    let spellIssues: [RichTextSpellIssue]

    func makeUIView(context: Context) -> PlatformRichTextView {
        let view = PlatformRichTextView()
        view.configure(state: state, dataSource: dataSource, styleSheet: styleSheet, spellIssues: spellIssues)
        return view
    }

    func updateUIView(_ uiView: PlatformRichTextView, context: Context) {
        uiView.configure(state: state, dataSource: dataSource, styleSheet: styleSheet, spellIssues: spellIssues)
    }
}
#endif
