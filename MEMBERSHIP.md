# RichTextPrimitive — Document Editor Family Membership

This primitive is a member of the Document Editor primitive family. It defines the **block-based rich-text model** consumed by DocumentPrimitive and re-exported through RichTextEditorKit.

## Conventions This Primitive Participates In

- [x] [shared-types](../CONVENTIONS/shared-types-convention.md) — defines RichText block model; imports Typography types
- [ ] [typed-static-constants](../CONVENTIONS/typed-static-constants-convention.md) — not directly
- [x] [document-editor-family-membership](../CONVENTIONS/document-editor-family-membership.md)

## Shared Types This Primitive Defines

- **RichText block model** — block types, inline runs, editor operations, paste-special surface
- Consumed by: `DocumentPrimitive`, `RichTextEditorKit`, hosts

## Shared Types This Primitive Imports

- **Typography types** from `TypographyPrimitive`
- Broader shared infra (not family): `UndoPrimitive`, `ClipboardPrimitive`, `ColorPickerPrimitive`, `DragAndDropPrimitive`, `KeyboardShortcutPrimitive`, `SpellCheckKit`, `SyntaxHighlightPrimitive`

## Siblings That Hard-Depend on This Primitive

- `DocumentPrimitive` — composes RichText into documents
- `RichTextEditorKit` — re-exports RichText surface

## Ripple-Analysis Checklist Before Modifying Public API

1. Changes to the RichText block model are HIGH-RIPPLE — affects DocumentPrimitive's composition + RichTextEditorKit's re-exports + hosts.
2. Changes to editor operations (block manipulation, paste-special, cursor semantics): affects editor UX across every consumer.
3. Consult [dependency audit §5](../docs/plans/2026-04-19-document-editor-dependency-audit.md) for the full ripple map.
4. Typography re-exposure (RichText surfaces some Typography types): changes to those re-exports follow TypographyPrimitive's ripple rules.
5. Document ripple impact in the commit/PR.

## Scope of Membership

Applies to modifications of RichTextPrimitive's own code. Consumers just importing for their own app are unaffected.
