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
    private static let internalLineSeparator = "\u{2028}"
    private static let metadataEncoder = JSONEncoder()
    private static let metadataDecoder = JSONDecoder()

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
        let rebuiltBlocks = Self.blocks(from: attributedText, preserving: dataSource.blocks)
        syncDataSource(with: rebuiltBlocks)
        applyBlocks(dataSource.blocks)
    }

    func textRange(for blockID: BlockID, offset: Int) -> NSTextRange? {
        guard let characterOffset = characterOffset(for: blockID, offset: offset) else { return nil }
        let location = BridgeTextLocation(offset: characterOffset)
        return NSTextRange(location: location, end: location)
    }

    func blockPosition(for location: NSTextLocation) -> TextPosition? {
        guard let location = location as? BridgeTextLocation else { return nil }
        return blockPosition(forCharacterOffset: location.offset)
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

    private static func blocks(from attributedText: NSAttributedString, preserving existingBlocks: [Block]) -> [Block] {
        let existingByID = Dictionary(uniqueKeysWithValues: existingBlocks.map { ($0.id, $0) })
        let lines = attributedLines(from: attributedText)
        var reuseCountBySourceID: [BlockID: Int] = [:]
        var lastProducedBlockBySourceID: [BlockID: Block] = [:]

        return lines.enumerated().map { index, line in
            let descriptor = blockDescriptor(from: line.representativeAttributes)
            let sourceBlock = descriptor?.blockID.flatMap { existingByID[$0] }
                ?? (existingBlocks.indices.contains(index) ? existingBlocks[index] : nil)

            if let sourceBlock {
                let sourceID = descriptor?.blockID ?? sourceBlock.id
                let occurrence = reuseCountBySourceID[sourceID, default: 0]
                reuseCountBySourceID[sourceID] = occurrence + 1

                let template = if occurrence == 0 {
                    sourceBlock
                } else {
                    splitSuccessorTemplate(for: lastProducedBlockBySourceID[sourceID] ?? sourceBlock)
                }

                let rebuilt = block(from: line.attributedString, existing: template)
                lastProducedBlockBySourceID[sourceID] = rebuilt

                if occurrence == 0 {
                    return rebuilt
                }

                return Block(type: rebuilt.type, content: rebuilt.content, metadata: rebuilt.metadata)
            }

            if let descriptor {
                return block(from: line.attributedString, descriptor: descriptor)
            }

            return Block(type: .paragraph, content: .text(textContent(from: line.attributedString)))
        }
    }

    private static func block(from line: NSAttributedString, existing: Block?) -> Block {
        guard let existing else {
            return Block(type: .paragraph, content: .text(textContent(from: line)))
        }

        let content = rebuildContent(for: line, existing: existing)
        return Block(id: existing.id, type: existing.type, content: content, metadata: existing.metadata)
    }

    private static func block(from line: NSAttributedString, descriptor: BlockDescriptor) -> Block {
        let template = descriptor.templateBlock
        let content = rebuildContent(for: line, existing: template)
        return Block(type: template.type, content: content, metadata: template.metadata)
    }

    private static func rebuildContent(for line: NSAttributedString, existing: Block) -> BlockContent {
        let textContent = textContent(from: line)
        let plainLine = line.string
        let decodedLine = decodeInternalLineSeparators(in: plainLine)

        switch existing.content {
        case .text:
            return .text(textContent)
        case let .heading(_, level):
            return .heading(textContent, level: level)
        case .blockQuote:
            return .blockQuote(textContent)
        case let .codeBlock(_, language):
            return .codeBlock(code: decodedLine, language: language)
        case let .list(_, style, indentLevel):
            return .list(textContent, style: style, indentLevel: indentLevel)
        case let .table(table):
            return .table(
                TableContent(
                    rows: table.rows,
                    columnWidths: table.columnWidths,
                    caption: textContent
                )
            )
        case let .image(image):
            var updatedImage = image
            updatedImage.altText = decodedLine.isEmpty ? image.altText : decodedLine
            return .image(updatedImage)
        case .divider:
            return .divider
        case let .embed(embed):
            return .embed(EmbedContent(kind: embed.kind, payload: decodedLine, metadata: embed.metadata))
        }
    }

    private static func attributedLines(from attributedText: NSAttributedString) -> [AttributedLine] {
        let string = attributedText.string as NSString
        guard string.length > 0 else {
            return [AttributedLine(attributedString: NSAttributedString(string: ""), representativeAttributes: [:])]
        }

        var lines: [AttributedLine] = []
        var start = 0

        for location in 0..<string.length where string.character(at: location) == 10 {
            let range = NSRange(location: start, length: location - start)
            lines.append(
                AttributedLine(
                    attributedString: attributedText.attributedSubstring(from: range),
                    representativeAttributes: representativeAttributes(
                        in: attributedText,
                        lineRange: range
                    )
                )
            )
            start = location + 1
        }

        let finalRange = NSRange(location: start, length: string.length - start)
        lines.append(
            AttributedLine(
                attributedString: attributedText.attributedSubstring(from: finalRange),
                representativeAttributes: representativeAttributes(
                    in: attributedText,
                    lineRange: finalRange
                )
            )
        )
        return lines
    }

    private static func textContent(from attributedText: NSAttributedString) -> TextContent {
        guard attributedText.length > 0 else {
            return .plain("")
        }

        var runs: [TextRun] = []
        attributedText.enumerateAttributes(
            in: NSRange(location: 0, length: attributedText.length),
            options: []
        ) { attributes, range, _ in
            let substring = attributedText.attributedSubstring(from: range).string
            runs.append(TextRun(text: substring, attributes: textAttributes(from: attributes)))
        }

        return TextContent(runs: runs)
    }

    private static func attributedText(for block: Block) -> NSAttributedString {
        let blockAttributes = blockAttributes(for: block)
        switch block.content {
        case let .text(content),
             let .heading(content, _),
             let .blockQuote(content),
             let .list(content, _, _):
            return attributedText(for: content, blockAttributes: blockAttributes)
        case let .codeBlock(code, _):
            return NSAttributedString(
                string: encodeInternalLineSeparators(in: code),
                attributes: blockAttributes
            )
        case let .table(content):
            let rendered = content.caption?.plainText ?? "[Table]"
            return NSAttributedString(string: rendered, attributes: blockAttributes)
        case let .image(content):
            return NSAttributedString(
                string: encodeInternalLineSeparators(in: content.altText ?? "[Image]"),
                attributes: blockAttributes
            )
        case .divider:
            return NSAttributedString(string: "—", attributes: blockAttributes)
        case let .embed(content):
            return NSAttributedString(
                string: encodeInternalLineSeparators(in: content.payload ?? "[\(content.kind)]"),
                attributes: blockAttributes
            )
        }
    }

    private static func attributedText(
        for content: TextContent,
        blockAttributes: [NSAttributedString.Key: Any]
    ) -> NSAttributedString {
        let attributed = NSMutableAttributedString()
        for run in content.runs {
            var attributes = attributes(for: run.attributes)
            blockAttributes.forEach { attributes[$0.key] = $0.value }
            attributed.append(
                NSAttributedString(
                    string: run.text,
                    attributes: attributes
                )
            )
        }
        return attributed
    }

    private static func encodeInternalLineSeparators(in string: String) -> String {
        string.replacingOccurrences(of: "\n", with: internalLineSeparator)
    }

    private static func decodeInternalLineSeparators(in string: String) -> String {
        string.replacingOccurrences(of: internalLineSeparator, with: "\n")
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
        if textAttributes.superscript {
            attributes[.baselineOffset] = (textAttributes.fontSize ?? 14) * 0.35
        }
        if textAttributes.subscript {
            attributes[.baselineOffset] = -((textAttributes.fontSize ?? 14) * 0.2)
        }

        return attributes
    }

    private static func blockAttributes(for block: Block) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .richTextBlockID: block.id.rawValue,
            .richTextBlockType: block.type.rawValue,
        ]

        if let metadata = try? metadataEncoder.encode(block.metadata) {
            attributes[.richTextBlockMetadata] = metadata
        }

        return attributes
    }

    private static func representativeAttributes(
        in attributedText: NSAttributedString,
        lineRange: NSRange
    ) -> [NSAttributedString.Key: Any] {
        if lineRange.length > 0 {
            return attributedText.attributes(at: lineRange.location, effectiveRange: nil)
        }

        if lineRange.location > 0 {
            return attributedText.attributes(at: lineRange.location - 1, effectiveRange: nil)
        }

        if attributedText.length > 0 {
            return attributedText.attributes(at: 0, effectiveRange: nil)
        }

        return [:]
    }

    private static func blockDescriptor(from attributes: [NSAttributedString.Key: Any]) -> BlockDescriptor? {
        let blockID = (attributes[.richTextBlockID] as? String).map { BlockID($0) }
        let blockType = (attributes[.richTextBlockType] as? String).flatMap(BlockType.init(rawValue:))
        let metadata: BlockMetadata? = {
            guard let data = attributes[.richTextBlockMetadata] as? Data else { return nil }
            return try? metadataDecoder.decode(BlockMetadata.self, from: data)
        }()

        guard blockID != nil || blockType != nil || metadata != nil else { return nil }
        return BlockDescriptor(
            blockID: blockID,
            blockType: blockType ?? .paragraph,
            metadata: metadata ?? BlockMetadata()
        )
    }

    private static func splitSuccessorTemplate(for block: Block) -> Block {
        switch block.content {
        case .text:
            return Block(type: .paragraph, content: .text(.plain("")), metadata: block.metadata)
        case .heading:
            return Block(type: .paragraph, content: .text(.plain("")))
        case .blockQuote:
            return Block(type: .blockQuote, content: .blockQuote(.plain("")), metadata: block.metadata)
        case let .codeBlock(_, language):
            return Block(type: .codeBlock, content: .codeBlock(code: "", language: language), metadata: block.metadata)
        case let .list(_, style, indentLevel):
            return Block(type: .list, content: .list(.plain(""), style: style, indentLevel: indentLevel), metadata: block.metadata)
        case .table, .image, .divider, .embed:
            return Block(type: .paragraph, content: .text(.plain("")))
        }
    }

    private static func textAttributes(from attributes: [NSAttributedString.Key: Any]) -> TextAttributes {
        var result = TextAttributes.plain

        if let font = attributes[.font] as? PlatformFont {
            result.fontSize = font.pointSize
            result.fontFamily = font.familyName

            #if canImport(AppKit)
            let traits = NSFontManager.shared.traits(of: font)
            result.bold = traits.contains(.boldFontMask)
            result.italic = traits.contains(.italicFontMask)
            result.code = traits.contains(.fixedPitchFontMask) || font.fontName.localizedCaseInsensitiveContains("mono")
            #else
            let traits = font.fontDescriptor.symbolicTraits
            result.bold = traits.contains(.traitBold)
            result.italic = traits.contains(.traitItalic)
            result.code = traits.contains(.traitMonoSpace) || font.fontName.localizedCaseInsensitiveContains("mono")
            #endif
        }

        let underlineStyle = (attributes[.underlineStyle] as? NSNumber)?.intValue ?? (attributes[.underlineStyle] as? Int) ?? 0
        let strikethroughStyle = (attributes[.strikethroughStyle] as? NSNumber)?.intValue ?? (attributes[.strikethroughStyle] as? Int) ?? 0
        result.underline = underlineStyle != 0
        result.strikethrough = strikethroughStyle != 0

        if let link = attributes[.link] as? URL {
            result.link = link
        } else if let link = attributes[.link] as? String {
            result.link = URL(string: link)
        }

        if let color = attributes[.foregroundColor] as? PlatformColor {
            result.color = colorValue(from: color)
        }
        if let color = attributes[.backgroundColor] as? PlatformColor {
            result.highlightColor = colorValue(from: color)
        }

        let baselineOffset = (attributes[.baselineOffset] as? NSNumber)?.doubleValue
            ?? (attributes[.baselineOffset] as? Double)
            ?? 0
        result.superscript = baselineOffset > 0
        result.subscript = baselineOffset < 0

        return result
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

    private static func colorValue(from color: PlatformColor) -> ColorValue? {
        #if canImport(AppKit)
        guard let converted = color.usingColorSpace(.sRGB) else { return nil }
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        converted.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #else
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        #endif

        return ColorValue(
            red: Double(red),
            green: Double(green),
            blue: Double(blue),
            alpha: Double(alpha),
            colorSpace: .sRGB
        )
    }
}

