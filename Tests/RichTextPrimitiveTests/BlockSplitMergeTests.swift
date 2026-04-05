import Foundation
import Testing
@testable import RichTextPrimitive

@Suite("BlockSplitMerge Tests")
struct BlockSplitMergeTests {
    @Test func splitParagraphCreatesTrailingParagraph() {
        let service = BlockSplitMerge()
        let block = Block(id: "a", type: .paragraph, content: .text(.plain("HelloWorld")))

        let result = service.split(block: block, at: 5)

        #expect(result.leading.content.textContent?.plainText == "Hello")
        #expect(result.trailing.type == .paragraph)
        #expect(result.trailing.content.textContent?.plainText == "World")
    }

    @Test func mergeParagraphsCombinesText() {
        let service = BlockSplitMerge()
        let merged = service.merge(
            previous: Block(id: "a", type: .paragraph, content: .text(.plain("Hello "))),
            next: Block(id: "b", type: .paragraph, content: .text(.plain("World")))
        )

        #expect(merged?.content.textContent?.plainText == "Hello World")
    }
}
