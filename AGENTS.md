# RichTextPrimitive Working Guide

## Xcode Build Stall Recovery

If an Xcode or `xcodebuild` build appears stalled with no useful progress, run the global build doctor before rebooting:

```sh
xcode-build-doctor
```

When it reports old stuck compiler probes for this project, clear only this project's stuck build-service tree:

```sh
xcode-build-doctor --project "RichTextPrimitive" --sample --fix
```

Use `--dry-run` first when other legitimate builders may be active. Avoid `--all --fix` unless Todd explicitly wants every active Xcode build stopped. If the doctor reports no stuck probes, investigate the build normally (compiler/package/cache/project error).

## Purpose
RichTextPrimitive is the cross-platform block rich text editor foundation. It owns block and inline models, editor state, data-source mutations, platform editor views, formatting helpers, paste parsing, list continuation, spell-check integration, the optional block navigator reorder rail, and the optional `RichTextPrimitiveAI` tool surface.

## Repositories & Local Paths

| Package | Repository | Local Path |
|---------|------------|------------|
| **RichTextPrimitive** | https://github.com/therealLordtodd/RichTextPrimitive.git | `/Users/todd/Building - Apple/Packages/RichTextPrimitive` |

## Build & Test

- **Build:** `swift build`
- **Test:** `swift test`

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

## Performance posture

Editor primitive on the per-keystroke hot path of every host that renders a rich-text surface. The package straddles two cost regimes: the in-memory block model (cheap, value-type) and the TextKit 2 bridge (allocation-heavy by nature, owned by AppKit/UIKit).

- **Hot paths:**
  - `ArrayRichTextDataSource` mutation methods (`insertBlocks`, `deleteBlocks`, `moveBlocks`, `replaceBlock`, `updateTextContent`, `updateBlockType`) — called per keystroke, per paste, per drag-drop. Each mutation fans out to registered observers via the `RichTextMutation` channel.
  - `RichTextContentBridge` — TextKit 2 bridge that maps `Block` arrays to `NSAttributedString` storage. The macOS and iOS layout-manager attachment paths must stay symmetric or one platform pays an O(blocks) re-layout per edit.
  - `SpellCheckingService` — runs against changed ranges, not full documents; the `SpellChecker` protocol seam exists so tests skip the system spell checker entirely.
  - `PasteHandler` and `ListContinuation` — invoked once per paste / once per Return-key, not per character. Cost is amortized.
- **Concurrency model:** the editor is `@MainActor`-bound end-to-end. `RichTextState` is `@MainActor @Observable final class`; `RichTextDataSource` is a `@MainActor` protocol with `AnyObject` + `Observable` constraints; `ArrayRichTextDataSource` is `@MainActor @Observable final class`. This is deliberate — TextKit 2, AppKit's `NSTextView`, and UIKit's `UITextView` are all main-thread-only, so pushing the editor model off the main actor would only buy thread hops. `Block`, `BlockContent`, `TextContent`, `TextRun`, and `TextAttributes` are `Sendable` value types so snapshots cross actor boundaries cleanly when a host wants to persist or diff outside the editor.
- **Allocation discipline:** per-mutation, the data source rebuilds the affected `Block` (value type, COW semantics on the contained `[TextRun]`), notifies observers via `[UUID: closure]` lookup, and the bridge re-renders the changed range. The block-navigator rail is driven by the same data source — no second observer chain. The undo stack snapshots `[Block]` arrays; for a multi-megabyte document these snapshots are the dominant per-edit allocation, mitigated by the host's undo-coalescing policy. The `RichTextPrimitiveAI` target is opt-in and adds zero cost when a host doesn't link it.

Reviewed 2026-04-29 (Speed & Clarity round 1, baseline pass); rewritten 2026-05-03 (portfolio sweep — concrete prose).
