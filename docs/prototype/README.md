# Prototype archive

The Claude Design prototype marginalia was built from. Archived here so the visual reference is always available without a network call.

**Source:** https://claude.ai/design/p/b3f09479-46c7-4206-b77c-17b7c31f7fe2?file=Marginalia.dc.html
**Project id:** `b3f09479-46c7-4206-b77c-17b7c31f7fe2`
**Captured:** 2026-08-13

## Files

| File | What it is |
|---|---|
| `Marginalia.dc.html` | The prototype. Two turns — turn 1 explores three directions (`1a` books-first, `1b` stream, `1c` index card), turn 2 develops `1b` into the interactive prototype `2a` |
| `colors_and_type.css` | The OpenCode design system's tokens — the source the values in `docs/design-system.md` were lifted from |

## What to look at

**`2a` is the one that matters.** It's the developed direction and the basis for the app: stream home with tag chips and a persistent capture bar, books tab with detail view, review tab, note links, and an Inbox for quick captures.

`1c` is worth a look for context on the review tab — its keep/skip/later card is what the shipping design deliberately rejects. See `docs/decisions.md` §4.

## Reading it

The file is a Claude Design document: markup with `{{ binding }}` placeholders, `<sc-if>` / `<sc-for>` control flow, and a `DCLogic` class at the bottom holding the state and the seed data. It renders inside an iPhone frame from `ios-frame.jsx`, which is prototype scaffolding and has no counterpart in the app.

Open it in a browser to see it rendered, or read the `<script type="text/x-dc">` block at the end for the behavior and the seed books.

## Where the app departs from it

The prototype is the authority on **look**. `docs/specs/2026-08-13-marginalia-design.md` is the authority on **behavior**, and it overrides the prototype in several places — most significantly the review tab, which drops `keep / skip / later` for full-screen paged cards with follow-up threads and stars.

Don't edit these files. They're a reference artifact; the point is that they still show what was originally designed.
