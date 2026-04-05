import Foundation
import Observation

@MainActor
@Observable
public final class ArrayRichTextDataSource: RichTextDataSource {
    public var blocks: [Block]

    private var observers: [UUID: @MainActor (RichTextMutation) -> Void] = [:]

    public init(blocks: [Block] = []) {
        self.blocks = blocks
    }

    public func block(at index: Int) -> Block {
        blocks[index]
    }

    public func insertBlocks(_ blocks: [Block], at index: Int) {
        let insertionIndex = min(max(index, 0), self.blocks.count)
        self.blocks.insert(contentsOf: blocks, at: insertionIndex)
        notify(.blocksInserted(indices: IndexSet(insertionIndex..<(insertionIndex + blocks.count))))
    }

    public func deleteBlocks(at indices: IndexSet) {
        for index in indices.sorted(by: >) where blocks.indices.contains(index) {
            blocks.remove(at: index)
        }
        notify(.blocksDeleted(indices: indices))
    }

    public func moveBlocks(from source: IndexSet, to destination: Int) {
        let movingBlocks = source.sorted().compactMap { index in
            blocks.indices.contains(index) ? blocks[index] : nil
        }

        for index in source.sorted(by: >) where blocks.indices.contains(index) {
            blocks.remove(at: index)
        }

        let insertionIndex = min(max(destination, 0), blocks.count)
        blocks.insert(contentsOf: movingBlocks, at: insertionIndex)
        notify(.blocksMoved(from: source, to: destination))
    }

    public func replaceBlock(at index: Int, with block: Block) {
        guard blocks.indices.contains(index) else { return }
        blocks[index] = block
        notify(.blockReplaced(index: index))
    }

    public func updateTextContent(blockID: BlockID, content: TextContent) {
        guard let index = blocks.firstIndex(where: { $0.id == blockID }) else { return }
        switch blocks[index].content {
        case .text:
            blocks[index].content = .text(content)
        case let .heading(_, level):
            blocks[index].content = .heading(content, level: level)
        case .blockQuote:
            blocks[index].content = .blockQuote(content)
        case let .list(_, style, indentLevel):
            blocks[index].content = .list(content, style: style, indentLevel: indentLevel)
        case let .codeBlock(_, language):
            blocks[index].content = .codeBlock(code: content.plainText, language: language)
        case .table, .image, .divider, .embed:
            return
        }
        notify(.textUpdated(blockID: blockID))
    }

    public func updateBlockType(blockID: BlockID, type: BlockType, content: BlockContent) {
        guard let index = blocks.firstIndex(where: { $0.id == blockID }) else { return }
        blocks[index].type = type
        blocks[index].content = content
        notify(.typeChanged(blockID: blockID))
    }

    public func addMutationObserver(_ observer: @escaping @MainActor (RichTextMutation) -> Void) -> UUID {
        let id = UUID()
        observers[id] = observer
        return id
    }

    public func removeMutationObserver(_ id: UUID) {
        observers.removeValue(forKey: id)
    }

    private func notify(_ mutation: RichTextMutation) {
        for observer in observers.values {
            observer(mutation)
        }
    }
}
