import CoreGraphics
import Foundation
import Observation
import SpellCheckKit
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
    public var isSpellCheckingEnabled: Bool
    public var spellCheckLanguage: String
    public var spellIssues: [RichTextSpellIssue]

    private var undoObserverID: UUID?
    private weak var undoDataSource: (any RichTextDataSource)?
    private weak var undoStack: UndoStack<[Block]>?
    private var undoStackObservationToken: UndoObservationToken?
    private var isApplyingUndoSnapshot = false
    private let spellCheckingService = SpellCheckingService()

    public init(
        selection: TextSelection = .blockSelection([]),
        activeAttributes: TextAttributes = .plain,
        findState: FindReplaceState? = nil,
        writingMode: any WritingMode = StandardMode(),
        focusedBlockID: BlockID? = nil,
        zoomLevel: CGFloat = 1.0,
        isSpellCheckingEnabled: Bool = true,
        spellCheckLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"
    ) {
        self.selection = selection
        self.activeAttributes = activeAttributes
        self.findState = findState
        self.writingMode = writingMode
        self.focusedBlockID = focusedBlockID
        self.zoomLevel = zoomLevel
        self.isSpellCheckingEnabled = isSpellCheckingEnabled
        self.spellCheckLanguage = spellCheckLanguage
        self.spellIssues = []
    }

    public func connectUndo(
        stack: UndoStack<[Block]>,
        dataSource: any RichTextDataSource
    ) {
        disconnectUndo()

        undoDataSource = dataSource
        undoStack = stack

        undoObserverID = dataSource.addMutationObserver { [weak self, weak stack, weak dataSource] mutation in
            guard let self, let stack, let dataSource, !self.isApplyingUndoSnapshot else { return }
            stack.push(dataSource.blocks, description: Self.undoDescription(for: mutation))
        }

        undoStackObservationToken = stack.observe { [weak self, weak dataSource, weak stack] in
            guard let self, let dataSource, let stack else { return }
            self.applyUndoSnapshot(stack.currentState, to: dataSource)
        }
    }

    public func disconnectUndo() {
        if let undoObserverID {
            undoDataSource?.removeMutationObserver(undoObserverID)
            self.undoObserverID = nil
        }

        if let undoStackObservationToken {
            undoStack?.removeObservation(undoStackObservationToken)
            self.undoStackObservationToken = nil
        }

        undoDataSource = nil
        undoStack = nil
        isApplyingUndoSnapshot = false
    }

    public func refreshSpellChecking(
        dataSource: any RichTextDataSource,
        checker: any SpellChecker
    ) async {
        guard isSpellCheckingEnabled else {
            spellIssues = []
            return
        }

        spellIssues = await spellCheckingService.issues(
            in: dataSource.blocks,
            language: spellCheckLanguage,
            checker: checker
        )
    }

    public func clearSpellChecking() {
        spellIssues = []
    }

    private func applyUndoSnapshot(
        _ snapshot: [Block],
        to dataSource: any RichTextDataSource
    ) {
        guard dataSource.blocks != snapshot else { return }

        isApplyingUndoSnapshot = true
        if !dataSource.blocks.isEmpty {
            dataSource.deleteBlocks(at: IndexSet(0..<dataSource.blocks.count))
        }
        if !snapshot.isEmpty {
            dataSource.insertBlocks(snapshot, at: 0)
        }
        isApplyingUndoSnapshot = false
    }

    private static func undoDescription(for mutation: RichTextMutation) -> String {
        switch mutation {
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
    }
}
