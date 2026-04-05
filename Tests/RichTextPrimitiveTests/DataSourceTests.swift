import Foundation
import Testing
@testable import RichTextPrimitive

@MainActor
@Suite("RichTextPrimitive Data Source Tests")
struct DataSourceTests {
    @Test func crudOperationsMutateBackingArray() {
        let dataSource = ArrayRichTextDataSource(
            blocks: [
                Block(id: "a", type: .paragraph, content: .text(.plain("First"))),
            ]
        )

        dataSource.insertBlocks([Block(id: "b", type: .paragraph, content: .text(.plain("Second")))], at: 1)
        #expect(dataSource.blocks.count == 2)

        dataSource.updateTextContent(blockID: "a", content: .plain("Updated"))
        #expect(dataSource.blocks[0].content.textContent?.plainText == "Updated")

        dataSource.moveBlocks(from: IndexSet(integer: 0), to: 1)
        #expect(dataSource.blocks[1].id == "a")

        dataSource.deleteBlocks(at: IndexSet(integer: 0))
        #expect(dataSource.blocks.count == 1)
    }

    @Test func observersReceiveMutations() {
        let dataSource = ArrayRichTextDataSource()
        var mutations: [RichTextMutation] = []

        let observerID = dataSource.addMutationObserver { mutation in
            mutations.append(mutation)
        }

        dataSource.insertBlocks([Block(id: "x", type: .paragraph, content: .text(.plain("Hello")))], at: 0)
        dataSource.updateBlockType(blockID: "x", type: .heading, content: .heading(.plain("Hello"), level: 1))
        dataSource.removeMutationObserver(observerID)
        dataSource.deleteBlocks(at: IndexSet(integer: 0))

        #expect(mutations.count == 2)
        #expect(mutations[0] == .blocksInserted(indices: IndexSet(integer: 0)))
    }
}
