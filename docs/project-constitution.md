# RichTextPrimitive — Project Constitution

**Created:** 2026-04-16
**Authors:** Todd Cowing + Claude (Opus 4.7)

This document records the *why* behind foundational decisions. It is written for future collaborators — human and AI — who weren't in the room when these choices were made. The development plan tells you what we're building. AGENTS.md tells you how to build it. This document tells you why we made the decisions we made, and where we believe this is going.

Fill in the project-specific sections as decisions are made. The **Founding Principles** apply to every project in the portfolio without exception — they are the intent behind the work. The **Portfolio-Wide Decisions** are pre-filled conventional choices that follow from those principles; they apply unless explicitly overridden here with a documented reason.

---

## What RichTextPrimitive Is Trying to Be

RichTextPrimitive is the block-based editing layer in the portfolio's document stack. It provides a portable rich-text block model, a data-source protocol for mutable editor content, a cross-platform SwiftUI editor surface, undo and spell-check integration, paste-special and block-editing services, and an optional AI product for tool-driven document editing. It is for apps that need structured editing — block-level operations, durable model semantics, and testable editor services — not for apps that only need a plain `TextEditor` or markdown field. The central insight is that a block model is the right source of truth for non-trivial text editing, with platform text views as a rendering bridge rather than the durable store.

---

## Foundational Decisions

### Shared Portfolio Doctrine

The shared founding principles and portfolio-wide defaults now live in the Foundation Libraries wiki:

- `/Users/todd/Library/CloudStorage/GoogleDrive-todd@cowingfamily.com/My Drive/The Commons/Libraries/Foundation Libraries/operations/portfolio-doctrine.md`

Use this local constitution for project-specific decisions, not copied portfolio boilerplate.

---

### Project-Specific Decisions

*Add an entry here for every significant architectural, tooling, or directional decision made for this project. Write it at decision time, not retroactively. Future collaborators need to understand the reasoning, not just the outcome.*

*Initial decisions summarized from CLAUDE.md:*

#### `RichTextDataSource` Is the Mutation Boundary

**Decision:** All editor mutations flow through the `RichTextDataSource` protocol. Views and services do not edit block arrays behind the source.

**Why:** A single mutation boundary is the seam that keeps the model portable and testable. Hosts can swap in custom data sources for persistence, collaboration, or auditing without the editor view's internals needing to change. Mutating behind the data source would fork state between the live view and the stored model.

**Trade-offs accepted:** Every mutation must go through the protocol even when a direct array edit would be simpler. Hosts that want custom data sources must implement the full surface the editor relies on.

---

#### AI Layer Is a Separate Product

**Decision:** The `RichTextPrimitiveAI` target (DocumentAITool, DocumentAIContext, BlockMutation, tool providers) is a distinct product that depends on the core, not the reverse. The core target does not import AI types.

**Why:** Apps that just want a block editor should not pull AI-facing concepts into their dependency graph. Keeping AI in a separate product preserves optionality without weakening the AI-collaboration story for hosts that want it.

**Trade-offs accepted:** Hosts that want AI editing must adopt a second product. Contributors must not introduce AI imports into the core target.

---

#### TextKit 2 Bridge Is the Rendered Storage Source

**Decision:** `RichTextContentBridge` owns the TextKit 2 rendered attributed storage. macOS and iOS layout-manager attachment paths stay symmetric.

**Why:** Rich text editing needs a platform text view for real typing, selection, and input method handling, but the durable model must stay cross-platform. A single bridge with symmetric platform paths is how the package keeps feature parity between macOS 15 and iOS 17 without forking behavior.

**Trade-offs accepted:** The bridge adds surface area and requires both platform paths to be implemented together. Changes that break symmetry are rejected as violations of this rule.

---

*Add more entries as decisions are made.*

---

## Tech Stack and Platform Choices

**Platform:** macOS 15+ and iOS 17+ (cross-platform Swift package)
**Primary language:** Swift 6.0
**UI framework:** SwiftUI with internal AppKit/UIKit bridges via TextKit 2
**Data layer:** In-memory `ArrayRichTextDataSource` by default; host apps own durable persistence behind the `RichTextDataSource` protocol

**Why this stack:** This is the editor engine at the heart of the portfolio's writing surface. Swift 6 with SwiftUI keeps it consistent with the rest of the editor stack, while a platform bridge is unavoidable because real text input and selection are platform-native. The block-based data source keeps the durable model portable and testable even though rendering goes through platform text views.

---

## Who This Is Built For

*Who are the primary users or operators of this software? Humans, AI agents, or both? This shapes everything from UI density to conductorship defaults.*

[ ] Primarily humans
[ ] Primarily AI agents
[ ] Both, roughly equally
[ ] Both — humans build it, AIs operate it
[X] Both — AIs build it, humans operate it

**Notes:** Foundation primitive consumed by host editor apps. Humans write in the editors built on top of this package; AIs build and maintain the package itself, and can also drive editing tools through the `RichTextPrimitiveAI` product.

---

## Where This Is Going

[To be filled in as project direction crystallizes.]

---

## Open Questions

*None recorded yet.*

---

## Amendment Process

Use this process whenever a foundational decision changes or a new decision is added.

1. Update the relevant section in this constitution in the same change as the code/docs that motivated the update.
2. For each new or changed decision entry, include:
   - **Decision**
   - **Why**
   - **Trade-offs accepted**
   - **Revisit trigger** (what condition should cause reconsideration)
3. Add a matching row in the **Decision Log** with date and a concise summary.
4. If the amendment changes implementation rules, update `AGENTS.md` and any affected style guide files in the same change.
5. Record who approved the amendment (human + AI collaborator when applicable).

Minor wording clarifications that do not change meaning do not require a new decision entry, but should still be noted in the Decision Log.

---

## Decision Log

*Brief chronological record of significant decisions. Add an entry whenever a non-trivial decision is made that isn't already captured in the sections above.*

| Date | Decision | Decided by |
|------|----------|------------|
| 2026-04-16 | Constitution created and Founding Principles established | Both |
