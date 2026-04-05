#if canImport(AppKit)
import AppKit
private typealias PlatformFont = NSFont
private typealias PlatformColor = NSColor
#elseif canImport(UIKit)
import UIKit
private typealias PlatformFont = UIFont
private typealias PlatformColor = UIColor
#endif
import Foundation
import ColorPickerPrimitive

@MainActor
final class RichTextContentBridge {
    let dataSource: any RichTextDataSource
    let textContentStorage: NSTextContentStorage

    private(set) var blockRanges: [BlockID: Range<Int>] = [:]
    private(set) var cachedAttributedString = NSAttributedString(string: "")

    init(dataSource: any RichTextDataSource) {
        self.dataSource = dataSource
        self.textContentStorage = NSTextContentStorage()
        applyBlocks(dataSource.blocks)
    }

    func applyBlocks(_ blocks: [Block]) {
        var ranges: [BlockID: Range<Int>] = [:]
        let attributed = NSMutableAttributedString()
        var location = 0

        for (index, block) in blocks.enumerated() {
            let blockString = Self.attributedText(for: block)
            attributed.append(blockString)
            let blockLength = blockString.string.count
            ranges[block.id] = location..<(location + blockLength)
            location += blockLength

            if index < blocks.count - 1 {
                attributed.append(NSAttributedString(string: "\n"))
                location += 1
            }
        }

        cachedAttributedString = attributed
        blockRanges = ranges
    }

    func processEditing(in range: NSTextRange, delta: Int) {
        _ = range
        _ = delta
    }

    func processAttributedText(_ attributedText: NSAttributedString) {
        let rebuiltBlocks = Self.blocks(from: attributedText.string, preserving: dataSource.blocks)
        syncDataSource(with: rebuiltBlocks)
        applyBlocks(dataSource.blocks)
    }

    func textRange(for blockID: BlockID, offset: Int) -> NSTextRange? {
        _ = blockID
        _ = offset
        return nil
    }

    func blockPosition(for location: NSTextLocation) -> TextPosition? {
        _ = location
        return nil
    }

    func blockPosition(forCharacterOffset offset: Int) -> TextPosition? {
        for (blockID, range) in blockRanges.sorted(by: { $0.value.lowerBound < $1.value.lowerBound }) {
            if range.contains(offset) {
                return TextPosition(blockID: blockID, offset: offset - range.lowerBound)
            }
        }

        if let last = blockRanges.max(by: { $0.value.upperBound < $1.value.upperBound }) {
            return TextPosition(blockID: last.key, offset: max(offset - last.value.lowerBound, 0))
        }

        return nil
    }

    func characterOffset(for blockID: BlockID, offset: Int) -> Int? {
        guard let range = blockRanges[blockID] else { return nil }
        return min(range.lowerBound + max(offset, 0), range.upperBound)
    }

    private func syncDataSource(with blocks: [Block]) {
        if !dataSource.blocks.isEmpty {
            dataSource.deleteBlocks(at: IndexSet(0..<dataSource.blocks.count))
        }
        if !blocks.isEmpty {
            dataSource.insertBlocks(blocks, at: 0)
        }
    }

    private static func blocks(from plainText: String, preserving existingBlocks: [Block]) -> [Block] {
        let lines = plainText.components(separatedBy: "\n")
        return lines.enumerated().map { index, line in
            let existingBlock = existingBlocks.indices.contains(index) ? existingBlocks[index] : nil
            return block(from: line, existing: existingBlock)
        }
    }

    private static func block(from line: String, existing: Block?) -> Block {
        guard let existing else {
            return Block(type: .paragraph, content: .text(.plain(line)))
        }

        let content = rebuildContent(for: line, existing: existing)
        return Block(id: existing.id, type: existing.type, content: content, metadata: existing.metadata)
    }

    private static func rebuildContent(for line: String, existing: Block) -> BlockContent {
        switch existing.content {
        case .text:
            return .text(TextContent.plain(line))
        case let .heading(_, level):
            return .heading(TextContent.plain(line), level: level)
        case .blockQuote:
            return .blockQuote(TextContent.plain(line))
        case let .codeBlock(_, language):
            return .codeBlock(code: line, language: language)
        case let .list(_, style, indentLevel):
            return .list(TextContent.plain(line), style: style, indentLevel: indentLevel)
        case let .table(table):
            return .table(
                TableContent(
                    rows: table.rows,
                    columnWidths: table.columnWidths,
                    caption: TextContent.plain(line)
                )
            )
        case let .image(image):
            var updatedImage = image
            updatedImage.altText = line.isEmpty ? image.altText : line
            return .image(updatedImage)
        case .divider:
            return .divider
        case let .embed(embed):
            return .embed(EmbedContent(kind: embed.kind, payload: line, metadata: embed.metadata))
        }
    }

    private static func attributedText(for block: Block) -> NSAttributedString {
        switch block.content {
        case let .text(content),
             let .heading(content, _),
             let .blockQuote(content),
             let .list(content, _, _):
            return attributedText(for: content)
        case let .codeBlock(code, _):
            return NSAttributedString(string: code)
        case let .table(content):
            let rendered = content.rows
                .map { row in row.map(\.plainText).joined(separator: " | ") }
                .joined(separator: "\n")
            return NSAttributedString(string: rendered)
        case let .image(content):
            return NSAttributedString(string: content.altText ?? "[Image]")
        case .divider:
            return NSAttributedString(string: "—")
        case let .embed(content):
            return NSAttributedString(string: content.payload ?? "[\(content.kind)]")
        }
    }

    private static func attributedText(for content: TextContent) -> NSAttributedString {
        let attributed = NSMutableAttributedString()
        for run in content.runs {
            attributed.append(
                NSAttributedString(
                    string: run.text,
                    attributes: attributes(for: run.attributes)
                )
            )
        }
        return attributed
    }

    private static func attributes(for textAttributes: TextAttributes) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [:]
        attributes[.font] = font(for: textAttributes)

        if textAttributes.underline {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        if textAttributes.strikethrough {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        if let link = textAttributes.link {
            attributes[.link] = link
        }
        if let color = textAttributes.color {
            attributes[.foregroundColor] = platformColor(from: color)
        }
        if let color = textAttributes.highlightColor {
            attributes[.backgroundColor] = platformColor(from: color)
        }

        return attributes
    }

    private static func font(for textAttributes: TextAttributes) -> PlatformFont {
        let size = textAttributes.fontSize ?? 14

        #if canImport(AppKit)
        let base = textAttributes.fontFamily.flatMap { NSFont(name: $0, size: size) } ?? NSFont.systemFont(ofSize: size)
        if textAttributes.bold {
            return NSFont.boldSystemFont(ofSize: size)
        }
        if textAttributes.italic {
            return NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask)
        }
        return base
        #else
        if textAttributes.bold {
            return UIFont.boldSystemFont(ofSize: size)
        }
        if textAttributes.italic {
            return UIFont.italicSystemFont(ofSize: size)
        }
        return textAttributes.fontFamily.flatMap { UIFont(name: $0, size: size) } ?? UIFont.systemFont(ofSize: size)
        #endif
    }

    private static func platformColor(from value: ColorValue) -> PlatformColor {
        let converted = value.converted(to: ColorSpace.sRGB)
        #if canImport(AppKit)
        return PlatformColor(
            red: converted.red,
            green: converted.green,
            blue: converted.blue,
            alpha: converted.alpha
        )
        #else
        return PlatformColor(
            red: converted.red,
            green: converted.green,
            blue: converted.blue,
            alpha: converted.alpha
        )
        #endif
    }
}
