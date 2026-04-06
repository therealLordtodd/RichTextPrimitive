#if canImport(AppKit)
import AppKit
import SwiftUI

final class PlatformRichTextView: NSScrollView, NSTextViewDelegate {
    private let editorTextView = NSTextView()
    private var bridge: RichTextContentBridge?
    private weak var state: RichTextState?
    private weak var observedDataSource: (any RichTextDataSource)?
    private var mutationObserverID: UUID?
    private var isApplyingUpdate = false

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
        documentView = editorTextView
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        state: RichTextState,
        dataSource: any RichTextDataSource,
        styleSheet: TextStyleSheet
    ) {
        self.state = state

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
        editorTextView.textStorage?.setAttributedString(bridge.cachedAttributedString)

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
}

struct PlatformRichTextViewRepresentable: NSViewRepresentable {
    var state: RichTextState
    let dataSource: any RichTextDataSource
    let styleSheet: TextStyleSheet

    func makeNSView(context: Context) -> PlatformRichTextView {
        let view = PlatformRichTextView()
        view.configure(state: state, dataSource: dataSource, styleSheet: styleSheet)
        return view
    }

    func updateNSView(_ nsView: PlatformRichTextView, context: Context) {
        nsView.configure(state: state, dataSource: dataSource, styleSheet: styleSheet)
    }
}
#endif
