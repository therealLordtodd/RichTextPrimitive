import CoreGraphics
import Foundation
import ColorPickerPrimitive

public struct TextAttributes: Codable, Sendable, Equatable {
    public var bold: Bool
    public var italic: Bool
    public var underline: Bool
    public var strikethrough: Bool
    public var code: Bool
    public var link: URL?
    public var color: ColorValue?
    public var highlightColor: ColorValue?
    public var fontSize: CGFloat?
    public var fontFamily: String?
    public var superscript: Bool
    public var `subscript`: Bool

    public init(
        bold: Bool = false,
        italic: Bool = false,
        underline: Bool = false,
        strikethrough: Bool = false,
        code: Bool = false,
        link: URL? = nil,
        color: ColorValue? = nil,
        highlightColor: ColorValue? = nil,
        fontSize: CGFloat? = nil,
        fontFamily: String? = nil,
        superscript: Bool = false,
        subscript: Bool = false
    ) {
        self.bold = bold
        self.italic = italic
        self.underline = underline
        self.strikethrough = strikethrough
        self.code = code
        self.link = link
        self.color = color
        self.highlightColor = highlightColor
        self.fontSize = fontSize
        self.fontFamily = fontFamily
        self.superscript = superscript
        self.`subscript` = `subscript`
    }

    public static let plain = TextAttributes()
}
