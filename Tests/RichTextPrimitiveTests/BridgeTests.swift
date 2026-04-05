import Foundation
import Testing
@testable import RichTextPrimitive

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
}
