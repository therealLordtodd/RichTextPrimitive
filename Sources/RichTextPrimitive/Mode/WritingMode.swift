import Foundation
import KeyboardShortcutProtocol

public struct ModeKeyboardShortcut: Sendable, Codable, Equatable, Identifiable {
    public var id: String
    public var key: ShortcutKey
    public var modifiers: ShortcutModifiers
    public var commandID: String

    public init(
        id: String,
        key: ShortcutKey,
        modifiers: ShortcutModifiers = .command,
        commandID: String
    ) {
        self.id = id
        self.key = key
        self.modifiers = modifiers
        self.commandID = commandID
    }
}

public protocol WritingMode: Sendable {
    var id: String { get }
    var displayName: String { get }
    var availableBlockTypes: [BlockType] { get }
    func defaultBlockType(after current: BlockType, metadata: BlockMetadata) -> BlockType
    var keyboardShortcuts: [ModeKeyboardShortcut] { get }
    var styleOverrides: TextStyleSheet? { get }
    func metadataForTypeChange(from: BlockType, to: BlockType, existing: BlockMetadata) -> BlockMetadata
}
