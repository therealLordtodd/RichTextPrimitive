import CoreGraphics
import Foundation

public struct ImageContent: Codable, Sendable, Equatable {
    public var imageID: UUID
    public var url: URL?
    public var data: Data?
    public var altText: String?
    public var size: CGSize?

    public init(
        imageID: UUID = UUID(),
        url: URL? = nil,
        data: Data? = nil,
        altText: String? = nil,
        size: CGSize? = nil
    ) {
        self.imageID = imageID
        self.url = url
        self.data = data
        self.altText = altText
        self.size = size
    }
}
