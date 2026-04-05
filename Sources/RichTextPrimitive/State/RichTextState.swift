import CoreGraphics
import Foundation
import Observation
import UndoPrimitive

@MainActor
@Observable
public final class RichTextState {
    public var selection: TextSelection
    public var activeAttributes: TextAttributes
    public var findState: FindReplaceState?
    public var writingMode: any WritingMode
    public var focusedBlockID: BlockID?
    public var zoomLevel: CGFloat

    private var undoObserverID: UUID?

    public init(
        selection: TextSelection = .blockSelection([]),
        activeAttributes: TextAttributes = .plain,
        findState: FindReplaceState? = nil,
        writingMode: any WritingMode = StandardMode(),
        focusedBlockID: BlockID? = nil,
        zoomLevel: CGFloat = 1.0
    ) {
        self.selection = selection
        self.activeAttributes = activeAttributes
        self.findState = findState
        self.writingMode = writingMode
        self.focusedBlockID = focusedBlockID
        self.zoomLevel = zoomLevel
    }

    public func connectUndo(
        stack: UndoStack<[Block]>,
        dataSource: any RichTextDataSource
    ) {
        if let undoObserverID {
            dataSource.removeMutationObserver(undoObserverID)
        }

        undoObserverID = dataSource.addMutationObserver { mutation in
            let description = switch mutation {
            case .blocksInserted:
                "Insert Blocks"
            case .blocksDeleted:
                "Delete Blocks"
            case .blocksMoved:
                "Move Blocks"
            case .blockReplaced:
                "Replace Block"
            case .textUpdated:
                "Edit Text"
            case .typeChanged:
                "Change Block Type"
            case .batchUpdate:
                "Batch Update"
            }
            stack.push(dataSource.blocks, description: description)
        }
    }
}
