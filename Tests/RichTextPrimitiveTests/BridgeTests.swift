import Foundation
import SpellCheckKit
import Testing
@testable import RichTextPrimitive
import ColorPickerPrimitive
#if canImport(AppKit)
import AppKit
private typealias TestPlatformFont = NSFont
private typealias TestPlatformColor = NSColor
#elseif canImport(UIKit)
import UIKit
private typealias TestPlatformFont = UIFont
private typealias TestPlatformColor = UIColor
#endif

@MainActor
@Suite("RichTextContentBridge Tests")
struct BridgeTests {
    @Test func bridgeBuildsJoinedDocumentString() {
        let dataSource = ArrayRichTextDataSource(
            blocks: [
                Block(id: "a", type: .heading, content: .heading(.plain("Title"), level: 1)),
                Block(id: "b", type: .paragraph, content: .text(.plain("Body"))),
            ]
        )

        let bridge = RichTextContentBridge(dataSource: dataSource, styleSheet: .standard)
        bridge.applyBlocks(dataSource.blocks)

        #expect(bridge.cachedAttributedString.string == "Title\nBody")
        #expect(bridge.blockPosition(forCharacterOffset: 0)?.blockID == "a")
        #expect(bridge.blockPosition(forCharacterOffset: 6)?.blockID == "b")

        let range = try! #require(bridge.textRange(for: "b", offset: 2))
        let rangeStart = try! #require(bridge.blockPosition(for: range.location))
        #expect(rangeStart.blockID == "b")
        #expect(rangeStart.offset == 2)
    }

    @Test func blockBoundaryPositionsStayAnchoredToExpectedBlockEdges() {
        let dataSource = ArrayRichTextDataSource(
            blocks: [
                Block(id: "a", type: .paragraph, content: .text(.plain("Alpha"))),
                Block(id: "b", type: .paragraph, content: .text(.plain("Beta"))),
            ]
        )

        let bridge = RichTextContentBridge(dataSource: dataSource, styleSheet: .standard)

        let endOfFirstBlock = try! #require(bridge.blockPosition(forCharacterOffset: 5))
        #expect(endOfFirstBlock.blockID == "a")
        #expect(endOfFirstBlock.offset == 5)

        let startOfSecondBlock = try! #require(bridge.blockPosition(forCharacterOffset: 6))
        #expect(startOfSecondBlock.blockID == "b")
        #expect(startOfSecondBlock.offset == 0)

        let clampedPastDocumentEnd = try! #require(bridge.blockPosition(forCharacterOffset: 99))
        #expect(clampedPastDocumentEnd.blockID == "b")
        #expect(clampedPastDocumentEnd.offset == 4)
    }

    @Test func textRangeRoundTripsAtEndOfNonFinalBlock() {
        let dataSource = ArrayRichTextDataSource(
            blocks: [
                Block(id: "a", type: .paragraph, content: .text(.plain("Alpha"))),
                Block(id: "b", type: .paragraph, content: .text(.plain("Beta"))),
            ]
        )

        let bridge = RichTextContentBridge(dataSource: dataSource, styleSheet: .standard)
        let range = try! #require(bridge.textRange(for: "a", offset: 5))
        let resolved = try! #require(bridge.blockPosition(for: range.location))

        #expect(resolved.blockID == "a")
        #expect(resolved.offset == 5)
    }

    @Test func editedTextRoundTripsBackIntoBlocks() {
        let dataSource = ArrayRichTextDataSource(
            blocks: [
                Block(id: "a", type: .paragraph, content: .text(.plain("First"))),
                Block(id: "b", type: .paragraph, content: .text(.plain("Second"))),
            ]
        )

        let bridge = RichTextContentBridge(dataSource: dataSource, styleSheet: .standard)
        bridge.processAttributedText(NSAttributedString(string: "Alpha\nBeta\nGamma"))

        #expect(dataSource.blocks.count == 3)
        #expect(dataSource.blocks[0].id == "a")
        #expect(dataSource.blocks[0].content.textContent?.plainText == "Alpha")
        #expect(dataSource.blocks[2].content.textContent?.plainText == "Gamma")
    }

