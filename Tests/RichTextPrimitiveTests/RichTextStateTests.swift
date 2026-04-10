import Foundation
import Testing
import UndoPrimitive
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

    @Test func connectedUndoStackRestoresDataSourceOnUndoRedo() {
        let original = Block(id: "block-1", type: .paragraph, content: .text(.plain("Original")))
        let dataSource = ArrayRichTextDataSource(blocks: [original])
        let stack = UndoStack(initialState: dataSource.blocks)
        let state = RichTextState()

        state.connectUndo(stack: stack, dataSource: dataSource)
        dataSource.updateTextContent(blockID: "block-1", content: .plain("Edited"))

        #expect(stack.undoCount == 1)
        #expect(stack.undoDescription == "Edit Text")
        #expect(dataSource.blocks.first?.content.textContent?.plainText == "Edited")

        _ = stack.undo()

        #expect(dataSource.blocks == [original])
        #expect(stack.undoCount == 0)
        #expect(stack.redoCount == 1)

        _ = stack.redo()

        #expect(dataSource.blocks.first?.content.textContent?.plainText == "Edited")
        #expect(stack.undoCount == 1)
        #expect(stack.redoCount == 0)
    }

    @Test func reconnectingUndoRemovesOldDataSourceObserver() {
        let oldSource = ArrayRichTextDataSource(
            blocks: [Block(id: "old", type: .paragraph, content: .text(.plain("Old")))]
        )
        let newSource = ArrayRichTextDataSource(
            blocks: [Block(id: "new", type: .paragraph, content: .text(.plain("New")))]
        )
        let oldStack = UndoStack(initialState: oldSource.blocks)
        let newStack = UndoStack(initialState: newSource.blocks)
        let state = RichTextState()

        state.connectUndo(stack: oldStack, dataSource: oldSource)
        state.connectUndo(stack: newStack, dataSource: newSource)

        oldSource.updateTextContent(blockID: "old", content: .plain("Old edited"))
        newSource.updateTextContent(blockID: "new", content: .plain("New edited"))

        #expect(oldStack.undoCount == 0)
        #expect(newStack.undoCount == 1)
    }

    @Test func disconnectUndoStopsRecordingMutations() {
        let dataSource = ArrayRichTextDataSource(
            blocks: [Block(id: "block", type: .paragraph, content: .text(.plain("Start")))]
        )
        let stack = UndoStack(initialState: dataSource.blocks)
        let state = RichTextState()

        state.connectUndo(stack: stack, dataSource: dataSource)
        state.disconnectUndo()
        dataSource.updateTextContent(blockID: "block", content: .plain("Changed"))

        #expect(stack.undoCount == 0)
    }
}
