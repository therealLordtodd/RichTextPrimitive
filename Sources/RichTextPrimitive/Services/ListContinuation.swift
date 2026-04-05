import Foundation

public struct ListContinuationResult: Sendable, Equatable {
    public var nextBlock: Block
    public var exitsList: Bool

    public init(nextBlock: Block, exitsList: Bool) {
        self.nextBlock = nextBlock
        self.exitsList = exitsList
    }
}

public struct ListContinuation: Sendable {
    public init() {}

    public func handleEnter(
        in block: Block,
        writingMode: any WritingMode = StandardMode()
    ) -> ListContinuationResult? {
        guard case let .list(content, style, indentLevel) = block.content else {
            return nil
        }

        if content.isEmpty {
            let nextType = writingMode.defaultBlockType(after: .list, metadata: block.metadata)
            return ListContinuationResult(
                nextBlock: Block(type: nextType, content: .text(.plain(""))),
                exitsList: true
            )
        }

        return ListContinuationResult(
            nextBlock: Block(
                type: .list,
                content: .list(.plain(""), style: style, indentLevel: indentLevel),
                metadata: block.metadata
            ),
            exitsList: false
        )
    }
}