    @Test func insertedParagraphBreakPreservesFollowingBlockIdentity() {
        let dataSource = ArrayRichTextDataSource(
            blocks: [
                Block(
                    id: "a",
                    type: .paragraph,
                    content: .text(.plain("Alpha")),
                    metadata: BlockMetadata(custom: ["origin": .string("lead")])
                ),
                Block(
                    id: "b",
                    type: .heading,
                    content: .heading(.plain("Beta"), level: 2),
                    metadata: BlockMetadata(custom: ["origin": .string("title")])
                ),
            ]
        )

        let bridge = RichTextContentBridge(dataSource: dataSource, styleSheet: .standard)
        let attributed = NSMutableAttributedString(attributedString: bridge.cachedAttributedString)
        let insertedAttributes = attributed.attributes(at: 0, effectiveRange: nil)
        attributed.insert(NSAttributedString(string: "\nGamma", attributes: insertedAttributes), at: 5)

        bridge.processAttributedText(attributed)

        #expect(dataSource.blocks.count == 3)
        #expect(dataSource.blocks[0].id == "a")
        #expect(dataSource.blocks[0].metadata.custom["origin"] == .string("lead"))
        #expect(dataSource.blocks[1].id != "a")
        #expect(dataSource.blocks[1].id != "b")
        #expect(dataSource.blocks[1].type == .paragraph)
        #expect(dataSource.blocks[1].content.textContent?.plainText == "Gamma")
        #expect(dataSource.blocks[1].metadata.custom["origin"] == .string("lead"))
        #expect(dataSource.blocks[2].id == "b")
        #expect(dataSource.blocks[2].type == .heading)
        #expect(dataSource.blocks[2].content.textContent?.plainText == "Beta")
        #expect(dataSource.blocks[2].metadata.custom["origin"] == .string("title"))
    }

    @Test func deletedParagraphBreakPreservesLaterBlockIdentity() {
        let dataSource = ArrayRichTextDataSource(
            blocks: [
                Block(id: "a", type: .paragraph, content: .text(.plain("Alpha"))),
                Block(id: "b", type: .heading, content: .heading(.plain("Beta"), level: 2)),
                Block(
                    id: "c",
                    type: .paragraph,
                    content: .text(.plain("Gamma")),
                    metadata: BlockMetadata(custom: ["tail": .bool(true)])
                ),
            ]
        )

        let bridge = RichTextContentBridge(dataSource: dataSource, styleSheet: .standard)
        let attributed = NSMutableAttributedString(attributedString: bridge.cachedAttributedString)
        attributed.deleteCharacters(in: NSRange(location: 5, length: 1))

        bridge.processAttributedText(attributed)

        #expect(dataSource.blocks.count == 2)
        #expect(dataSource.blocks[0].id == "a")
        #expect(dataSource.blocks[0].content.textContent?.plainText == "AlphaBeta")
        #expect(dataSource.blocks[1].id == "c")
        #expect(dataSource.blocks[1].content.textContent?.plainText == "Gamma")
        #expect(dataSource.blocks[1].metadata.custom["tail"] == .bool(true))
    }

    @Test func editedAttributedTextPreservesInlineFormatting() {
        let dataSource = ArrayRichTextDataSource(
            blocks: [
                Block(id: "a", type: .paragraph, content: .text(.plain("First"))),
            ]
        )

        let bridge = RichTextContentBridge(dataSource: dataSource, styleSheet: .standard)
        let attributed = NSMutableAttributedString()
        attributed.append(
            NSAttributedString(
                string: "Bold",
                attributes: [
                    .font: boldFont(ofSize: 15),
                    .foregroundColor: platformColor(red: 1, green: 0, blue: 0),
                ]
            )
        )
        attributed.append(
            NSAttributedString(
                string: " Link",
                attributes: [
                    .font: italicFont(ofSize: 13),
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .link: URL(string: "https://example.com")!,
                ]
            )
        )

        bridge.processAttributedText(attributed)

        let runs = dataSource.blocks[0].content.textContent?.runs ?? []
        #expect(runs.count == 2)
        #expect(runs[0].text == "Bold")
        #expect(runs[0].attributes.bold)
        #expect(runs[0].attributes.color != nil)
        #expect(runs[1].text == " Link")
        #expect(runs[1].attributes.italic)
        #expect(runs[1].attributes.underline)
        #expect(runs[1].attributes.link?.absoluteString == "https://example.com")
    }

    @Test func multilineCodeBlockRoundTripsAsSingleBlock() {
        let dataSource = ArrayRichTextDataSource(
            blocks: [
                Block(
                    id: "code",
                    type: .codeBlock,
                    content: .codeBlock(code: "let a = 1\nlet b = 2", language: "swift")
                ),
            ]
        )

        let bridge = RichTextContentBridge(dataSource: dataSource, styleSheet: .standard)
        bridge.processAttributedText(bridge.cachedAttributedString)

        #expect(dataSource.blocks.count == 1)
        if case let .codeBlock(code, language) = dataSource.blocks[0].content {
            #expect(code == "let a = 1\nlet b = 2")
            #expect(language == "swift")
        } else {
            Issue.record("Expected code block content")
        }
    }

