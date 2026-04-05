import Foundation

public struct BlockSplitResult: Sendable, Equatable {
    public var leading: Block
    public var trailing: Block

    public init(leading: Block, trailing: Block) {
        self.leading = leading
        self.trailing = trailing
    }
}

public struct BlockSplitMerge: Sendable {
    public init() {}

    public func split(
        block: Block,
        at offset: Int,
        writingMode: any WritingMode = StandardMode()
    ) -> BlockSplitResult {
        switch block.content {
        case let .text(content):
            let (left, right) = content.split(at: offset)
            return BlockSplitResult(
                leading: Block(id: block.id, type: .paragraph, content: .text(left), metadata: block.metadata),
                trailing: Block(
                    type: writingMode.defaultBlockType(after: block.type, metadata: block.metadata),
                    content: .text(right),
                    metadata: writingMode.metadataForTypeChange(from: block.type, to: .paragraph, existing: block.metadata)
                )
            )
        case let .heading(content, level):
            let (left, right) = content.split(at: offset)
            return BlockSplitResult(
                leading: Block(id: block.id, type: .heading, content: .heading(left, level: level), metadata: block.metadata),
                trailing: Block(type: .paragraph, content: .text(right))
            )
        case let .blockQuote(content):
            let (left, right) = content.split(at: offset)
            return BlockSplitResult(
                leading: Block(id: block.id, type: .blockQuote, content: .blockQuote(left), metadata: block.metadata),
                trailing: Block(type: .blockQuote, content: .blockQuote(right), metadata: block.metadata)
            )
        case let .codeBlock(code, language):
            let characters = Array(code)
            let safeOffset = min(max(offset, 0), characters.count)
            let left = String(characters[..<safeOffset])
            let right = String(characters[safeOffset...])
            return BlockSplitResult(
                leading: Block(id: block.id, type: .codeBlock, content: .codeBlock(code: left, language: language), metadata: block.metadata),
                trailing: Block(type: .codeBlock, content: .codeBlock(code: right, language: language), metadata: block.metadata)
            )
        case let .list(content, style, indentLevel):
            let (left, right) = content.split(at: offset)
            return BlockSplitResult(
                leading: Block(id: block.id, type: .list, content: .list(left, style: style, indentLevel: indentLevel), metadata: block.metadata),
                trailing: Block(type: .list, content: .list(right, style: style, indentLevel: indentLevel), metadata: block.metadata)
            )
        case .table, .image, .divider, .embed:
            return BlockSplitResult(
                leading: block,
                trailing: Block(type: .paragraph, content: .text(.plain("")))
            )
        }
    }

    public func merge(previous: Block, next: Block) -> Block? {
        switch (previous.content, next.content) {
        case let (.text(left), .text(right)):
            return Block(
                id: previous.id,
                type: .paragraph,
                content: .text(left.replacing(range: left.characters.count..<left.characters.count, with: right)),
                metadata: previous.metadata
            )
        case let (.blockQuote(left), .blockQuote(right)):
            return Block(
                id: previous.id,
                type: .blockQuote,
                content: .blockQuote(left.replacing(range: left.characters.count..<left.characters.count, with: right)),
                metadata: previous.metadata
            )
        case let (.heading(left, level1), .heading(right, level2)) where level1 == level2:
            return Block(
                id: previous.id,
                type: .heading,
                content: .heading(left.replacing(range: left.characters.count..<left.characters.count, with: right), level: level1),
                metadata: previous.metadata
            )
        case let (.codeBlock(left, language1), .codeBlock(right, language2)) where language1 == language2:
            return Block(
                id: previous.id,
                type: .codeBlock,
                content: .codeBlock(code: left + right, language: language1),
                metadata: previous.metadata
            )
        case let (.list(left, style1, indent1), .list(right, style2, indent2)) where style1 == style2 && indent1 == indent2:
            return Block(
                id: previous.id,
                type: .list,
                content: .list(left.replacing(range: left.characters.count..<left.characters.count, with: right), style: style1, indentLevel: indent1),
                metadata: previous.metadata
            )
        default:
            return nil
        }
    }
}
