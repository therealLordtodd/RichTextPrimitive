import Foundation
import Testing
@testable import RichTextPrimitive

@Suite("TextFormatting Tests")
struct TextFormattingTests {
    @Test func toggleBoldAppliesAcrossRange() {
        let formatter = TextFormatting()
        let content = TextContent.plain("Hello")

        let formatted = formatter.toggle(.bold, in: content, range: 0..<5)

        #expect(formatted.runs.count == 1)
        #expect(formatted.runs[0].attributes.bold == true)
    }

    @Test func linkApplicationSplitsRuns() {
        let formatter = TextFormatting()
        let content = TextContent.plain("Hello")
        let url = URL(string: "https://example.com")

        let formatted = formatter.setLink(url, to: content, range: 1..<4)

        #expect(formatted.runs.count == 3)
        #expect(formatted.runs[1].attributes.link == url)
    }
}
