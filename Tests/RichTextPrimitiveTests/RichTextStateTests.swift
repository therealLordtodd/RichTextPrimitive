import Foundation
import Testing
@testable import RichTextPrimitive

@MainActor
@Suite("RichTextState Tests")
struct RichTextStateTests {
    @Test func statePropertiesCanBeUpdated() {
        let state = RichTextState()
        let findState = FindReplaceState(query: "hello", replacement: "world")

        state.findState = findState
        state.focusedBlockID = "block-1"
        state.zoomLevel = 1.25
        state.selection = .caret("block-1", offset: 3)

        #expect(state.findState?.query == "hello")
        #expect(state.focusedBlockID == "block-1")
        #expect(state.zoomLevel == 1.25)
        #expect(state.selection == .caret("block-1", offset: 3))
    }

    @Test func findReplaceStateTracksCurrentMatch() {
        let match = TextSelection.caret("block-1", offset: 1)
        let findState = FindReplaceState(matches: [match], currentMatchIndex: 0)

        #expect(findState.matchCount == 1)
        #expect(findState.currentMatch == match)
    }
}
