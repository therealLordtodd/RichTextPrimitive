import Foundation

final class AttachmentBlockElement: NSObject {
    let blockID: BlockID
    let blockContent: BlockContent

    init(blockID: BlockID, blockContent: BlockContent) {
        self.blockID = blockID
        self.blockContent = blockContent
    }
}
