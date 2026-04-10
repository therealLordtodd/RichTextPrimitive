#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

final class AttachmentBlockElement: NSTextElement {
    let blockID: BlockID
    let blockContent: BlockContent

    init(blockID: BlockID, blockContent: BlockContent) {
        self.blockID = blockID
        self.blockContent = blockContent
        super.init(textContentManager: nil)
    }
}
