import Foundation

public enum RichTextMutation: Sendable, Equatable {
    case blocksInserted(indices: IndexSet)
    case blocksDeleted(indices: IndexSet)
    case blocksMoved(from: IndexSet, to: Int)
    case blockReplaced(index: Int)
    case textUpdated(blockID: BlockID)
    case typeChanged(blockID: BlockID)
    case batchUpdate
}
