import Foundation

public struct TextRun: Codable, Sendable, Equatable {
    public var text: String
    public var attributes: TextAttributes

    public init(text: String, attributes: TextAttributes = .plain) {
        self.text = text
        self.attributes = attributes
    }
}
