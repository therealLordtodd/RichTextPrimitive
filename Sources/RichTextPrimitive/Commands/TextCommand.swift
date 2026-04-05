import Foundation
import KeyboardShortcutProtocol

public struct TextCommand: Identifiable, Sendable, Equatable {
    public let id: String
    public var key: ShortcutKey?
    public var modifiers: ShortcutModifiers
    public var action: TextCommandAction

    public init(
        id: String,
        key: ShortcutKey? = nil,
        modifiers: ShortcutModifiers = .command,
        action: TextCommandAction
    ) {
        self.id = id
        self.key = key
        self.modifiers = modifiers
        self.action = action
    }
}
