import Foundation
import Testing
@testable import RichTextPrimitive

@Suite("RichTextPrimitive Block Model Tests")
struct BlockModelTests {
    @Test func blockIDSupportsStringLiteral() {
        let id: BlockID = "intro"
        #expect(id.rawValue == "intro")
    }

    @Test func textAttributesDefaultValues() {
        let attributes = TextAttributes()
        #expect(attributes.bold == false)
        #expect(attributes.italic == false)
        #expect(attributes.underline == false)
        #expect(attributes.strikethrough == false)
        #expect(attributes.code == false)
        #expect(attributes.fontSize == nil)
    }

    @Test func blockContentCasesCarryAssociatedValues() {
        let heading = BlockContent.heading(.plain("Title"), level: 2)
        let list = BlockContent.list(.plain("Item"), style: .bullet, indentLevel: 1)

        if case let .heading(content, level) = heading {
            #expect(content.plainText == "Title")
            #expect(level == 2)
        } else {
            Issue.record("Expected heading case")
        }

        if case let .list(content, style, indentLevel) = list {
            #expect(content.plainText == "Item")
            #expect(style == .bullet)
            #expect(indentLevel == 1)
        } else {
            Issue.record("Expected list case")
        }
    }

    @Test func codableRoundTripForCompositeBlock() throws {
        let block = Block(
            id: "block-1",
            type: .image,
            content: .image(ImageContent(altText: "Cover")),
            metadata: BlockMetadata(custom: [
                "featured": .bool(true),
                "priority": .int(3),
            ])
        )

        let data = try JSONEncoder().encode(block)
        let decoded = try JSONDecoder().decode(Block.self, from: data)

        #expect(decoded == block)
    }

    @Test func textContentNormalizesAdjacentRuns() {
        let content = TextContent(
            runs: [
                TextRun(text: "Hel", attributes: .plain),
                TextRun(text: "lo", attributes: .plain),
            ]
        )

        #expect(content.runs.count == 1)
        #expect(content.plainText == "Hello")
    }

    @Test func textContentSlicingPreservesFormattingAcrossRuns() {
        let content = TextContent(
            runs: [
                TextRun(text: "Bold", attributes: TextAttributes(bold: true)),
                TextRun(text: "Plain", attributes: .plain),
            ]
        )

        let sliced = content.sliced(2..<7)

        #expect(sliced.plainText == "ldPla")
        #expect(sliced.runs.count == 2)
        #expect(sliced.runs[0].attributes.bold)
        #expect(sliced.runs[1].attributes == .plain)
    }
}
