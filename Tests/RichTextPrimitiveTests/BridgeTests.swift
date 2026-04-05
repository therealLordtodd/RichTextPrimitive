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
