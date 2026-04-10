#if canImport(UIKit)
import SwiftUI
import UIKit

final class PlatformRichTextView: UITextView, UITextViewDelegate {
    private var bridge: RichTextContentBridge?
    private weak var editorState: RichTextState?
    private weak var observedDataSource: (any RichTextDataSource)?
    private var mutationObserverID: UUID?
    private var isApplyingUpdate = false

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
