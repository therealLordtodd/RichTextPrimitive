import Foundation

public struct EmbedContent: Codable, Sendable, Equatable {
    public var kind: String
    public var payload: String?
    public var metadata: [String: MetadataValue]

    public init(
        kind: String,
        payload: String? = nil,
        metadata: [String: MetadataValue] = [:]
    ) {
        self.kind = kind
        self.payload = payload
        self.metadata = metadata
    }
}
