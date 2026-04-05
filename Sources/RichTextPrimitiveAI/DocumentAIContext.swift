import Foundation
import RichTextPrimitive

public struct DocumentAIContext: Sendable, Equatable {
    public var blocks: [Block]
    public var selection: TextSelection?
    public var focusedBlockID: BlockID?
    public var documentTitle: String?

    public init(
        blocks: [Block],
        selection: TextSelection? = nil,
        focusedBlockID: BlockID? = nil,
        documentTitle: String? = nil
    ) {
        self.blocks = blocks
        self.selection = selection
        self.focusedBlockID = focusedBlockID
        self.documentTitle = documentTitle
    }
}
