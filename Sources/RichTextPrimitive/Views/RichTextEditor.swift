import DragAndDropPrimitive
import SpellCheckKit
import SwiftUI

public struct RichTextEditor: View {
    @Bindable private var state: RichTextState
    @StateObject private var blockNavigator = RichTextBlockNavigatorController()
    private let dataSource: any RichTextDataSource
    private let styleSheet: TextStyleSheet
    private let spellChecker: (any SpellChecker)?
    private let showsBlockNavigator: Bool

    public init(
        state: RichTextState,
        dataSource: any RichTextDataSource,
        styleSheet: TextStyleSheet = .standard,
        spellChecker: (any SpellChecker)? = SystemSpellChecker(),
        showsBlockNavigator: Bool = false
    ) {
        self.state = state
        self.dataSource = dataSource
        self.styleSheet = styleSheet
        self.spellChecker = spellChecker
        self.showsBlockNavigator = showsBlockNavigator
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if showsBlockNavigator {
                RichTextBlockNavigator(
                    controller: blockNavigator,
                    focusedBlockID: state.focusedBlockID,
                    onSelect: focusBlock
                )
            }

            PlatformRichTextViewRepresentable(
                state: state,
                dataSource: dataSource,
                styleSheet: styleSheet,
                spellIssues: state.spellIssues
            )
        }
        .task(id: blockNavigatorTaskID) {
            if showsBlockNavigator {
                blockNavigator.bind(to: dataSource)
            } else {
                blockNavigator.unbind()
            }
        }
        .onDisappear {
            blockNavigator.unbind()
        }
        .task(id: spellCheckTaskID) {
            guard let spellChecker else {
                await MainActor.run {
                    state.clearSpellChecking()
                }
                return
            }
            await state.refreshSpellChecking(dataSource: dataSource, checker: spellChecker)
        }
    }

    private var spellCheckTaskID: String {
        [
            state.isSpellCheckingEnabled.description,
            state.spellCheckLanguage,
            dataSource.blocks.map { block in
                "\(block.id.rawValue):\(spellCheckText(for: block) ?? "")"
            }.joined(separator: "\u{1F}")
        ].joined(separator: "|")
    }

    private var blockNavigatorTaskID: String {
        "\(showsBlockNavigator)-\(ObjectIdentifier(dataSource))"
    }

    private func focusBlock(_ blockID: BlockID) {
        state.focusedBlockID = blockID
        state.selection = .caret(blockID, offset: 0)
    }

    private func spellCheckText(for block: Block) -> String? {
        switch block.content {
        case let .text(content),
             let .heading(content, _),
             let .blockQuote(content),
             let .list(content, _, _):
            content.plainText
        case .codeBlock, .table, .image, .divider, .embed:
            nil
        }
    }
}
