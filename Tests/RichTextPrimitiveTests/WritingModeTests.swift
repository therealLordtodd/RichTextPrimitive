import Foundation
import Testing
@testable import RichTextPrimitive

@Suite("WritingMode Tests")
struct WritingModeTests {
    @Test func standardModeSupportsAllBlockTypes() {
        let mode = StandardMode()
        #expect(mode.availableBlockTypes == BlockType.allCases)
    }

    @Test func standardModeDefaultsToParagraph() {
        let mode = StandardMode()
        #expect(mode.defaultBlockType(after: .heading, metadata: BlockMetadata()) == .paragraph)
    }
}
