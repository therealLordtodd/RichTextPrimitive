import Foundation
import RichTextPrimitive

public protocol DocumentAIToolProvider {
    var tools: [DocumentAITool] { get }
}
