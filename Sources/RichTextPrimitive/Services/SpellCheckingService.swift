import Foundation
import SpellCheckKit

public struct SpellCheckingService: Sendable {
    public init() {}

    public func issues(
        in blocks: [Block],
        language: String,
        checker: any SpellChecker
    ) async -> [RichTextSpellIssue] {
        var resolvedIssues: [RichTextSpellIssue] = []

        for block in blocks {
            guard let text = spellCheckText(for: block), !text.isEmpty else { continue }
            let issues = await checker.check(text, language: language)

            resolvedIssues.append(
                contentsOf: issues.map { issue in
                    RichTextSpellIssue(
                        id: issue.id,
                        blockID: block.id,
                        range: integerRange(for: issue.range, in: text),
                        type: issue.type,
                        message: issue.message,
                        suggestions: issue.suggestions,
                        word: issue.word(in: text)
                    )
                }
            )
        }

        return resolvedIssues
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

    private func integerRange(
        for range: Range<String.Index>,
        in text: String
    ) -> Range<Int> {
        let lower = text.distance(from: text.startIndex, to: range.lowerBound)
        let upper = text.distance(from: text.startIndex, to: range.upperBound)
        return lower..<upper
    }
}
