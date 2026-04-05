import Foundation
import Testing
@testable import RichTextPrimitive

@Suite("ListContinuation Tests")
struct ListContinuationTests {
    @Test func nonEmptyListContinuesSameListStyle() {
        let service = ListContinuation()
        let block = Block(
            type: .list,
            content: .list(.plain("Item"), style: .numbered, indentLevel: 2)
        )

        let result = service.handleEnter(in: block)

        #expect(result?.exitsList == false)
        if case let .list(content, style, indentLevel) = result?.nextBlock.content {
            #expect(content.plainText.isEmpty)
            #expect(style == .numbered)
            #expect(indentLevel == 2)
        } else {
            Issue.record("Expected list continuation block")
        }
    }

    @Test func emptyListExitsToParagraph() {
        let service = ListContinuation()
        let block = Block(type: .list, content: .list(.plain(""), style: .bullet, indentLevel: 0))

        let result = service.handleEnter(in: block)

        #expect(result?.exitsList == true)
        #expect(result?.nextBlock.type == .paragraph)
    }
}
