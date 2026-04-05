import Foundation
import Observation

@MainActor
public protocol RichTextDataSource: AnyObject, Observable {
    var blocks: [Block] { get }

    func block(at index: Int) -> Block
    func insertBlocks(_ blocks: [Block], at index: Int)
    func deleteBlocks(at indices: IndexSet)
    func moveBlocks(from source: IndexSet, to destination: Int)
    func replaceBlock(at index: Int, with block: Block)

    func updateTextContent(blockID: BlockID, content: TextContent)
    func updateBlockType(blockID: BlockID, type: BlockType, content: BlockContent)

    func addMutationObserver(_ observer: @escaping @MainActor (RichTextMutation) -> Void) -> UUID
    func removeMutationObserver(_ id: UUID)
}
