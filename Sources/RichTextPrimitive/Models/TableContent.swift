import CoreGraphics
import Foundation

public struct TableContent: Codable, Sendable, Equatable {
    public var rows: [[TextContent]]
    public var columnWidths: [CGFloat]?
    public var caption: TextContent?

    public init(
        rows: [[TextContent]],
        columnWidths: [CGFloat]? = nil,
        caption: TextContent? = nil
    ) {
        self.rows = rows
        self.columnWidths = columnWidths
        self.caption = caption
    }
}
