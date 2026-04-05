import Foundation

public struct StandardMode: WritingMode {
    public let id = "standard"
    public let displayName = "Standard"

    public init() {}

    public var availableBlockTypes: [BlockType] {
        BlockType.allCases
    }

    public func defaultBlockType(after current: BlockType, metadata: BlockMetadata) -> BlockType {
        .paragraph
    }

    public var keyboardShortcuts: [ModeKeyboardShortcut] {
        []
    }

    public var styleOverrides: TextStyleSheet? {
        nil
    }

    public func metadataForTypeChange(
        from: BlockType,
        to: BlockType,
        existing: BlockMetadata
    ) -> BlockMetadata {
        existing
    }
}
