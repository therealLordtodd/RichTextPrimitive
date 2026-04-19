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

### Founding Principles

These are the core architectural and philosophical commitments that shape every project in this portfolio. They are not defaults to be overridden — they are the intent behind the work. Every other decision, in this document or elsewhere, should be consistent with these principles.

---

#### Layered Architecture — Primitives, Kits, Host Apps

**Decision:** Every app in this portfolio is built as a thin host layer on top of a stack of shared primitives and kits. Before building any feature or component, check `/Users/todd/Programming/Packages/` for existing primitives and kits that already solve part of the problem — if one exists, use it. When building something novel, always ask: *"Can this feature or component be a primitive or a kit?"* If yes, build it at the primitive or kit layer first, then let the host app wrap it.

**Why:** This is a layered system in the Unix sense — small, sharp, composable foundation pieces that stack into larger capabilities, with host apps as the outermost wrapper. Reuse is not a secondary concern; it is the entire point. Foundation code only becomes solid when it is used everywhere, in real apps, under real load. Every app is both a consumer of primitives and a proving ground that justifies their existence with real usage and bug testing. Re-implementing a capability that already exists in `Packages/` weakens the foundation and forks maintenance across copies that will drift.

**How this shapes decisions:**
- **During design:** browse `Packages/` first. The names are descriptive. Don't rebuild what exists.
- **During implementation:** if new work is even partly general-purpose, extract it as a primitive or kit *before* the host app depends on it.
- **During review:** duplicating existing primitive functionality is a code review finding, not a stylistic preference.

---

#### Built for Humans and AI Together

**Decision:** As far as is reasonable, every app in this portfolio is designed for both human and AI operation. AI agents are first-class operators of these apps, not observers. Every app is wired into the four backbone packages that give AI the ability to interact with, debug, and use the software we build:

- **AISeamsKit** — the controllability seam. Exposes app surfaces so AI can act on them.
- **Marple** — app inspection. Lets AI introspect the structure and state of running UI.
- **LoggingKit** — structured logging. Gives AI a filterable, queryable event stream of what the app is doing in real time.
- **Ansel** — screen capture. Lets AI visually perceive what is on screen.

An app that is not wired into these backbone packages is a human-only app, not a collaboration app.

**Why:** This whole adventure is a giant collaboration engine. Our apps are the places where humans and AIs do work *together* — not just UIs that humans drive while an AI watches from the outside. An AI that cannot see, name, or act on a surface cannot collaborate on it; it can only give advice. The four backbone packages are what turn a human app into a collaboration app: perception (Ansel), introspection (Marple), observation (LoggingKit), and action (AISeamsKit).

Several entries later in this document — the UI element naming convention, the centralized logging architecture, the style check — exist *because* of this principle. They are the mechanical implementation of "the AI can reach this." When a design decision affects whether an AI can operate a surface, this principle is the tiebreaker.

**How this shapes decisions:**
- New features are designed with the question *"Can an AI do this?"* If no, document why.
- New UI elements are named and exposed — anonymous inline controls are invisible to AI and violate this principle.
- New apps integrate AISeamsKit, Marple, LoggingKit, and Ansel by default, not as a follow-up. Adding them retroactively is harder than wiring them in from day one.

---

### Portfolio-Wide Decisions (Pre-Filled)

These are the conventional choices that follow from the Founding Principles above — tooling, process, and style defaults that apply across the portfolio. Override only with a documented reason.

---

#### Plane for Project Management

**Decision:** Use Plane as the project management system across all projects in this portfolio.

**Why Plane specifically:** Plane is fully open source under a license that permits free use, modification, and distribution without fee or permission. It is actively maintained by a team outside this portfolio — we benefit from ongoing improvements without owning the maintenance burden. It is not the most polished PM tool available, but it is solid, actively developed, and ours to use however we need.

The strategic upside: if we ever need full control over the PM layer — to integrate it more deeply with tooling, to fork it, to modify its behavior — someone has already done the foundational engineering work. We are not locked into a vendor and we are not starting from zero.

**What lives in Plane:** Milestones, issues, sprints, code review findings, and pages for key design docs. **What does not:** ephemeral session annotations, scratch work, and anything that lives naturally in source files (AGENTS.md, style guides, plans).

---

#### Open Source and Permissive Licensing as a Default Preference

**Decision:** When choosing tools, infrastructure, and dependencies, prefer open source with permissive licenses over proprietary alternatives, all else being equal.

**Why:** Vendor lock-in is a long-term cost that is invisible at the start of a project and painful at the end. Open source tools can be forked, self-hosted, modified, and used without recurring fees or permission. When a proprietary tool is clearly superior for a specific capability, use it — but document why and note the lock-in risk.

---

#### UI Element Naming Convention

**Decision:** Every interactive UI element is a named computed property following the `[dataObject][property][ElementType]` pattern. Every ViewModel exposes `uiElementContext`.

**Why:** Named elements are grep-able, referable in natural language, and inspectable by AI agents. Anonymous inline controls are invisible to tooling and create a gap between what the code says and what the AI can reason about. This convention exists because the AI needs to be able to say "the clientNameSearchField" and find it, and the human needs to be able to say "that search field at the top" and have the AI know exactly what they mean.

The full convention and suffix list is in `AGENTS.md` and `Style Guide/Unified Standards.md`. This entry explains why it's a first-class rule rather than a style preference.

---

#### Centralized Logging Architecture

**Decision:** All logging goes through the project's centralized logging facade (e.g., `AppLog`). Never use `print()` or raw logging APIs.

**Why:** Raw `print()` statements are invisible to structured log viewers, cannot be filtered by category or level, and leak into production builds. The 9-file fan-out logging architecture (facade → multiple sinks → error log) exists because developer observation of a running system requires structured, filterable, searchable output — not a stream of undifferentiated strings. The architecture spec is in `Style Guide/platform-notes/Apple Apps.md`.

---

#### Automated Style Check in Build Pipeline

**Decision:** Every Apple app target includes a `Style Check` Run Script build phase that executes `scripts/style_check.sh`.

**Why:** Style and naming checks need to run continuously, not only during ad-hoc reviews. Wiring the check into the build gives immediate feedback in Xcode, keeps conventions visible for humans and AI agents, and reduces drift between style guide intent and actual code.

**Implementation note:** Use non-strict mode (`STYLE_CHECK_STRICT=0`) during active refactor periods and strict mode (`STYLE_CHECK_STRICT=1`) in CI or when hard enforcement is desired.

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
