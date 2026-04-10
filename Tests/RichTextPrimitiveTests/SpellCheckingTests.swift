import Foundation
import SpellCheckKit
import Testing
@testable import RichTextPrimitive

@MainActor
@Suite("SpellChecking Tests")
struct SpellCheckingTests {
    @Test func refreshSpellCheckingMapsIssuesBackToBlocks() async {
        let dataSource = ArrayRichTextDataSource(
            blocks: [
                Block(id: "a", type: .paragraph, content: .text(.plain("This is teh first paragraph."))),
                Block(id: "b", type: .heading, content: .heading(.plain("Anoter title"), level: 1)),
                Block(id: "c", type: .codeBlock, content: .codeBlock(code: "teh code", language: "swift")),
            ]
        )
        let state = RichTextState(spellCheckLanguage: "en")

        await state.refreshSpellChecking(dataSource: dataSource, checker: StubSpellChecker())

        #expect(state.spellIssues.map(\.blockID) == ["a", "b"])
        #expect(state.spellIssues[0].range == 8..<11)
        #expect(state.spellIssues[0].word == "teh")
        #expect(state.spellIssues[0].suggestions == ["the"])
        #expect(state.spellIssues[1].range == 0..<6)
        #expect(state.spellIssues[1].word == "Anoter")
    }

    @Test func disabledSpellCheckingClearsExistingIssues() async {
        let dataSource = ArrayRichTextDataSource(
            blocks: [
                Block(id: "a", type: .paragraph, content: .text(.plain("teh"))),
            ]
        )
        let state = RichTextState()

        await state.refreshSpellChecking(dataSource: dataSource, checker: StubSpellChecker())
        #expect(!state.spellIssues.isEmpty)

        state.isSpellCheckingEnabled = false
        await state.refreshSpellChecking(dataSource: dataSource, checker: StubSpellChecker())

        #expect(state.spellIssues.isEmpty)
    }
}

private struct StubSpellChecker: SpellChecker {
    func check(_ text: String, language: String) async -> [SpellIssue] {
        var issues: [SpellIssue] = []
        if let range = text.range(of: "teh") {
            issues.append(
                SpellIssue(
                    range: range,
                    type: .spelling,
                    message: "Possible misspelling: teh",
                    suggestions: ["the"]
                )
            )
        }
        if let range = text.range(of: "Anoter") {
            issues.append(
                SpellIssue(
                    range: range,
                    type: .spelling,
                    message: "Possible misspelling: Anoter",
                    suggestions: ["Another"]
                )
            )
        }
        return issues
    }

    func suggestions(for word: String, language: String) async -> [String] {
        []
    }

    func learnWord(_ word: String) async {}

    func ignoreWord(_ word: String) async {}
}
