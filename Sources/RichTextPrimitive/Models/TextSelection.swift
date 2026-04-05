import Foundation

public enum TextSelection: Codable, Sendable, Equatable {
    case caret(BlockID, offset: Int)
    case range(start: TextPosition, end: TextPosition)
    case blockSelection(Set<BlockID>)
}
