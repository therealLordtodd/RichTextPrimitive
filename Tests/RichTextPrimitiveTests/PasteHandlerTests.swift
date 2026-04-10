import Foundation
import Testing
@testable import RichTextPrimitive

@Suite("PasteHandler Tests")
struct PasteHandlerTests {
    @Test func htmlParserPreservesMixedBlockOrder() {
        let handler = PasteHandler()
        let blocks = handler.blocks(
            fromHTML: """
            <h1>Title &amp; Terms</h1>
            <p>Intro <strong>copy</strong></p>
            <ol><li>First</li><li>Second</li></ol>
            <blockquote>Quoted text</blockquote>
            <pre>let value = 1</pre>
            <hr>
            """
        )

        #expect(blocks.map(\.type) == [.heading, .paragraph, .list, .list, .blockQuote, .codeBlock, .divider])
        #expect(blocks[0].content.textContent?.plainText == "Title & Terms")
        #expect(blocks[1].content.textContent?.plainText == "Intro copy")
        if case let .list(content, style, _) = blocks[2].content {
            #expect(content.plainText == "First")
            #expect(style == .numbered)
        } else {
            Issue.record("Expected numbered list item")
        }
        #expect(blocks[4].content.textContent?.plainText == "Quoted text")
        if case let .codeBlock(code, _) = blocks[5].content {
            #expect(code == "let value = 1")
        } else {
            Issue.record("Expected code block")
        }
    }

    @Test func htmlParserFallsBackToPlainTextWithLineBreaks() {
        let handler = PasteHandler()
        let blocks = handler.blocks(fromHTML: "Alpha<br>Beta &lt;Gamma&gt;")

        #expect(blocks.count == 2)
        #expect(blocks[0].content.textContent?.plainText == "Alpha")
        #expect(blocks[1].content.textContent?.plainText == "Beta <Gamma>")
    }
}
