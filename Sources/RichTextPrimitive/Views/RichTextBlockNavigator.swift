import DragAndDropPrimitive
import SwiftUI

@MainActor
final class RichTextBlockNavigatorController: ObservableObject {
    @Published var items: [RichTextBlockNavigatorItem] = []

    private weak var dataSource: (any RichTextDataSource)?
    private var mutationObserverID: UUID?
    private var boundIdentity: ObjectIdentifier?

    func bind(to dataSource: any RichTextDataSource) {
        let identity = ObjectIdentifier(dataSource)
        guard boundIdentity != identity else {
            sync(from: dataSource.blocks)
            return
        }

        unbind()
        self.dataSource = dataSource
        boundIdentity = identity
        sync(from: dataSource.blocks)

        mutationObserverID = dataSource.addMutationObserver { [weak self, weak dataSource] _ in
            guard let self, let dataSource else { return }
            self.sync(from: dataSource.blocks)
        }
    }

    func unbind() {
        if let dataSource, let mutationObserverID {
            dataSource.removeMutationObserver(mutationObserverID)
        }

        dataSource = nil
        mutationObserverID = nil
        boundIdentity = nil
        items = []
    }

    func applyReorder(_ result: ReorderResult<RichTextBlockNavigatorItem>) {
        guard let dataSource else { return }
        dataSource.moveBlocks(
            from: IndexSet(integer: result.fromIndex),
            to: result.toIndex
        )
        sync(from: dataSource.blocks)
    }

    private func sync(from blocks: [Block]) {
        items = blocks.enumerated().map { index, block in
            RichTextBlockNavigatorItem(index: index, block: block)
        }
    }
}

struct RichTextBlockNavigatorItem: Identifiable, Equatable, Sendable {
    let id: BlockID
    let index: Int
    let iconName: String
    let kindLabel: String
    let title: String
    let subtitle: String?

    init(index: Int, block: Block) {
        self.id = block.id
        self.index = index
        self.iconName = Self.iconName(for: block.type)
        self.kindLabel = Self.kindLabel(for: block.type, content: block.content)
        self.title = Self.title(for: block.content)
        self.subtitle = Self.subtitle(for: block.content)
    }

    func accessibilityValue(isFocused: Bool) -> String {
        var parts = [
            kindLabel,
            RichTextPrimitiveStrings.blockPosition(index + 1)
        ]

        if let subtitle {
            parts.append(subtitle)
        }

        if isFocused {
            parts.append(RichTextPrimitiveStrings.focusedAccessibilityValue)
        }

        return parts.joined(separator: ", ")
    }

    private static func iconName(for type: BlockType) -> String {
        switch type {
        case .paragraph:
            "paragraph"
        case .heading:
            "textformat.size"
        case .blockQuote:
            "quote.opening"
        case .codeBlock:
            "curlybraces"
        case .list:
            "list.bullet"
        case .table:
            "tablecells"
        case .image:
            "photo"
        case .divider:
            "minus"
        case .embed:
            "link"
        }
    }

    private static func kindLabel(for type: BlockType, content: BlockContent) -> String {
        switch content {
        case let .heading(_, level):
            RichTextPrimitiveStrings.headingKind(level: level)
        case let .list(_, style, _):
            RichTextPrimitiveStrings.listKind(style: style)
        case let .embed(embed):
            embed.kind.uppercased()
        default:
            switch type {
            case .paragraph:
                RichTextPrimitiveStrings.paragraphKind
            case .heading:
                RichTextPrimitiveStrings.headingKind
            case .blockQuote:
                RichTextPrimitiveStrings.quoteKind
            case .codeBlock:
                RichTextPrimitiveStrings.codeKind
            case .list:
                RichTextPrimitiveStrings.listKind
            case .table:
                RichTextPrimitiveStrings.tableKind
            case .image:
                RichTextPrimitiveStrings.imageKind
            case .divider:
                RichTextPrimitiveStrings.dividerKind
            case .embed:
                RichTextPrimitiveStrings.embedKind
            }
        }
    }

