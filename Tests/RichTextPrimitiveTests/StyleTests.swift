import Foundation
import Testing
@testable import RichTextPrimitive

@MainActor
@Suite("Style Tests")
struct StyleTests {
    @Test func paragraphStyleCodableRoundTrip() throws {
        let style = ParagraphStyle(fontFamily: "Georgia", fontSize: 16, alignment: .justified)
        let data = try JSONEncoder().encode(style)
        let decoded = try JSONDecoder().decode(ParagraphStyle.self, from: data)
        #expect(decoded == style)
    }

    @Test func headingStyleLookupFallsBackToDefault() {
        let styleSheet = TextStyleSheet.standard
        #expect(styleSheet.headingStyle(level: 1).fontSize == 30)
        #expect(styleSheet.headingStyle(level: 99) == styleSheet.defaultStyle)
    }
}
