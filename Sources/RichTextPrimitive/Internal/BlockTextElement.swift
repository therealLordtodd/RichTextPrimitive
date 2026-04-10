#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

final class BlockTextElement: NSTextParagraph {
    let blockID: BlockID
    let blockType: BlockType
    let metadata: BlockMetadata

    init(
        blockID: BlockID,
        blockType: BlockType,
        metadata: BlockMetadata,
        attributedString: NSAttributedString
    ) {
        self.blockID = blockID
        self.blockType = blockType
        self.metadata = metadata
        super.init(attributedString: attributedString)
    }

}
