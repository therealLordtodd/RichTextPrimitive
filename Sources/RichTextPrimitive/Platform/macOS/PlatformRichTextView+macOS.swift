#if canImport(AppKit)
import AppKit
import ClipboardPrimitive
import SwiftUI
import UniformTypeIdentifiers

private final class RichTextEditorTextView: NSTextView {
    var handlePaste: ((PasteFormat) -> Bool)?

    override func paste(_ sender: Any?) {
        if handlePaste?(.original) == true {
            return
        }

        super.paste(sender)
    }

    override func pasteAsPlainText(_ sender: Any?) {
        if handlePaste?(.plainText) == true {
            return
        }

        super.pasteAsPlainText(sender)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let menu = (super.menu(for: event)?.copy() as? NSMenu) ?? super.menu(for: event) else {
            return nil
        }

        appendPasteSpecialMenu(to: menu)
        return menu
    }

    @objc private func pasteAsMarkdown(_ sender: Any?) {
        _ = sender
        _ = handlePaste?(.markdown)
    }

    @objc private func pasteAsHTML(_ sender: Any?) {
        _ = sender
        _ = handlePaste?(.html)
    }

    @objc private func pasteClipboardAsRichText(_ sender: Any?) {
        _ = sender
        _ = handlePaste?(.rtf)
    }

    @objc private func pasteAsCSV(_ sender: Any?) {
        _ = sender
        _ = handlePaste?(.csv)
    }

    private func appendPasteSpecialMenu(to menu: NSMenu) {
        let submenu = NSMenu(title: "Paste Special")
        submenu.addItem(
            NSMenuItem(
                title: "Markdown",
                action: #selector(pasteAsMarkdown(_:)),
                keyEquivalent: ""
            )
        )
        submenu.addItem(
            NSMenuItem(
                title: "HTML",
                action: #selector(pasteAsHTML(_:)),
                keyEquivalent: ""
            )
        )
        submenu.addItem(
            NSMenuItem(
                title: "Rich Text",
                action: #selector(pasteClipboardAsRichText(_:)),
                keyEquivalent: ""
            )
        )
        submenu.addItem(
            NSMenuItem(
                title: "CSV",
                action: #selector(pasteAsCSV(_:)),
                keyEquivalent: ""
            )
        )

        for item in submenu.items {
            item.target = self
        }

        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(
                title: "Paste Special",
                action: nil,
                keyEquivalent: ""
            )
        )
        menu.item(at: menu.items.count - 1)?.submenu = submenu
    }
}

final class PlatformRichTextView: NSScrollView, NSTextViewDelegate {
    private let editorTextView = RichTextEditorTextView(usingTextLayoutManager: true)
    private var bridge: RichTextContentBridge?
    private weak var state: RichTextState?
    private weak var observedDataSource: (any RichTextDataSource)?
    private var mutationObserverID: UUID?
    private var isApplyingUpdate = false
    private let clipboardManager = ClipboardManager()
    private let pasteHandler = PasteHandler()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        borderType = .noBorder
        drawsBackground = false
        hasVerticalScroller = true
        hasHorizontalScroller = false
        autohidesScrollers = true

