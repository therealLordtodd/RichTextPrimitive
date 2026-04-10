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
import TypographyPrimitive

@MainActor
final class RichTextContentBridge: NSObject, @preconcurrency NSTextContentStorageDelegate, @preconcurrency NSTextLayoutManagerDelegate {
    private static let internalLineSeparator = "\u{2028}"
    private static let metadataEncoder = JSONEncoder()
    private static let metadataDecoder = JSONDecoder()

    let dataSource: any RichTextDataSource
    let textContentStorage: NSTextContentStorage
    let textLayoutManager: NSTextLayoutManager
    let textContainer: NSTextContainer
    private(set) var styleSheet: TextStyleSheet

    private(set) var blockRanges: [BlockID: Range<Int>] = [:]
    private(set) var cachedAttributedString = NSAttributedString(string: "")

    init(dataSource: any RichTextDataSource, styleSheet: TextStyleSheet) {
        self.dataSource = dataSource
        self.styleSheet = styleSheet
        self.textContentStorage = NSTextContentStorage()
        self.textLayoutManager = NSTextLayoutManager()
        self.textContainer = NSTextContainer(
            size: CGSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        )
        super.init()
        textContentStorage.delegate = self
        textContentStorage.addTextLayoutManager(textLayoutManager)
        textLayoutManager.delegate = self
        textLayoutManager.textContainer = textContainer
        applyBlocks(dataSource.blocks)
    }

    func updateStyleSheet(_ styleSheet: TextStyleSheet) {
        self.styleSheet = styleSheet
    }

    func attachTextLayoutManager(_ layoutManager: NSTextLayoutManager) {
        if layoutManager.textContentManager !== textContentStorage {
            layoutManager.replace(textContentStorage)
        }
        layoutManager.delegate = self
    }

