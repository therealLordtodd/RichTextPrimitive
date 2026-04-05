import Foundation
import Testing
@testable import RichTextPrimitive
@testable import RichTextPrimitiveAI

@Suite("RichTextPrimitiveAI Tests")
struct AIToolTests {
    @Test func contextStoresSelectionAndBlocks() {
        let context = DocumentAIContext(
            blocks: [Block(id: "a", type: .paragraph, content: .text(.plain("Hello")))],
            selection: .caret("a", offset: 2),
            focusedBlockID: "a",
            documentTitle: "Draft"
        )

        #expect(context.blocks.count == 1)
        #expect(context.focusedBlockID == "a")
        #expect(context.documentTitle == "Draft")
    }

    @Test func toolExecutesClosure() async throws {
        let tool = DocumentAITool(
            id: "rewrite",
            name: "Rewrite",
            description: "Rewrite selected text",
            scope: .selection
        ) { context in
            let blockID = context.focusedBlockID ?? "unknown"
            return [.replaceText(blockID: blockID, content: .plain("Rewritten"))]
        }

        let mutations = try await tool.execute(
            context: DocumentAIContext(
                blocks: [],
                focusedBlockID: "block-1"
            )
        )

        #expect(mutations == [.replaceText(blockID: "block-1", content: .plain("Rewritten"))])
    }
}
