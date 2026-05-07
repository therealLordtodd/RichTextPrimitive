import Foundation

enum RichTextPrimitiveStrings {
    static var blockNavigatorAccessibilityLabel: String {
        localized("richText.navigator.accessibility.label", defaultValue: "Block navigator")
    }

    static var blockNavigatorRowAccessibilityHint: String {
        localized("richText.navigator.row.accessibility.hint", defaultValue: "Select this block in the editor")
    }

    static var editorContentAccessibilityLabel: String {
        localized("richText.editor.content.accessibility.label", defaultValue: "Rich text editor content")
    }

    static var editorContentAccessibilityHint: String {
        localized("richText.editor.content.accessibility.hint", defaultValue: "Edit rich text document blocks")
    }

    static var editorAccessibilityLabel: String {
        localized("richText.editor.accessibility.label", defaultValue: "Rich text editor")
    }

    static var focusedAccessibilityValue: String {
        localized("richText.navigator.accessibility.focused", defaultValue: "focused")
    }

    static var paragraphKind: String { localized("richText.block.kind.paragraph", defaultValue: "Paragraph") }
    static var headingKind: String { localized("richText.block.kind.heading", defaultValue: "Heading") }
    static var quoteKind: String { localized("richText.block.kind.quote", defaultValue: "Quote") }
    static var codeKind: String { localized("richText.block.kind.code", defaultValue: "Code") }
    static var listKind: String { localized("richText.block.kind.list", defaultValue: "List") }
    static var tableKind: String { localized("richText.block.kind.table", defaultValue: "Table") }
    static var imageKind: String { localized("richText.block.kind.image", defaultValue: "Image") }
    static var dividerKind: String { localized("richText.block.kind.divider", defaultValue: "Divider") }
    static var embedKind: String { localized("richText.block.kind.embed", defaultValue: "Embed") }
    static var untitledBlockTitle: String { localized("richText.block.title.untitled", defaultValue: "Untitled Block") }
    static var sectionDividerTitle: String { localized("richText.block.title.sectionDivider", defaultValue: "Section Divider") }

    static func headingKind(level: Int) -> String {
        String.localizedStringWithFormat(localized("richText.block.kind.headingLevel", defaultValue: "Heading %d"), level)
    }

    static func listKind(style: ListStyle) -> String {
        switch style {
        case .bullet:
            localized("richText.block.kind.list.bullet", defaultValue: "Bullet List")
        case .numbered:
            localized("richText.block.kind.list.numbered", defaultValue: "Numbered List")
        case .checklist:
            localized("richText.block.kind.list.checklist", defaultValue: "Checklist")
        }
    }

    static func blockPosition(_ position: Int) -> String {
        String.localizedStringWithFormat(localized("richText.navigator.accessibility.blockPosition", defaultValue: "block %d"), position)
    }

    static func codeBlockTitle(language: String, preview: String) -> String {
        String.localizedStringWithFormat(localized("richText.block.title.codePreview", defaultValue: "%@: %@"), language, preview)
    }

    static func tableTitle(rowCount: Int, columnCount: Int) -> String {
        String.localizedStringWithFormat(localized("richText.block.title.tableSize", defaultValue: "Table %dx%d"), rowCount, columnCount)
    }

    static func tableSubtitle(rowCount: Int, columnCount: Int) -> String {
        let rows = String.localizedStringWithFormat(localized("richText.block.subtitle.rows", defaultValue: "%d rows"), rowCount)
        let columns = String.localizedStringWithFormat(localized("richText.block.subtitle.columns", defaultValue: "%d columns"), columnCount)
        return String.localizedStringWithFormat(
            localized("richText.block.subtitle.tableDimensions", defaultValue: "%@, %@"),
            rows,
            columns
        )
    }

    static func imageSize(width: Int, height: Int) -> String {
        String.localizedStringWithFormat(localized("richText.block.subtitle.imageSize", defaultValue: "%d x %d"), width, height)
    }

    private static func localized(_ key: String, defaultValue: String) -> String {
        NSLocalizedString(key, bundle: .module, value: defaultValue, comment: "")
    }
}
