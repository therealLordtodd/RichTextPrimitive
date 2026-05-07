import Foundation
import SwiftUI
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

    @Test func packageChromeLocalizationResolvesDefaultResources() {
        #expect(RichTextPrimitiveStrings.editorAccessibilityLabel == "Rich text editor")
        #expect(RichTextPrimitiveStrings.headingKind(level: 2) == "Heading 2")
        #expect(RichTextPrimitiveStrings.listKind(style: .numbered) == "Numbered List")
        #expect(RichTextPrimitiveStrings.blockPosition(3) == "block 3")
        #expect(RichTextPrimitiveStrings.tableSubtitle(rowCount: 1, columnCount: 2) == "1 row, 2 columns")
        #expect(RichTextPrimitiveStrings.imageSize(width: 640, height: 480) == "640 x 480")
    }

    @Test func navigatorStyleCanBeProvidedThroughEnvironment() {
        let state = RichTextState()
        let dataSource = ArrayRichTextDataSource()
        let style = RichTextNavigatorStyle(navigatorWidth: 180)

        _ = RichTextEditor(
            state: state,
            dataSource: dataSource,
            spellChecker: nil,
            showsBlockNavigator: true
        )
        .richTextNavigatorStyle(style)

        #expect(style.navigatorWidth == 180)
    }
}