private struct AttributedLine {
    let attributedString: NSAttributedString
    let representativeAttributes: [NSAttributedString.Key: Any]
}

private struct BlockDescriptor {
    let blockID: BlockID?
    let blockType: BlockType
    let metadata: BlockMetadata

    var templateBlock: Block {
        switch blockType {
        case .paragraph:
            Block(type: .paragraph, content: .text(.plain("")), metadata: metadata)
        case .heading:
            Block(type: .heading, content: .heading(.plain(""), level: 1), metadata: metadata)
        case .blockQuote:
            Block(type: .blockQuote, content: .blockQuote(.plain("")), metadata: metadata)
        case .codeBlock:
            Block(type: .codeBlock, content: .codeBlock(code: "", language: nil), metadata: metadata)
        case .list:
            Block(type: .list, content: .list(.plain(""), style: .bullet, indentLevel: 0), metadata: metadata)
        case .table:
            Block(type: .table, content: .table(TableContent(rows: [], caption: .plain(""))), metadata: metadata)
        case .image:
            Block(type: .image, content: .image(ImageContent(altText: "")), metadata: metadata)
        case .divider:
            Block(type: .divider, content: .divider, metadata: metadata)
        case .embed:
            Block(type: .embed, content: .embed(EmbedContent(kind: "embed", payload: "")), metadata: metadata)
        }
    }
}

private final class BridgeTextLocation: NSObject, NSTextLocation {
    let offset: Int

    init(offset: Int) {
        self.offset = offset
    }

    func compare(_ location: any NSTextLocation) -> ComparisonResult {
        guard let other = location as? BridgeTextLocation else {
            return .orderedSame
        }
        if offset < other.offset {
            return .orderedAscending
        }
        if offset > other.offset {
            return .orderedDescending
        }
        return .orderedSame
    }
}

private extension NSAttributedString.Key {
    static let richTextBlockID = NSAttributedString.Key("RichTextPrimitive.blockID")
    static let richTextBlockType = NSAttributedString.Key("RichTextPrimitive.blockType")
    static let richTextBlockMetadata = NSAttributedString.Key("RichTextPrimitive.blockMetadata")
}
