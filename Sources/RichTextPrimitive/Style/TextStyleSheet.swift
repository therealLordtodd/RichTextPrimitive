import Foundation
import Observation
import TypographyPrimitive

@MainActor
@Observable
public final class TextStyleSheet {
    public var defaultStyle: ParagraphStyle
    public var headingStyles: [Int: ParagraphStyle]
    public var blockQuoteStyle: ParagraphStyle
    public var codeBlockStyle: ParagraphStyle
    public var listStyles: [ListStyle: ParagraphStyle]
    public var customStyles: [String: ParagraphStyle]

    public init(
        defaultStyle: ParagraphStyle = ParagraphStyle(),
        headingStyles: [Int: ParagraphStyle] = [
            1: ParagraphStyle(fontSize: 30, fontWeight: .bold, paragraphSpacing: 14),
            2: ParagraphStyle(fontSize: 24, fontWeight: .bold, paragraphSpacing: 12),
            3: ParagraphStyle(fontSize: 20, fontWeight: .semibold, paragraphSpacing: 10),
            4: ParagraphStyle(fontSize: 18, fontWeight: .semibold, paragraphSpacing: 10),
            5: ParagraphStyle(fontSize: 16, fontWeight: .medium, paragraphSpacing: 8),
            6: ParagraphStyle(fontSize: 14, fontWeight: .medium, paragraphSpacing: 8),
        ],
        blockQuoteStyle: ParagraphStyle = ParagraphStyle(indent: 20),
        codeBlockStyle: ParagraphStyle = ParagraphStyle(fontFamily: "Menlo", fontSize: 13),
        listStyles: [ListStyle: ParagraphStyle] = [
            .bullet: ParagraphStyle(firstLineIndent: 9, indent: 18),
            .numbered: ParagraphStyle(firstLineIndent: 9, indent: 18),
            .checklist: ParagraphStyle(firstLineIndent: 9, indent: 18),
        ],
        customStyles: [String: ParagraphStyle] = [:]
    ) {
        self.defaultStyle = defaultStyle
        self.headingStyles = headingStyles
        self.blockQuoteStyle = blockQuoteStyle
        self.codeBlockStyle = codeBlockStyle
        self.listStyles = listStyles
        self.customStyles = customStyles
    }

    public func headingStyle(level: Int) -> ParagraphStyle {
        headingStyles[level] ?? defaultStyle
    }

    public func style(for block: Block) -> ParagraphStyle {
        switch block.content {
        case let .heading(_, level):
            headingStyle(level: level)
        case .blockQuote:
            blockQuoteStyle
        case .codeBlock:
            codeBlockStyle
        case let .list(_, style, _):
            listStyles[style] ?? defaultStyle
        default:
            defaultStyle
        }
    }

    public static var standard: TextStyleSheet {
        TextStyleSheet()
    }
}