    @Test func tableCaptionEditsPreserveTableRows() {
        let dataSource = ArrayRichTextDataSource(
            blocks: [
                Block(
                    id: "table",
                    type: .table,
                    content: .table(
                        TableContent(
                            rows: [[.plain("Q1"), .plain("100")]],
                            columnWidths: [120, 80],
                            caption: .plain("Revenue")
                        )
                    )
                ),
            ]
        )

        let bridge = RichTextContentBridge(dataSource: dataSource, styleSheet: .standard)
        bridge.processAttributedText(NSAttributedString(string: "Updated Revenue"))

        #expect(dataSource.blocks.count == 1)
        if case let .table(table) = dataSource.blocks[0].content {
            #expect(table.rows == [[.plain("Q1"), .plain("100")]])
            #expect(table.columnWidths == [120, 80])
            #expect(table.caption == .plain("Updated Revenue"))
        } else {
            Issue.record("Expected table content")
        }
    }

    @Test func styleSheetAppliesBlockDefaultsWithoutPersistingInlineOverrides() {
        let styleSheet = TextStyleSheet(
            defaultStyle: ParagraphStyle(fontFamily: "Helvetica", fontSize: 15, textColor: ColorValue(red: 0.2, green: 0.2, blue: 0.2)),
            headingStyles: [
                1: ParagraphStyle(
                    fontFamily: "Helvetica",
                    fontSize: 32,
                    fontWeight: .bold,
                    paragraphSpacing: 18,
                    textColor: ColorValue(red: 0.8, green: 0.1, blue: 0.1)
                ),
            ]
        )
        let dataSource = ArrayRichTextDataSource(
            blocks: [
                Block(id: "heading", type: .heading, content: .heading(.plain("Styled"), level: 1)),
            ]
        )

        let bridge = RichTextContentBridge(dataSource: dataSource, styleSheet: styleSheet)
        let attributes = bridge.cachedAttributedString.attributes(at: 0, effectiveRange: nil)
        let font = try! #require(attributes[.font] as? TestPlatformFont)
        let color = try! #require(attributes[.foregroundColor] as? TestPlatformColor)
        let paragraphStyle = try! #require(attributes[.paragraphStyle] as? NSParagraphStyle)

        #expect(abs(font.pointSize - 32) < 0.1)
        #expect(isBold(font))
        #expect(platformColorValue(color) == ColorValue(red: 0.8, green: 0.1, blue: 0.1))
        #expect(abs(paragraphStyle.paragraphSpacing - 18) < 0.1)

        bridge.processAttributedText(bridge.cachedAttributedString)

        let run = try! #require(dataSource.blocks[0].content.textContent?.runs.first)
        #expect(run.attributes == .plain)
    }

    @Test func spellCheckOverlaysDoNotPersistAsInlineFormatting() {
        let dataSource = ArrayRichTextDataSource(
            blocks: [
                Block(id: "a", type: .paragraph, content: .text(.plain("teh word"))),
            ]
        )
        let bridge = RichTextContentBridge(dataSource: dataSource, styleSheet: .standard)
        let issue = RichTextSpellIssue(
            blockID: "a",
            range: 0..<3,
            type: .spelling,
            message: "Possible misspelling: teh",
            suggestions: ["the"],
            word: "teh"
        )

        let rendered = bridge.attributedString(spellIssues: [issue])
        #expect(rendered.attribute(.underlineStyle, at: 0, effectiveRange: nil) != nil)

        bridge.processAttributedText(rendered)

        let run = try! #require(dataSource.blocks[0].content.textContent?.runs.first)
        #expect(run.text == "teh word")
        #expect(!run.attributes.underline)
    }
}

#if canImport(AppKit)
private func boldFont(ofSize size: CGFloat) -> NSFont {
    NSFont.boldSystemFont(ofSize: size)
}

private func italicFont(ofSize size: CGFloat) -> NSFont {
    NSFontManager.shared.convert(NSFont.systemFont(ofSize: size), toHaveTrait: .italicFontMask)
}

private func platformColor(red: CGFloat, green: CGFloat, blue: CGFloat) -> NSColor {
    NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1)
}

private func isBold(_ font: NSFont) -> Bool {
    NSFontManager.shared.traits(of: font).contains(.boldFontMask)
}

private func platformColorValue(_ color: NSColor) -> ColorValue? {
    guard let converted = color.usingColorSpace(.sRGB) else { return nil }
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    converted.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return ColorValue(red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
}
#elseif canImport(UIKit)
private func boldFont(ofSize size: CGFloat) -> UIFont {
    UIFont.boldSystemFont(ofSize: size)
}

private func italicFont(ofSize size: CGFloat) -> UIFont {
    UIFont.italicSystemFont(ofSize: size)
}

private func platformColor(red: CGFloat, green: CGFloat, blue: CGFloat) -> UIColor {
    UIColor(red: red, green: green, blue: blue, alpha: 1)
}

private func isBold(_ font: UIFont) -> Bool {
    font.fontDescriptor.symbolicTraits.contains(.traitBold)
}

private func platformColorValue(_ color: UIColor) -> ColorValue? {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
    return ColorValue(red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
}
#endif
