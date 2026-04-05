import Foundation

public enum BlockType: String, Codable, Sendable, CaseIterable {
    case paragraph
    case heading
    case blockQuote
    case codeBlock
    case list
    case table
    case image
    case divider
    case embed
}

public struct BlockID: Sendable, Codable, Hashable, RawRepresentable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public var description: String { rawValue }
}

public struct Block: Identifiable, Codable, Sendable, Equatable {
    public let id: BlockID
    public var type: BlockType
    public var content: BlockContent
    public var metadata: BlockMetadata

    public init(
        id: BlockID = BlockID(UUID().uuidString),
        type: BlockType,
        content: BlockContent,
        metadata: BlockMetadata = BlockMetadata()
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.metadata = metadata
    }
}
