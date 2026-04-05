import Foundation

public enum InlineTextAttribute: Sendable {
    case bold
    case italic
    case underline
    case strikethrough
    case code
    case superscript
    case `subscript`
}

public struct TextFormatting: Sendable {
    public init() {}

    public func apply(
        _ attribute: InlineTextAttribute,
        value: Bool,
        to content: TextContent,
        range: Range<Int>
    ) -> TextContent {
        var fragments = content.characters
        let lower = min(max(range.lowerBound, 0), fragments.count)
        let upper = min(max(range.upperBound, lower), fragments.count)

        for index in lower..<upper {
            set(attribute, value: value, on: &fragments[index].attributes)
        }

        return TextContent(characters: fragments)
    }

    public func toggle(
        _ attribute: InlineTextAttribute,
        in content: TextContent,
        range: Range<Int>
    ) -> TextContent {
        let fragments = content.characters
        let lower = min(max(range.lowerBound, 0), fragments.count)
        let upper = min(max(range.upperBound, lower), fragments.count)
        guard lower < upper else { return content }

        let shouldEnable = fragments[lower..<upper].contains { fragment in
            !value(of: attribute, in: fragment.attributes)
        }

        return apply(attribute, value: shouldEnable, to: content, range: range)
    }

    public func setLink(
        _ link: URL?,
        to content: TextContent,
        range: Range<Int>
    ) -> TextContent {
        var fragments = content.characters
        let lower = min(max(range.lowerBound, 0), fragments.count)
        let upper = min(max(range.upperBound, lower), fragments.count)

        for index in lower..<upper {
            fragments[index].attributes.link = link
        }

        return TextContent(characters: fragments)
    }

    private func value(of attribute: InlineTextAttribute, in attributes: TextAttributes) -> Bool {
        switch attribute {
        case .bold:
            attributes.bold
        case .italic:
            attributes.italic
        case .underline:
            attributes.underline
        case .strikethrough:
            attributes.strikethrough
        case .code:
            attributes.code
        case .superscript:
            attributes.superscript
        case .subscript:
            attributes.`subscript`
        }
    }

    private func set(_ attribute: InlineTextAttribute, value: Bool, on attributes: inout TextAttributes) {
        switch attribute {
        case .bold:
            attributes.bold = value
        case .italic:
            attributes.italic = value
        case .underline:
            attributes.underline = value
        case .strikethrough:
            attributes.strikethrough = value
        case .code:
            attributes.code = value
        case .superscript:
            attributes.superscript = value
            if value { attributes.`subscript` = false }
        case .subscript:
            attributes.`subscript` = value
            if value { attributes.superscript = false }
        }
    }
}
