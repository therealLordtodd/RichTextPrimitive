import Foundation
import Testing
@testable import RichTextPrimitive
import DragAndDropPrimitive

@MainActor
@Suite("RichTextPrimitive Block Navigator Tests")
struct BlockNavigatorTests {
    @Test func controllerBuildsNavigatorItemsFromBlocks() {
        let dataSource = ArrayRichTextDataSource(
            blocks: [
                Block(
                    id: "heading",
                    type: .heading,
                    content: .heading(.plain("Launch Plan"), level: 2)
                ),
                Block(
                    id: "image",
                    type: .image,
                    content: .image(ImageContent(altText: "Hero render"))
                ),
                Block(
                    id: "divider",
                    type: .divider,
                    content: .divider
                ),
            ]
        )
        let controller = RichTextBlockNavigatorController()

        controller.bind(to: dataSource)

        #expect(controller.items.map(\.id) == ["heading", "image", "divider"])
        #expect(controller.items[0].kindLabel == "Heading 2")
        #expect(controller.items[1].title == "Hero render")
        #expect(controller.items[2].title == "Section Divider")
    }

    @Test func controllerReordersBackingDataSource() {
        let dataSource = ArrayRichTextDataSource(
            blocks: [
                Block(id: "a", type: .paragraph, content: .text(.plain("First"))),
                Block(id: "b", type: .paragraph, content: .text(.plain("Second"))),
                Block(id: "c", type: .paragraph, content: .text(.plain("Third"))),
            ]
        )
        let controller = RichTextBlockNavigatorController()
        controller.bind(to: dataSource)

        controller.applyReorder(
            ReorderResult(
                item: controller.items[0],
                fromIndex: 0,
                toIndex: 2
            )
        )

        #expect(dataSource.blocks.map(\.id) == ["b", "c", "a"])
        #expect(controller.items.map(\.id) == ["b", "c", "a"])
    }
}
