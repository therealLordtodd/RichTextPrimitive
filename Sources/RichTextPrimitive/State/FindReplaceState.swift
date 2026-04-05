import Foundation
import Observation

@MainActor
@Observable
public final class FindReplaceState {
    public var query: String
    public var replacement: String
    public var isCaseSensitive: Bool
    public var isWholeWordsOnly: Bool
    public var matches: [TextSelection]
    public var currentMatchIndex: Int?

    public init(
        query: String = "",
        replacement: String = "",
        isCaseSensitive: Bool = false,
        isWholeWordsOnly: Bool = false,
        matches: [TextSelection] = [],
        currentMatchIndex: Int? = nil
    ) {
        self.query = query
        self.replacement = replacement
        self.isCaseSensitive = isCaseSensitive
        self.isWholeWordsOnly = isWholeWordsOnly
        self.matches = matches
        self.currentMatchIndex = currentMatchIndex
    }

    public var matchCount: Int {
        matches.count
    }

    public var currentMatch: TextSelection? {
        guard let currentMatchIndex, matches.indices.contains(currentMatchIndex) else { return nil }
        return matches[currentMatchIndex]
    }
}
