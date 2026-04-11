# RichTextPrimitive

RichTextPrimitive provides a block-based rich text editor model and SwiftUI editor primitive for macOS and iOS. It is designed to be embedded by higher-level document products while keeping the editable text model portable and testable, with shared paste-special, spell-check, block-selection, and block-reorder behavior across platforms.

## Quick Start

```swift
import RichTextPrimitive
import SwiftUI

let dataSource = ArrayRichTextDataSource(
    blocks: [
        Block(
            type: .paragraph,
            content: .text(.plain("Hello, editor."))
        )
    ]
)
let state = RichTextState()

struct EditorHost: View {
    let state: RichTextState
    let dataSource: ArrayRichTextDataSource

    var body: some View {
        RichTextEditor(state: state, dataSource: dataSource)
    }
}
```

## Key Types
- `Block`, `BlockID`, `BlockType`, and `BlockContent`: The portable block document model.
- `TextContent`, `TextRun`, and `TextAttributes`: Inline text and styling model.
- `RichTextDataSource`: MainActor mutation boundary for block collections.
- `ArrayRichTextDataSource`: In-memory observable data source.
- `RichTextState`: Selection, active attributes, find state, writing mode, zoom, and spell-check state.
- `RichTextEditor`: SwiftUI editor view backed by platform TextKit integration.
- `RichTextBlockNavigator`: Optional block outline and drag-to-reorder rail used by higher-level hosts such as `DocumentPrimitive`.
- `TextStyleSheet` and `ParagraphStyle`: Default, heading, quote, code, list, and custom paragraph styling.
- `TextFormatting`, `BlockSplitMerge`, `ListContinuation`, `PasteHandler`, and `SpellCheckingService`: Editing services.
- `DocumentAITool`, `DocumentAIContext`, and `BlockMutation`: Optional AI tool surface from `RichTextPrimitiveAI`.

## Common Operations
- Mutate content through `RichTextDataSource` methods such as `insertBlocks(_:at:)`, `replaceBlock(at:with:)`, and `updateTextContent(blockID:content:)`.
- Use `RichTextState.connectUndo(stack:dataSource:)` to record data-source edits and apply `UndoStack<[Block]>` undo/redo snapshots back to the editor. Call `disconnectUndo()` before tearing down a custom binding.
- Pass a custom `SpellChecker` to `RichTextEditor` for deterministic tests or specialized dictionaries.
- Set `showsBlockNavigator: true` when the host wants a drag-reorder block rail backed by `DragAndDropPrimitive` and the same `RichTextDataSource`.
- Use `PasteHandler` with `ClipboardPrimitive.ClipboardContent` when hosts need deterministic block conversion for HTML, RTF, URLs, files, or pasted images. On macOS and iOS, `RichTextEditor` extends the native edit menu with `Paste Special` actions backed by that same conversion path.
- Use `TextSelection.blockSelection` when higher-level hosts need object-style selection or review focus. The platform bridges map block selections to a visible text range and scroll target instead of treating them as a no-op.
- Use `TextContent.plain(_:)` for plain text and `TextContent.sliced(_:)` when rendering fragments.
- Use `TextStyleSheet.standard` as the default editor stylesheet and override with a custom sheet when embedding.

## Platform Notes
- The package supports macOS 15 and iOS 17.
- The editor uses platform TextKit paths internally. Keep macOS and iOS behavior aligned when touching layout, storage, selection, or spell-check refresh.
- Preserve native AppKit/UIKit edit menus on the live editor surface. Extend them with clipboard-backed `Paste Special` actions rather than replacing them with a custom context menu.
- `RichTextPrimitiveAI` is a separate product so hosts can opt into AI tooling without coupling the core editor to AI features.

## Testing

Run:

```bash
swift test
```

For platform-sensitive changes, also run:

```bash
xcodebuild build -scheme RichTextPrimitive-Package -destination 'generic/platform=iOS Simulator' -quiet
```

Add bridge coverage whenever TextKit storage, attributed rendering, or block-selection mapping changes.