        editorTextView.isRichText = true
        editorTextView.allowsUndo = true
        editorTextView.isVerticallyResizable = true
        editorTextView.isHorizontallyResizable = false
        editorTextView.textContainerInset = NSSize(width: 8, height: 8)
        editorTextView.delegate = self
        editorTextView.handlePaste = { [weak self] format in
            self?.handlePasteAction(format) ?? false
        }
        documentView = editorTextView
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        state: RichTextState,
        dataSource: any RichTextDataSource,
        styleSheet: TextStyleSheet,
        spellIssues: [RichTextSpellIssue]
    ) {
        self.state = state
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
        if let textLayoutManager = editorTextView.textLayoutManager {
            bridge?.attachTextLayoutManager(textLayoutManager)
        }

        syncFromBridge()
    }

    func textDidChange(_ notification: Notification) {
        _ = notification
        guard !isApplyingUpdate, let bridge else { return }
        bridge.processAttributedText(editorTextView.attributedString())
        syncSelectionState()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        _ = notification
        guard !isApplyingUpdate else { return }
        syncSelectionState()
    }

    private func syncFromBridge() {
        guard let bridge else { return }

        isApplyingUpdate = true
        bridge.applyBlocks(bridge.dataSource.blocks)
        let rendered = state.map { bridge.attributedString(spellIssues: $0.spellIssues) }
            ?? bridge.cachedAttributedString
        bridge.applyRenderedAttributedString(rendered)

        if editorTextView.textLayoutManager?.textContentManager !== bridge.textContentStorage {
            if let textContentStorage = editorTextView.textContentStorage {
                textContentStorage.attributedString = rendered
            } else {
                editorTextView.textStorage?.setAttributedString(rendered)
            }
        }

        if let state {
            applySelection(from: state)
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
        editorTextView.setSelectedRange(range)
        editorTextView.scrollRangeToVisible(range)
    }

    private func syncSelectionState() {
        guard let state, let bridge else { return }
        let selection = editorTextView.selectedRange()
        guard let start = bridge.blockPosition(forCharacterOffset: selection.location) else { return }

        if selection.length == 0 {
            state.selection = .caret(start.blockID, offset: start.offset)
            state.focusedBlockID = start.blockID
            return
        }

        let endOffset = selection.location + selection.length
        if let end = bridge.blockPosition(forCharacterOffset: endOffset) {
            state.selection = .range(start: start, end: end)
            state.focusedBlockID = start.blockID
        }
    }

    private func handlePasteAction(_ format: PasteFormat) -> Bool {
        switch format {
        case .original:
            guard shouldCustomHandleOriginalPaste else {
                return false
            }
        case .plainText, .markdown, .html, .rtf, .csv:
            break
        }

        Task { [weak self] in
            await self?.performCustomPaste(format)
        }
        return true
    }

    private var shouldCustomHandleOriginalPaste: Bool {
        let pasteboard = NSPasteboard.general

        if let fileURLs = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL],
           !fileURLs.isEmpty {
            return true
        }

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let first = urls.first,
           !first.isFileURL {
            return true
        }

        let types = pasteboard.types?.compactMap { UTType($0.rawValue) } ?? []
        return types.contains(where: { $0.conforms(to: .image) })
    }

    private func performCustomPaste(_ format: PasteFormat) async {
        do {
            guard let content = try await clipboardManager.paste(as: format) else {
                NSSound.beep()
                return
            }

            let blocks = pasteHandler.blocks(from: content)
            guard !blocks.isEmpty else {
                NSSound.beep()
                return
            }

            insertPastedBlocks(blocks)
        } catch {
            NSSound.beep()
        }
    }

    private func insertPastedBlocks(_ blocks: [Block]) {
        guard let bridge else { return }

        let selectedRange = editorTextView.selectedRange()
        let fragment = wrappedPasteFragment(
            bridge.attributedString(for: blocks),
            for: blocks,
            replacing: selectedRange
        )

        if let textStorage = editorTextView.textStorage {
            textStorage.beginEditing()
            textStorage.replaceCharacters(in: selectedRange, with: fragment)
            textStorage.endEditing()
        }

        let insertionLocation = selectedRange.location + fragment.length
        editorTextView.setSelectedRange(NSRange(location: insertionLocation, length: 0))
        editorTextView.didChangeText()
    }

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

    private func needsLeadingBoundary(before location: Int) -> Bool {
        guard location > 0 else { return false }
        let string = editorTextView.string as NSString
        return string.substring(with: NSRange(location: location - 1, length: 1)) != "\n"
    }

    private func needsTrailingBoundary(after location: Int) -> Bool {
        let string = editorTextView.string as NSString
        guard location < string.length else { return false }
        return string.substring(with: NSRange(location: location, length: 1)) != "\n"
    }

    private func boundaryAttributesForSelection(_ selection: NSRange) -> [NSAttributedString.Key: Any] {
        guard let textStorage = editorTextView.textStorage, textStorage.length > 0 else {
            return editorTextView.typingAttributes
        }

        if selection.location > 0 {
            return textStorage.attributes(at: min(selection.location - 1, textStorage.length - 1), effectiveRange: nil)
        }

        return textStorage.attributes(at: 0, effectiveRange: nil)
    }
}

struct PlatformRichTextViewRepresentable: NSViewRepresentable {
    var state: RichTextState
    let dataSource: any RichTextDataSource
    let styleSheet: TextStyleSheet
    let spellIssues: [RichTextSpellIssue]

    func makeNSView(context: Context) -> PlatformRichTextView {
        let view = PlatformRichTextView()
        view.configure(state: state, dataSource: dataSource, styleSheet: styleSheet, spellIssues: spellIssues)
        return view
    }

    func updateNSView(_ nsView: PlatformRichTextView, context: Context) {
        nsView.configure(state: state, dataSource: dataSource, styleSheet: styleSheet, spellIssues: spellIssues)
    }
}
#endif
