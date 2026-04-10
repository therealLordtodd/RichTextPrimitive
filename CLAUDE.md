# RichTextPrimitive Working Guide

## Purpose
RichTextPrimitive is the cross-platform block rich text editor foundation. It owns block and inline models, editor state, data-source mutations, platform editor views, formatting helpers, paste parsing, list continuation, spell-check integration, the optional block navigator reorder rail, and the optional `RichTextPrimitiveAI` tool surface.

## Key Directories
- `Sources/RichTextPrimitive`: Core block model, state, services, style system, writing modes, commands, and SwiftUI editor view.
- `Sources/RichTextPrimitiveAI`: AI context, tool, provider, and block mutation abstractions.
- `Tests/RichTextPrimitiveTests`: Model, state, bridge, formatting, spell checking, and writing-mode tests.
- `Tests/RichTextPrimitiveAITests`: AI tool tests.

## Architecture Rules
- `RichTextDataSource` is the mutation boundary. Views and services should mutate through data-source methods rather than editing arrays behind the source.
- `RichTextEditor` must remain cross-platform for macOS 15 and iOS 17. AppKit/UIKit specifics belong under platform/internal seams.
- The optional block navigator rail must stay driven by the same `RichTextDataSource`; do not introduce a second source of truth for reorder UI.
- The TextKit 2 bridge in `RichTextContentBridge` is the source for rendered attributed storage. Keep macOS and iOS layout-manager attachment paths symmetric.
- Keep spell checking behind the `SpellChecker` protocol. `SystemSpellChecker` is the default, but tests should be able to inject fakes.
- Do not make `RichTextPrimitiveAI` a dependency of the core target; the AI target depends on core, not the reverse.

## Testing
- Run `swift test` before committing.
- Run an iOS simulator package build after touching platform view, bridge, spell-check, paste, or dependency code.
- Add block navigator coverage when changing block summaries, reorder plumbing, or focus synchronization.
- Add bridge coverage in `BridgeTests` whenever TextKit storage, block layout, or attributed rendering changes.
- Add mutation coverage in `DataSourceTests` and `RichTextStateTests` when changing data-source or state behavior.