    private static func title(for content: BlockContent) -> String {
        let fallback = RichTextPrimitiveStrings.untitledBlockTitle
        switch content {
        case let .text(text),
             let .heading(text, _),
             let .blockQuote(text),
             let .list(text, _, _):
            return firstMeaningfulLine(in: text.plainText) ?? fallback
        case let .codeBlock(code, language):
            let prefix = language?.uppercased() ?? RichTextPrimitiveStrings.codeKind
            return firstMeaningfulLine(in: code).map {
                RichTextPrimitiveStrings.codeBlockTitle(language: prefix, preview: $0)
            } ?? prefix
        case let .table(table):
            if let caption = table.caption?.plainText,
               let firstLine = firstMeaningfulLine(in: caption) {
                return firstLine
            }
            let columnCount = table.rows.map(\.count).max() ?? 0
            return RichTextPrimitiveStrings.tableTitle(rowCount: table.rows.count, columnCount: columnCount)
        case let .image(image):
            if let altText = firstMeaningfulLine(in: image.altText) {
                return altText
            }
            if let url = image.url?.lastPathComponent,
               !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return url
            }
            return RichTextPrimitiveStrings.imageKind
        case .divider:
            return RichTextPrimitiveStrings.sectionDividerTitle
        case let .embed(embed):
            if let title = metadataString(["title", "name", "filename"], metadata: embed.metadata) {
                return title
            }
            if let payload = firstMeaningfulLine(in: embed.payload) {
                return payload
            }
            return embed.kind.uppercased()
        }
    }

    private static func subtitle(for content: BlockContent) -> String? {
        switch content {
        case let .heading(text, _),
             let .text(text),
             let .blockQuote(text),
             let .list(text, _, _):
            return detailSummary(for: text.plainText)
        case let .codeBlock(code, _):
            return detailSummary(for: code)
        case let .table(table):
            if let caption = table.caption?.plainText,
               let summary = detailSummary(for: caption) {
                return summary
            }
            let rowCount = table.rows.count
            let columnCount = table.rows.map(\.count).max() ?? 0
            return RichTextPrimitiveStrings.tableSubtitle(rowCount: rowCount, columnCount: columnCount)
        case let .image(image):
            if let size = image.size {
                return RichTextPrimitiveStrings.imageSize(width: Int(size.width), height: Int(size.height))
            }
            return image.url?.pathExtension.uppercased()
        case .divider:
            return nil
        case let .embed(embed):
            return metadataString(["url", "path"], metadata: embed.metadata)
                ?? detailSummary(for: embed.payload)
        }
    }

    private static func firstMeaningfulLine(in text: String?) -> String? {
        guard let text else { return nil }
        return text
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }

    private static func detailSummary(for text: String?) -> String? {
        guard let firstLine = firstMeaningfulLine(in: text) else { return nil }
        let condensed = firstLine.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard condensed.count > 48 else { return condensed }
        let cutoff = condensed.index(condensed.startIndex, offsetBy: 45)
        return "\(condensed[..<cutoff])..."
    }

    private static func metadataString(
        _ keys: [String],
        metadata: [String: MetadataValue]
    ) -> String? {
        for key in keys {
            if case let .string(value)? = metadata[key] {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }
}

struct RichTextBlockNavigator: View {
    @ObservedObject var controller: RichTextBlockNavigatorController
    let focusedBlockID: BlockID?
    let style: RichTextNavigatorStyle
    let onSelect: (BlockID) -> Void

    var body: some View {
        if controller.items.count > 1 {
            ReorderableList(
                items: Binding(
                    get: { controller.items },
                    set: { controller.items = $0 }
                ),
                showsDragHandles: true,
                style: style.reorderableStyle,
                onReorder: controller.applyReorder
            ) { item in
                blockRow(item)
            }
            .frame(width: style.navigatorWidth, alignment: .topLeading)
            .padding(style.navigatorPadding)
            .background(
                style.backgroundColor,
                in: RoundedRectangle(cornerRadius: style.navigatorCornerRadius, style: .continuous)
            )
            .accessibilityLabel(RichTextPrimitiveStrings.blockNavigatorAccessibilityLabel)
        }
    }

    private func blockRow(_ item: RichTextBlockNavigatorItem) -> some View {
        HStack(alignment: .top, spacing: style.rowIconTextSpacing) {
            Image(systemName: item.iconName)
                .font(style.iconFont)
                .foregroundStyle(focusedBlockID == item.id ? style.iconFocusedColor : style.iconDefaultColor)
                .frame(width: style.iconWidth, alignment: .center)

            VStack(alignment: .leading, spacing: style.rowTextLineSpacing) {
                HStack(spacing: style.titleIndexSpacing) {
                    Text(item.title)
                        .font(style.titleFont)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(verbatim: "\(item.index + 1)")
                        .font(style.indexFont)
                        .foregroundStyle(.secondary)
                }

                Text(item.kindLabel)
                    .font(style.kindFont)
                    .foregroundStyle(.secondary)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(style.subtitleFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, style.rowVerticalPadding)
        .padding(.horizontal, style.rowHorizontalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selectionBackground(for: item.id))
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect(item.id)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.title)
        .accessibilityValue(item.accessibilityValue(isFocused: focusedBlockID == item.id))
        .accessibilityHint(RichTextPrimitiveStrings.blockNavigatorRowAccessibilityHint)
    }

    @ViewBuilder
    private func selectionBackground(for blockID: BlockID) -> some View {
        RoundedRectangle(cornerRadius: style.selectionCornerRadius, style: .continuous)
            .fill(
                focusedBlockID == blockID
                    ? style.selectionColor
                    : Color.clear
            )
    }
}
