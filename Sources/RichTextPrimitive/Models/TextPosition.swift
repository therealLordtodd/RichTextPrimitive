import Foundation

public struct TextPosition: Codable, Sendable, Equatable {
    public var blockID: BlockID
    public var offset: Int

    public init(blockID: BlockID, offset: Int) {
        self.blockID = blockID
        self.offset = offset
    }
}