    func applyBlocks(_ blocks: [Block]) {
        var ranges: [BlockID: Range<Int>] = [:]
        let attributed = NSMutableAttributedString()
        var location = 0

        for (index, block) in blocks.enumerated() {
            let blockString = attributedText(for: block)
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
        textContentStorage.attributedString = attributed
    }

    func applyRenderedAttributedString(_ attributedString: NSAttributedString) {
        textContentStorage.attributedString = attributedString
    }

    func processEditing(in range: NSTextRange, delta: Int) {
        _ = range
        _ = delta
        guard let attributedString = textContentStorage.attributedString else { return }
        processAttributedText(attributedString)
    }

    func processAttributedText(_ attributedText: NSAttributedString) {
        let rebuiltBlocks = Self.blocks(
            from: Self.attributedTextByRemovingSpellCheckOverlays(from: attributedText),
            preserving: dataSource.blocks,
            styleSheet: styleSheet
        )
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
        let sortedRanges = blockRanges.sorted(by: { $0.value.lowerBound < $1.value.lowerBound })
        guard let first = sortedRanges.first else { return nil }

        var previous = first
        for entry in sortedRanges {
            let (blockID, range) = entry
            if range.contains(offset) || offset == range.upperBound {
                return TextPosition(
                    blockID: blockID,
                    offset: clampedBlockOffset(for: offset, in: range)
                )
            }

            if offset < range.lowerBound {
                return TextPosition(
                    blockID: previous.key,
                    offset: clampedBlockOffset(for: offset, in: previous.value)
                )
            }

            previous = entry
        }

        return TextPosition(
            blockID: previous.key,
            offset: clampedBlockOffset(for: offset, in: previous.value)
        )
    }

    func characterOffset(for blockID: BlockID, offset: Int) -> Int? {
        guard let range = blockRanges[blockID] else { return nil }
        return min(range.lowerBound + max(offset, 0), range.upperBound)
    }

    func attributedString(spellIssues: [RichTextSpellIssue]) -> NSAttributedString {
        guard !spellIssues.isEmpty else { return cachedAttributedString }

        let attributed = NSMutableAttributedString(attributedString: cachedAttributedString)
        for issue in spellIssues {
            guard let start = characterOffset(for: issue.blockID, offset: issue.range.lowerBound),
                  let end = characterOffset(for: issue.blockID, offset: issue.range.upperBound),
                  end > start,
                  start < attributed.length else { continue }

            let range = NSRange(
                location: start,
                length: min(end, attributed.length) - start
            )
            Self.applySpellCheckOverlay(issue: issue, to: attributed, range: range)
        }

        return attributed
    }

    static func attributedTextByRemovingSpellCheckOverlays(
        from attributedText: NSAttributedString
    ) -> NSAttributedString {
        guard attributedText.length > 0 else { return attributedText }

        let stripped = NSMutableAttributedString(attributedString: attributedText)
        let fullRange = NSRange(location: 0, length: stripped.length)
        stripped.enumerateAttribute(.richTextSpellIssueID, in: fullRange) { value, range, _ in
            guard value != nil else { return }

            if let originalUnderline = stripped.attribute(.richTextOriginalUnderlineStyle, at: range.location, effectiveRange: nil) {
                stripped.addAttribute(.underlineStyle, value: originalUnderline, range: range)
            } else {
                stripped.removeAttribute(.underlineStyle, range: range)
            }

            if let originalUnderlineColor = stripped.attribute(.richTextOriginalUnderlineColor, at: range.location, effectiveRange: nil) {
                stripped.addAttribute(.underlineColor, value: originalUnderlineColor, range: range)
            } else {
                stripped.removeAttribute(.underlineColor, range: range)
            }

            stripped.removeAttribute(.richTextSpellIssueID, range: range)
            stripped.removeAttribute(.richTextOriginalUnderlineStyle, range: range)
            stripped.removeAttribute(.richTextOriginalUnderlineColor, range: range)
        }

        return stripped
    }

    private func clampedBlockOffset(for characterOffset: Int, in range: Range<Int>) -> Int {
        min(max(characterOffset - range.lowerBound, 0), range.count)
    }

    private static func applySpellCheckOverlay(
        issue: RichTextSpellIssue,
        to attributed: NSMutableAttributedString,
        range: NSRange
    ) {
        attributed.enumerateAttributes(in: range) { attributes, subrange, _ in
            var overlay: [NSAttributedString.Key: Any] = [
                .richTextSpellIssueID: issue.id.uuidString,
                .underlineStyle: NSUnderlineStyle.single.rawValue | NSUnderlineStyle.patternDot.rawValue,
                .underlineColor: PlatformColor.systemRed,
            ]

            if let underlineStyle = attributes[.underlineStyle] {
                overlay[.richTextOriginalUnderlineStyle] = underlineStyle
            }
            if let underlineColor = attributes[.underlineColor] {
                overlay[.richTextOriginalUnderlineColor] = underlineColor
            }

            attributed.addAttributes(overlay, range: subrange)
        }
    }

    private func syncDataSource(with blocks: [Block]) {
        if !dataSource.blocks.isEmpty {
            dataSource.deleteBlocks(at: IndexSet(0..<dataSource.blocks.count))
        }
        if !blocks.isEmpty {
            dataSource.insertBlocks(blocks, at: 0)
        }
    }

    func textContentStorage(
        _ textContentStorage: NSTextContentStorage,
        textParagraphWith range: NSRange
    ) -> NSTextParagraph? {
        guard let attributedString = textContentStorage.attributedString,
              attributedString.length > 0,
              range.location < attributedString.length else { return nil }

        let safeLength = min(range.length, attributedString.length - range.location)
        let safeRange = NSRange(location: range.location, length: safeLength)
        let attributes = attributedString.attributes(at: safeRange.location, effectiveRange: nil)
        guard let descriptor = Self.blockDescriptor(from: attributes) else { return nil }

        return BlockTextElement(
            blockID: descriptor.blockID ?? BlockID(UUID().uuidString),
            blockType: descriptor.blockType,
            metadata: descriptor.metadata,
            attributedString: attributedString.attributedSubstring(from: safeRange)
        )
    }

    func textLayoutManager(
        _ textLayoutManager: NSTextLayoutManager,
        textLayoutFragmentFor location: any NSTextLocation,
        in textElement: NSTextElement
    ) -> NSTextLayoutFragment {
        BlockLayoutFragment(textElement: textElement, range: textElement.elementRange)
    }

    private static func blocks(
        from attributedText: NSAttributedString,
        preserving existingBlocks: [Block],
        styleSheet: TextStyleSheet
    ) -> [Block] {
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

                let rebuilt = block(from: line.attributedString, existing: template, styleSheet: styleSheet)
                lastProducedBlockBySourceID[sourceID] = rebuilt

                if occurrence == 0 {
                    return rebuilt
                }

                return Block(type: rebuilt.type, content: rebuilt.content, metadata: rebuilt.metadata)
            }

            if let descriptor {
                return block(from: line.attributedString, descriptor: descriptor, styleSheet: styleSheet)
            }

            return block(
                from: line.attributedString,
                existing: Block(type: .paragraph, content: .text(.plain(""))),
                styleSheet: styleSheet
            )
        }
    }

    private static func block(
        from line: NSAttributedString,
        existing: Block?,
        styleSheet: TextStyleSheet
    ) -> Block {
        guard let existing else {
            let fallback = Block(type: .paragraph, content: .text(.plain("")))
            let content = rebuildContent(for: line, existing: fallback, styleSheet: styleSheet)
            return Block(type: .paragraph, content: content)
        }

        let content = rebuildContent(for: line, existing: existing, styleSheet: styleSheet)
        return Block(id: existing.id, type: existing.type, content: content, metadata: existing.metadata)
    }

    private static func block(
        from line: NSAttributedString,
        descriptor: BlockDescriptor,
        styleSheet: TextStyleSheet
    ) -> Block {
        let template = descriptor.templateBlock
        let content = rebuildContent(for: line, existing: template, styleSheet: styleSheet)
        return Block(type: template.type, content: content, metadata: template.metadata)
    }

    private static func rebuildContent(
        for line: NSAttributedString,
        existing: Block,
        styleSheet: TextStyleSheet
    ) -> BlockContent {
        let textContent = textContent(
            from: line,
            defaultStyle: styleSheet.style(for: existing)
        )
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

    private static func textContent(
        from attributedText: NSAttributedString,
        defaultStyle: ParagraphStyle
    ) -> TextContent {
        guard attributedText.length > 0 else {
            return .plain("")
        }

        var runs: [TextRun] = []
        attributedText.enumerateAttributes(
            in: NSRange(location: 0, length: attributedText.length),
            options: []
        ) { attributes, range, _ in
            let substring = attributedText.attributedSubstring(from: range).string
            runs.append(
                TextRun(
                    text: substring,
                    attributes: textAttributes(from: attributes, defaultStyle: defaultStyle)
                )
            )
        }

        return TextContent(runs: runs)
    }

    private func attributedText(for block: Block) -> NSAttributedString {
        let paragraphStyle = styleSheet.style(for: block)
        let blockAttributes = Self.blockAttributes(for: block, paragraphStyle: paragraphStyle)
        switch block.content {
        case let .text(content),
             let .heading(content, _),
             let .blockQuote(content),
             let .list(content, _, _):
            return Self.attributedText(
                for: content,
                blockAttributes: blockAttributes,
                defaultStyle: paragraphStyle
            )
        case let .codeBlock(code, _):
            return NSAttributedString(
                string: Self.encodeInternalLineSeparators(in: code),
                attributes: blockAttributes
            )
        case let .table(content):
            let rendered = content.caption?.plainText ?? "[Table]"
            return NSAttributedString(string: rendered, attributes: blockAttributes)
        case let .image(content):
            return NSAttributedString(
                string: Self.encodeInternalLineSeparators(in: content.altText ?? "[Image]"),
                attributes: blockAttributes
            )
        case .divider:
            return NSAttributedString(string: "—", attributes: blockAttributes)
        case let .embed(content):
            return NSAttributedString(
                string: Self.encodeInternalLineSeparators(in: content.payload ?? "[\(content.kind)]"),
                attributes: blockAttributes
            )
        }
    }

    private static func attributedText(
        for content: TextContent,
        blockAttributes: [NSAttributedString.Key: Any],
        defaultStyle: ParagraphStyle
    ) -> NSAttributedString {
        let attributed = NSMutableAttributedString()
        for run in content.runs {
            var attributes = attributes(for: run.attributes, defaultStyle: defaultStyle)
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

    private static func attributes(
        for textAttributes: TextAttributes,
        defaultStyle: ParagraphStyle
    ) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [:]
        attributes[.font] = font(for: textAttributes, defaultStyle: defaultStyle)

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
            attributes[.baselineOffset] = (textAttributes.fontSize ?? defaultStyle.fontSize) * 0.35
        }
        if textAttributes.subscript {
            attributes[.baselineOffset] = -((textAttributes.fontSize ?? defaultStyle.fontSize) * 0.2)
        }

        return attributes
    }

    private static func blockAttributes(
        for block: Block,
        paragraphStyle: ParagraphStyle
    ) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .richTextBlockID: block.id.rawValue,
            .richTextBlockType: block.type.rawValue,
            .font: font(for: .plain, defaultStyle: paragraphStyle),
            .paragraphStyle: nsParagraphStyle(from: paragraphStyle),
            .foregroundColor: platformColor(from: paragraphStyle.textColor),
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

    private static func textAttributes(
        from attributes: [NSAttributedString.Key: Any],
        defaultStyle: ParagraphStyle
    ) -> TextAttributes {
        var result = TextAttributes.plain

        if let font = attributes[.font] as? PlatformFont {
            let traits = fontTraits(for: font)
            let familyName = normalizedFontFamilyName(font.familyName)
            if abs(font.pointSize - defaultStyle.fontSize) > 0.1 {
                result.fontSize = font.pointSize
            }
            if !familyName.localizedCaseInsensitiveContains(defaultStyle.fontFamily) {
                result.fontFamily = familyName
            }
            result.bold = traits.bold && !isBoldWeight(defaultStyle.fontWeight)
            result.italic = traits.italic
            result.code = traits.monospace && !familyName.localizedCaseInsensitiveContains(defaultStyle.fontFamily)
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

        if let color = attributes[.foregroundColor] as? PlatformColor,
           let resolvedColor = colorValue(from: color),
           resolvedColor != defaultStyle.textColor {
            result.color = resolvedColor
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

    private static func normalizedFontFamilyName(_ familyName: String?) -> String {
        familyName ?? ""
    }

    private static func font(
        for textAttributes: TextAttributes,
        defaultStyle: ParagraphStyle
    ) -> PlatformFont {
        let size = textAttributes.fontSize ?? defaultStyle.fontSize
        let family = textAttributes.fontFamily ?? defaultStyle.fontFamily
        let wantsBold = textAttributes.bold || isBoldWeight(defaultStyle.fontWeight)
        let wantsItalic = textAttributes.italic
        let wantsCodeFace = textAttributes.code || defaultStyle.fontFamily.localizedCaseInsensitiveContains("mono")

        #if canImport(AppKit)
        let base = NSFont(name: family, size: size)
            ?? (wantsCodeFace
                ? NSFont.monospacedSystemFont(ofSize: size, weight: appKitWeight(for: defaultStyle.fontWeight))
                : NSFont.systemFont(ofSize: size, weight: appKitWeight(for: defaultStyle.fontWeight)))
        var resolved = base
        if wantsCodeFace, !fontTraits(for: resolved).monospace {
            resolved = NSFont.monospacedSystemFont(ofSize: size, weight: appKitWeight(for: defaultStyle.fontWeight))
        }
        if wantsBold {
            resolved = NSFontManager.shared.convert(resolved, toHaveTrait: .boldFontMask)
        }
        if wantsItalic {
            resolved = NSFontManager.shared.convert(resolved, toHaveTrait: .italicFontMask)
        }
        return resolved
        #else
        let descriptor: UIFontDescriptor
        if wantsCodeFace {
            descriptor = UIFont.monospacedSystemFont(ofSize: size, weight: uiKitWeight(for: defaultStyle.fontWeight)).fontDescriptor
        } else if let custom = UIFont(name: family, size: size) {
            descriptor = custom.fontDescriptor
        } else {
            descriptor = UIFont.systemFont(ofSize: size, weight: uiKitWeight(for: defaultStyle.fontWeight)).fontDescriptor
        }
        var traits = descriptor.symbolicTraits
        if wantsBold { traits.insert(.traitBold) }
        if wantsItalic { traits.insert(.traitItalic) }
        if wantsCodeFace { traits.insert(.traitMonoSpace) }
        let resolvedDescriptor = descriptor.withSymbolicTraits(traits) ?? descriptor
        return UIFont(descriptor: resolvedDescriptor, size: size)
        #endif
    }

    private static func nsParagraphStyle(from style: ParagraphStyle) -> NSMutableParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = textAlignment(for: style.alignment)
        paragraphStyle.firstLineHeadIndent = style.firstLineIndent
        paragraphStyle.headIndent = style.indent
        paragraphStyle.paragraphSpacing = style.paragraphSpacing
        paragraphStyle.lineSpacing = max((style.lineSpacing - 1) * style.fontSize, 0)
        return paragraphStyle
    }

    private static func textAlignment(for alignment: TextAlignment) -> NSTextAlignment {
        switch alignment {
        case .leading:
            .left
        case .center:
            .center
        case .trailing:
            .right
        case .justified:
            .justified
        }
    }

    private static func isBoldWeight(_ weight: FontWeight) -> Bool {
        switch weight {
        case .ultraLight, .thin, .light, .regular:
            false
        case .medium, .semibold, .bold, .heavy, .black:
            true
        }
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

    private static func fontTraits(for font: PlatformFont) -> (bold: Bool, italic: Bool, monospace: Bool) {
        #if canImport(AppKit)
        let traits = NSFontManager.shared.traits(of: font)
        return (
            traits.contains(.boldFontMask),
            traits.contains(.italicFontMask),
            traits.contains(.fixedPitchFontMask) || font.fontName.localizedCaseInsensitiveContains("mono")
        )
        #else
        let traits = font.fontDescriptor.symbolicTraits
        return (
            traits.contains(.traitBold),
            traits.contains(.traitItalic),
            traits.contains(.traitMonoSpace) || font.fontName.localizedCaseInsensitiveContains("mono")
        )
        #endif
    }

    #if canImport(AppKit)
    private static func appKitWeight(for weight: FontWeight) -> NSFont.Weight {
        switch weight {
        case .ultraLight:
            .ultraLight
        case .thin:
            .thin
        case .light:
            .light
        case .regular:
            .regular
        case .medium:
            .medium
        case .semibold:
            .semibold
        case .bold:
            .bold
        case .heavy:
            .heavy
        case .black:
            .black
        }
    }
    #else
    private static func uiKitWeight(for weight: FontWeight) -> UIFont.Weight {
        switch weight {
        case .ultraLight:
            .ultraLight
        case .thin:
            .thin
        case .light:
            .light
        case .regular:
            .regular
        case .medium:
            .medium
        case .semibold:
            .semibold
        case .bold:
            .bold
        case .heavy:
            .heavy
        case .black:
            .black
        }
    }
    #endif
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

extension NSAttributedString.Key {
    static let richTextBlockID = NSAttributedString.Key("RichTextPrimitive.blockID")
    static let richTextBlockType = NSAttributedString.Key("RichTextPrimitive.blockType")
    static let richTextBlockMetadata = NSAttributedString.Key("RichTextPrimitive.blockMetadata")
    static let richTextSpellIssueID = NSAttributedString.Key("RichTextPrimitive.spellIssueID")
    static let richTextOriginalUnderlineStyle = NSAttributedString.Key("RichTextPrimitive.originalUnderlineStyle")
    static let richTextOriginalUnderlineColor = NSAttributedString.Key("RichTextPrimitive.originalUnderlineColor")
}
