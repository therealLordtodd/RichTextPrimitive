import Foundation

final class BlockTextElement: NSObject {
    let blockID: BlockID
    let blockType: BlockType
    let metadata: BlockMetadata

    init(blockID: BlockID, blockType: BlockType, metadata: BlockMetadata) {
        self.blockID = blockID
        self.blockType = blockType
        self.metadata = metadata
    }
}
