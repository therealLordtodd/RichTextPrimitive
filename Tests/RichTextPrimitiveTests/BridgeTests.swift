import Foundation
import Testing
@testable import RichTextPrimitive
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
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

        let bridge = RichTextContentBridge(dataSource: dataSource)
        bridge.applyBlocks(dataSource.blocks)

        #expect(bridge.cachedAttributedString.string == "Title\nBody")
        #expect(bridge.blockPosition(forCharacterOffset: 0)?.blockID == "a")
        #expect(bridge.blockPosition(forCharacterOffset: 6)?.blockID == "b")

        let range = try! #require(bridge.textRange(for: "b", offset: 2))
        let rangeStart = try! #require(bridge.blockPosition(for: range.location))
        #expect(rangeStart.blockID == "b")
        #expect(rangeStart.offset == 2)
    }

    @Test func editedTextRoundTripsBackIntoBlocks() {
        let dataSource = ArrayRichTextDataSource(
            blocks: [
                Block(id: "a", type: .paragraph, content: .text(.plain("First"))),
                Block(id: "b", type: .paragraph, content: .text(.plain("Second"))),
            ]
        )

        let bridge = RichTextContentBridge(dataSource: dataSource)
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

        let bridge = RichTextContentBridge(dataSource: dataSource)
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

        let bridge = RichTextContentBridge(dataSource: dataSource)
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

        let bridge = RichTextContentBridge(dataSource: dataSource)
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

        let bridge = RichTextContentBridge(dataSource: dataSource)
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

        let bridge = RichTextContentBridge(dataSource: dataSource)
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
#endif
