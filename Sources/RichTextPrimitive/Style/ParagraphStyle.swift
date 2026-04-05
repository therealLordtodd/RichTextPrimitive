import CoreGraphics
import Foundation
import ColorPickerPrimitive
import TypographyPrimitive

public enum TextAlignment: String, Codable, Sendable, CaseIterable {
    case leading
    case center
    case trailing
    case justified
}

public struct ParagraphStyle: Codable, Sendable, Equatable {
    public var fontFamily: String
    public var fontSize: CGFloat
    public var fontWeight: FontWeight
    public var lineSpacing: CGFloat
    public var paragraphSpacing: CGFloat
    public var alignment: TextAlignment
    public var firstLineIndent: CGFloat
    public var indent: CGFloat
    public var textColor: ColorValue

    public init(
        fontFamily: String = "SF Pro",
        fontSize: CGFloat = 14,
        fontWeight: FontWeight = .regular,
        lineSpacing: CGFloat = 1.4,
        paragraphSpacing: CGFloat = 8,
        alignment: TextAlignment = .leading,
        firstLineIndent: CGFloat = 0,
        indent: CGFloat = 0,
        textColor: ColorValue = ColorValue(red: 0, green: 0, blue: 0)
    ) {
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.lineSpacing = lineSpacing
        self.paragraphSpacing = paragraphSpacing
        self.alignment = alignment
        self.firstLineIndent = firstLineIndent
        self.indent = indent
        self.textColor = textColor
    }
}
