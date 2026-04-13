# RichTextPrimitive

`RichTextPrimitive` is the block-based editing layer in the document stack.

It gives you:

- a portable rich-text block model
- a data-source protocol for mutable editor content
- a SwiftUI editor surface
- undo integration
- spell-check integration
- paste-special and block-editing services
- an optional AI product for tool-driven document editing

Use it when your app needs a structured editor, not just an attributed string text view.

Do not use it when a plain `TextEditor`, simple markdown field, or small note input is enough. This package is for apps that want block-level editing, durable model semantics, and editor services that can scale into larger document products.

## Products

`RichTextPrimitive` ships as two products:

### `RichTextPrimitive`

The core editor runtime:

- block model
- text and style model
- data source protocol
- editor state
- SwiftUI editor
- editing services

### `RichTextPrimitiveAI`

The optional AI-facing layer:

- `DocumentAITool`
- `DocumentAIContext`
- `BlockMutation`
- tool-provider protocols

That separation matters. Apps can adopt the editor without pulling AI-specific concepts into the core dependency graph.

## Core model

### `Block`

`Block` is the basic content unit.

Important related types:

- `BlockID`
- `BlockType`
- `BlockContent`
- `BlockMetadata`

This is the real source of truth for document content in the package.

### `TextContent`, `TextRun`, and `TextAttributes`

These types model inline text content and formatting inside text-bearing blocks.

That lets the package keep:

- a structured editor model
- portable formatting semantics
- testable editing behavior outside platform text views

### `RichTextDataSource`

`RichTextDataSource` is the mutation boundary for the editor.

It exposes:

- current `blocks`
- insert, delete, move, and replace operations
- text updates
- block-type updates
- mutation observers

If your app has custom persistence or collaboration logic, this protocol is one of the most important seams in the package.

### `ArrayRichTextDataSource`

The in-memory implementation of `RichTextDataSource`.

Use it when:

- you want the simplest working editor host
- your content is local and session-bound
- you are prototyping before moving to a custom store

### `RichTextState`

`RichTextState` is the UI-facing editor state.

It owns:

- current selection
- active text attributes
- find/replace state
- writing mode
- focused block ID
- zoom level
- spell-check configuration and issues

This is the main state object you keep alive alongside the data source.

### `RichTextEditor`

`RichTextEditor` is the SwiftUI editing surface.

It takes:

- a `RichTextState`
- a `RichTextDataSource`
- an optional `TextStyleSheet`
- an optional spell checker
- an option to show the block navigator

## Quick start

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
        RichTextEditor(
            state: state,
            dataSource: dataSource
        )
    }
}
```

That is the simplest correct host shape:

1. one data source
2. one editor state
3. one editor view

## Concrete examples

### 1. Show the block navigator

```swift
RichTextEditor(
    state: state,
    dataSource: dataSource,
    showsBlockNavigator: true
)
```

This is useful in longer documents where block structure matters and users may want drag-based reordering or quick block focus changes.

### 2. Connect undo

```swift
import UndoPrimitive

let undoStack = UndoStack<[Block]>(initialState: dataSource.blocks)
state.connectUndo(stack: undoStack, dataSource: dataSource)
```

Disconnect it when the editor host tears down:

```swift
state.disconnectUndo()
```

### 3. Run spell checking with a deterministic checker in tests

```swift
RichTextEditor(
    state: state,
    dataSource: dataSource,
    spellChecker: FakeSpellChecker()
)
```

This is a good seam for tests or for specialized dictionaries in domain apps.

### 4. Use paste conversion without the full editor

```swift
let handler = PasteHandler()
let importedBlocks = handler.blocks(from: markdownString)
dataSource.insertBlocks(importedBlocks, at: dataSource.blocks.count)
```

Or from richer clipboard content:

```swift
let blocks = handler.blocks(from: clipboardContent)
```

This is a good reminder that the services are useful outside the editor view itself.

### 5. Use a custom stylesheet

```swift
let styleSheet = TextStyleSheet.standard

RichTextEditor(
    state: state,
    dataSource: dataSource,
    styleSheet: styleSheet
)
```

### 6. Adopt the AI layer only when needed

```swift
import RichTextPrimitiveAI

let tool = DocumentAITool(
    name: "summarize-selection",
    description: "Summarize the selected blocks",
    scope: .selection
) { context in
    []
}
```

The important point is architectural: AI lives in the separate product, not the editor core.

## Editing services

The package includes a set of plain service types that keep common editing behaviors out of the platform bridge code.

Important ones:

- `TextFormatting`
- `BlockSplitMerge`
- `ListContinuation`
- `PasteHandler`
- `SpellCheckingService`

These are useful when:

- your host app wants deterministic editing logic
- you need testable formatting behavior
- you want to reuse the same conversion or mutation rules outside the visible editor

## How to wire it into your app

### Keep the block model as the source of truth

Do not treat the platform text view as the durable document model.

The healthy pattern is:

- your app owns a `RichTextDataSource`
- the data source owns `[Block]`
- `RichTextEditor` renders and mutates through that source

That is what keeps the model portable and testable.

### Choose the data-source strategy early

Start with `ArrayRichTextDataSource` if you want the fastest path to a working editor.

Move to a custom `RichTextDataSource` when you need:

- persistence
- collaboration
- document partitioning
- custom mutation auditing

### Keep one `RichTextState` per editor session

`RichTextState` is not just transient UI decoration. It carries important editing state like selection, active formatting context, find state, spell-check issues, and zoom level.

### Treat `RichTextPrimitive` as the editor layer, not the full document layer

This package is strongest when embedded by a higher-level host that owns:

- document metadata
- sections or pages
- export workflow
- comments and review navigation
- app-level persistence

That is exactly why `DocumentPrimitive` exists above it.

## A strong host-app pattern

```swift
@MainActor
final class NoteEditorController {
    let state = RichTextState()
    let dataSource: ArrayRichTextDataSource

    init(initialBlocks: [Block]) {
        self.dataSource = ArrayRichTextDataSource(blocks: initialBlocks)
    }
}
```

Then in SwiftUI:

```swift
RichTextEditor(
    state: controller.state,
    dataSource: controller.dataSource,
    showsBlockNavigator: true
)
```

That keeps the package in its best role: the editing engine and structured content model.

## Constraints and caveats

- macOS 15+ and iOS 17+
- the package is block-based by design; it is not trying to be a raw attributed-string editor
- `RichTextState` and the editor live on the main actor
- platform text integration is internal, but the durable content model is still the block data source
- AI functionality is opt-in through the separate `RichTextPrimitiveAI` product

## When it is the right fit

`RichTextPrimitive` is a good fit for:

- note editors
- structured writing tools
- editor surfaces inside larger document apps
- apps that need consistent paste and spell-check behavior
- products that may later grow into page/section-oriented document editors

It is less useful for:

- tiny text inputs
- plain markdown text areas
- apps that do not need block structure or editor services
