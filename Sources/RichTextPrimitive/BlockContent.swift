import Foundation

public enum BlockContent: Codable, Sendable, Equatable {
    case text(TextContent)
    case heading(TextContent, level: Int)
    case blockQuote(TextContent)
    case codeBlock(code: String, language: String?)
    case list(TextContent, style: ListStyle, indentLevel: Int)
    case table(TableContent)
    case image(ImageContent)
    case divider
    case embed(EmbedContent)

    public var textContent: TextContent? {
        switch self {
        case let .text(content),
             let .heading(content, _),
             let .blockQuote(content),
             let .list(content, _, _):
            return content
        case let .codeBlock(code, _):
            return .plain(code)
        case .table, .image, .divider, .embed:
            return nil
        }
    }
}
