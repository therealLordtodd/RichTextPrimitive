import Foundation

public struct BlockMetadata: Codable, Sendable, Equatable {
    public var custom: [String: MetadataValue]

    public init(custom: [String: MetadataValue] = [:]) {
        self.custom = custom
    }
}

public enum MetadataValue: Codable, Sendable, Equatable {
    case string(String)
    case int(Int)
    case bool(Bool)
    case double(Double)
}
