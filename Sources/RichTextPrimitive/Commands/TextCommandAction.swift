import Foundation

public enum TextCommandAction: Sendable, Equatable {
    case toggleBold
    case toggleItalic
    case toggleUnderline
    case indent
    case outdent
    case changeBlockType(BlockType)
    case insertBlock(BlockType)
    case custom(String)
}
