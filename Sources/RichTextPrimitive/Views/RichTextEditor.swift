import SpellCheckKit
import SwiftUI

public struct RichTextEditor: View {
    @Bindable private var state: RichTextState
    private let dataSource: any RichTextDataSource
    private let styleSheet: TextStyleSheet
    private let spellChecker: (any SpellChecker)?

    public init(
        state: RichTextState,
        dataSource: any RichTextDataSource,
        styleSheet: TextStyleSheet = .standard,
        spellChecker: (any SpellChecker)? = SystemSpellChecker()
    ) {
        self.state = state
        self.dataSource = dataSource
        self.styleSheet = styleSheet
        self.spellChecker = spellChecker
    }

    public var body: some View {
        PlatformRichTextViewRepresentable(
            state: state,
            dataSource: dataSource,
            styleSheet: styleSheet,
            spellIssues: state.spellIssues
        )
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
