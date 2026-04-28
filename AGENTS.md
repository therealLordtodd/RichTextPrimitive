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
- `RichTextEditor` must remain cross-platform for macOS 14 and iOS 15. AppKit/UIKit specifics belong under platform/internal seams.
- The optional block navigator rail must stay driven by the same `RichTextDataSource`; do not introduce a second source of truth for reorder UI.
- The TextKit 2 bridge in `RichTextContentBridge` is the source for rendered attributed storage. Keep macOS and iOS layout-manager attachment paths symmetric.
- `TextSelection.blockSelection` is a real selection mode, not a placeholder. Platform bridges must resolve it to a visible range and scroll target for review/object focus.
- Keep spell checking behind the `SpellChecker` protocol. `SystemSpellChecker` is the default, but tests should be able to inject fakes.
- Preserve native AppKit/UIKit edit menus on the live text surface. Extend them for clipboard-backed paste-special behavior instead of replacing them with a custom context menu.
- Do not make `RichTextPrimitiveAI` a dependency of the core target; the AI target depends on core, not the reverse.

## Testing
- Run `swift test` before committing.
- Run an iOS simulator package build after touching platform view, bridge, spell-check, paste, or dependency code.
- Add block navigator coverage when changing block summaries, reorder plumbing, or focus synchronization.
- Add bridge coverage in `BridgeTests` whenever TextKit storage, block layout, attributed rendering, or block-selection mapping changes.
- Add mutation coverage in `DataSourceTests` and `RichTextStateTests` when changing data-source or state behavior.

## Project Management
- Plane project: `RichTextPrimitive` (`RTP`) — `fd285d13-4bd0-443a-ae28-a9cd3a44f21f`
- Standard states: Backlog `10f842a8-e105-4534-a3db-24f8ba5e08eb`, Todo `9db54ee3-8815-4c88-a82c-17c0d4ce0d06`, In Progress `2096cd1e-c8a1-4463-9408-2af7e53d377d`, Done `bd9673ad-920b-4da3-ac0d-3de88b516fd7`, Cancelled `a8ae0d1f-2676-44d3-98da-772307d50e17`
- `Code Review` module exists for this project.
- Follow-up note already filed: `RTP-1` — use `FilterPrimitive` for structured review and navigation filters.

---

## Family Membership — Document Editor

This primitive is a member of the Document Editor primitive family. It participates in shared conventions and consumes or publishes cross-primitive types used by the rich-text / document / editor stack.

**Before modifying public API, shared conventions, or cross-primitive types, consult:**
- `../RichTextEditorKit/docs/plans/2026-04-19-document-editor-dependency-audit.md` — who depends on whom, who uses which conventions
- `/Users/todd/Building - Apple/Packages/CONVENTIONS/` — shared patterns this primitive participates in
- `./MEMBERSHIP.md` in this primitive's root — specific list of conventions, shared types, and sibling consumers

**Changes that alter public API, shared type definitions, or convention contracts MUST include a ripple-analysis section in the commit or PR description** identifying which siblings could be affected and how.

Standalone consumers (apps just importing this primitive) are unaffected by this discipline — it applies only to modifications to the primitive itself.
