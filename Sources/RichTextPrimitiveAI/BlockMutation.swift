import Foundation
import RichTextPrimitive

public enum BlockMutation: Sendable, Equatable {
    case replaceText(blockID: BlockID, content: TextContent)
    case replaceBlock(blockID: BlockID, with: Block)
    case insertAfter(blockID: BlockID, blocks: [Block])
    case deleteBlock(blockID: BlockID)
}
