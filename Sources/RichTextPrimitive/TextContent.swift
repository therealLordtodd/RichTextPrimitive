import Foundation

internal struct TextCharacterFragment: Equatable, Sendable {
    var text: String
    var attributes: TextAttributes
}

public struct TextContent: Codable, Sendable, Equatable {
    public var runs: [TextRun]

    public init(runs: [TextRun] = []) {
        self.runs = Self.mergedRuns(from: runs)
    }

    public static func plain(_ text: String) -> TextContent {
        TextContent(runs: [TextRun(text: text)])
    }

    public var plainText: String {
        runs.map(\.text).joined()
    }

    public var isEmpty: Bool {
        plainText.isEmpty
    }

    internal var characters: [TextCharacterFragment] {
        runs.flatMap { run in
            run.text.map { character in
                TextCharacterFragment(text: String(character), attributes: run.attributes)
            }
        }
    }

    internal init(characters: [TextCharacterFragment]) {
        self.init(runs: Self.runs(from: characters))
    }

    internal func clampedOffset(_ offset: Int) -> Int {
        min(max(offset, 0), characters.count)
    }

    internal func split(at offset: Int) -> (TextContent, TextContent) {
        let fragments = characters
        let safeOffset = clampedOffset(offset)
        let left = Array(fragments[..<safeOffset])
        let right = Array(fragments[safeOffset...])
        return (TextContent(characters: left), TextContent(characters: right))
    }

    internal func slice(_ range: Range<Int>) -> TextContent {
        let fragments = characters
        let lower = min(max(range.lowerBound, 0), fragments.count)
        let upper = min(max(range.upperBound, lower), fragments.count)
        return TextContent(characters: Array(fragments[lower..<upper]))
    }

    internal func replacing(range: Range<Int>, with replacement: TextContent) -> TextContent {
        let fragments = characters
        let lower = min(max(range.lowerBound, 0), fragments.count)
        let upper = min(max(range.upperBound, lower), fragments.count)
        let newFragments = Array(fragments[..<lower]) + replacement.characters + Array(fragments[upper...])
        return TextContent(characters: newFragments)
    }

    private static func runs(from characters: [TextCharacterFragment]) -> [TextRun] {
        guard !characters.isEmpty else { return [] }

        var result: [TextRun] = []
        var currentText = characters[0].text
        var currentAttributes = characters[0].attributes

        for fragment in characters.dropFirst() {
            if fragment.attributes == currentAttributes {
                currentText += fragment.text
            } else {
                result.append(TextRun(text: currentText, attributes: currentAttributes))
                currentText = fragment.text
                currentAttributes = fragment.attributes
            }
        }

        result.append(TextRun(text: currentText, attributes: currentAttributes))
        return result
    }

    private static func mergedRuns(from runs: [TextRun]) -> [TextRun] {
        guard !runs.isEmpty else { return [] }

        var result: [TextRun] = []
        for run in runs where !run.text.isEmpty || runs.count == 1 {
            if var last = result.last, last.attributes == run.attributes {
                last.text += run.text
                result[result.count - 1] = last
            } else {
                result.append(run)
            }
        }
        return result
    }
}
