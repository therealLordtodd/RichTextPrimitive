import Foundation
import SpellCheckKit

public struct RichTextSpellIssue: Identifiable, Sendable, Equatable {
    public var id: UUID
    public var blockID: BlockID
    public var range: Range<Int>
    public var type: IssueType
    public var message: String
    public var suggestions: [String]
    public var word: String

    public init(
        id: UUID = UUID(),
        blockID: BlockID,
        range: Range<Int>,
        type: IssueType,
        message: String,
        suggestions: [String] = [],
        word: String
    ) {
        self.id = id
        self.blockID = blockID
        self.range = range
        self.type = type
        self.message = message
        self.suggestions = suggestions
        self.word = word
    }
}
