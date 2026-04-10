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
}
