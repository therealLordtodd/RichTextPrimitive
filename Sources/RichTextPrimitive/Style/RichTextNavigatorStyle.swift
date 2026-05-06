import DragAndDropPrimitive
import SwiftUI

/// Injectable style tokens for the block navigator rail.
///
/// All properties have sensible defaults that match the original hardcoded
/// appearance. Hosts can inject this through ``View/richTextNavigatorStyle(_:)``
/// or pass a one-off override to ``RichTextEditor``.
public struct RichTextNavigatorStyle: Sendable {

    // MARK: - Layout

    /// Spacing between the navigator rail and the editor content.
    public var editorSpacing: CGFloat

    /// Fixed width of the navigator panel.
    public var navigatorWidth: CGFloat

    /// Outer padding inside the navigator background.
    public var navigatorPadding: CGFloat

    /// Corner radius of the navigator background.
    public var navigatorCornerRadius: CGFloat

    /// Spacing between the icon and the text column in a block row.
    public var rowIconTextSpacing: CGFloat

    /// Width reserved for the block type icon.
    public var iconWidth: CGFloat

    /// Vertical spacing between the title/kind/subtitle lines.
    public var rowTextLineSpacing: CGFloat

    /// Spacing between the title text and the index badge.
    public var titleIndexSpacing: CGFloat

    /// Vertical padding on each block row.
    public var rowVerticalPadding: CGFloat

    /// Horizontal padding on each block row.
    public var rowHorizontalPadding: CGFloat

    /// Corner radius of the selection highlight behind a row.
    public var selectionCornerRadius: CGFloat

    // MARK: - Colors

    /// Background fill for the navigator panel.
    public var backgroundColor: Color

    /// Highlight fill behind the currently focused block row.
    public var selectionColor: Color

    /// Foreground color of the icon when its block is focused.
    public var iconFocusedColor: Color

    /// Foreground color of the icon when its block is not focused.
    public var iconDefaultColor: Color

    // MARK: - Fonts

    /// Font for the block type icon.
    public var iconFont: Font

    /// Font for the block title text.
    public var titleFont: Font

    /// Font for the block index badge.
    public var indexFont: Font

    /// Font for the block kind label (e.g. "Paragraph", "Heading 2").
    public var kindFont: Font

    /// Font for the optional subtitle text.
    public var subtitleFont: Font

    // MARK: - Reorderable list style overrides

    /// Style tokens forwarded to the underlying ``ReorderableList``.
    public var reorderableStyle: ReorderableContainerStyle

    // MARK: - Defaults

    /// Balanced defaults that reproduce the original hardcoded appearance.
    public static let `default` = RichTextNavigatorStyle()

    // MARK: - Init

    /// Creates a navigator style with full control over every visual token.
    public init(
        editorSpacing: CGFloat = 12,
        navigatorWidth: CGFloat = 220,
        navigatorPadding: CGFloat = 12,
        navigatorCornerRadius: CGFloat = 16,
        rowIconTextSpacing: CGFloat = 10,
        iconWidth: CGFloat = 18,
        rowTextLineSpacing: CGFloat = 4,
        titleIndexSpacing: CGFloat = 6,
        rowVerticalPadding: CGFloat = 2,
        rowHorizontalPadding: CGFloat = 2,
        selectionCornerRadius: CGFloat = 10,
        backgroundColor: Color = Color.secondary.opacity(0.06),
        selectionColor: Color = Color.accentColor.opacity(0.14),
        iconFocusedColor: Color = .accentColor,
        iconDefaultColor: Color = .secondary,
        iconFont: Font = .footnote.weight(.semibold),
        titleFont: Font = .subheadline.weight(.semibold),
        indexFont: Font = .caption2.monospacedDigit(),
        kindFont: Font = .caption,
        subtitleFont: Font = .caption,
        reorderableStyle: ReorderableContainerStyle = ReorderableContainerStyle(
            dragHandleColor: .secondary,
            targetedBackgroundColor: Color.accentColor.opacity(0.12),
            idleBackgroundColor: .clear,
            previewBackgroundColor: .white,
            previewBackgroundOpacity: 0.98,
            previewBorderColor: Color.accentColor,
            previewBorderOpacity: 0.25
        )
    ) {
        self.editorSpacing = editorSpacing
        self.navigatorWidth = navigatorWidth
        self.navigatorPadding = navigatorPadding
        self.navigatorCornerRadius = navigatorCornerRadius
        self.rowIconTextSpacing = rowIconTextSpacing
        self.iconWidth = iconWidth
        self.rowTextLineSpacing = rowTextLineSpacing
        self.titleIndexSpacing = titleIndexSpacing
        self.rowVerticalPadding = rowVerticalPadding
        self.rowHorizontalPadding = rowHorizontalPadding
        self.selectionCornerRadius = selectionCornerRadius
        self.backgroundColor = backgroundColor
        self.selectionColor = selectionColor
        self.iconFocusedColor = iconFocusedColor
        self.iconDefaultColor = iconDefaultColor
        self.iconFont = iconFont
        self.titleFont = titleFont
        self.indexFont = indexFont
        self.kindFont = kindFont
        self.subtitleFont = subtitleFont
        self.reorderableStyle = reorderableStyle
    }
}

private struct RichTextNavigatorStyleKey: EnvironmentKey {
    static let defaultValue: RichTextNavigatorStyle = .default
}

public extension EnvironmentValues {
    /// Environment-provided style tokens for the RichTextPrimitive block navigator.
    var richTextNavigatorStyle: RichTextNavigatorStyle {
        get { self[RichTextNavigatorStyleKey.self] }
        set { self[RichTextNavigatorStyleKey.self] = newValue }
    }
}

public extension View {
    /// Injects style tokens for RichTextPrimitive block navigator surfaces.
    func richTextNavigatorStyle(_ style: RichTextNavigatorStyle) -> some View {
        environment(\.richTextNavigatorStyle, style)
    }
}
