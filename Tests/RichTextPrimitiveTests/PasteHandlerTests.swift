import ClipboardPrimitive
import Foundation
import Testing
@testable import RichTextPrimitive
import UniformTypeIdentifiers

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

    @Test func clipboardHTMLBecomesStructuredBlocks() {
        let handler = PasteHandler()
        let blocks = handler.blocks(
            from: .richText(
                Data("<h2>Heading</h2><p>Body</p>".utf8),
                .html
            )
        )

        #expect(blocks.map(\.type) == [.heading, .paragraph])
        #expect(blocks[0].content.textContent?.plainText == "Heading")
        #expect(blocks[1].content.textContent?.plainText == "Body")
    }

    @Test func clipboardURLBecomesLinkedParagraph() {
        let handler = PasteHandler()
        let url = URL(string: "https://example.com/spec")!
        let blocks = handler.blocks(from: .url(url))

        #expect(blocks.count == 1)
        #expect(blocks[0].type == .paragraph)
        #expect(blocks[0].content.textContent?.plainText == url.absoluteString)
        let run = try! #require(blocks[0].content.textContent?.runs.first)
        #expect(run.attributes.link == url)
    }

    @Test func clipboardFilesMapImagesAndFileLinks() {
        let handler = PasteHandler()
        let imageURL = URL(fileURLWithPath: "/tmp/property-photo.png")
        let documentURL = URL(fileURLWithPath: "/tmp/closing-disclosure.pdf")
        let blocks = handler.blocks(from: .fileURL([imageURL, documentURL]))

        #expect(blocks.count == 2)
        #expect(blocks[0].type == .image)
        if case let .image(content) = blocks[0].content {
            #expect(content.url == imageURL)
            #expect(content.altText == "property-photo")
        } else {
            Issue.record("Expected image block for image file")
        }

        #expect(blocks[1].type == .paragraph)
        #expect(blocks[1].content.textContent?.plainText == "closing-disclosure")
        let run = try! #require(blocks[1].content.textContent?.runs.first)
        #expect(run.attributes.link == documentURL)
    }

    @Test func customBinaryClipboardContentFallsBackToEmbedBlock() {
        let handler = PasteHandler()
        let blocks = handler.blocks(
            from: .custom(Data([0x01, 0x02, 0x03]), UTType(exportedAs: "com.vantage.binary"))
        )

        #expect(blocks.count == 1)
        #expect(blocks[0].type == .embed)
        if case let .embed(content) = blocks[0].content {
            #expect(content.kind == "com.vantage.binary")
            #expect(content.metadata["byteCount"] == .int(3))
        } else {
            Issue.record("Expected embed fallback block")
        }
    }
}
