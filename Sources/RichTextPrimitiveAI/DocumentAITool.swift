import Foundation
import RichTextPrimitive

public enum ToolScope: Sendable, Equatable {
    case selection
    case block
    case document
}

public struct DocumentAITool: Identifiable, Sendable {
    public let id: String
    public var name: String
    public var description: String
    public var scope: ToolScope

    private let executeHandler: @Sendable (DocumentAIContext) async throws -> [BlockMutation]

    public init(
        id: String,
        name: String,
        description: String,
        scope: ToolScope,
        execute: @escaping @Sendable (DocumentAIContext) async throws -> [BlockMutation]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.scope = scope
        self.executeHandler = execute
    }

    public func execute(context: DocumentAIContext) async throws -> [BlockMutation] {
        try await executeHandler(context)
    }
}
