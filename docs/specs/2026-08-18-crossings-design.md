# The map comes out; a crossing becomes a card

**2026-08-18 · design · supersedes `docs/decisions.md` §11, §19 and §20**

Approved in conversation before any code was written. `docs/decisions.md` §21 is the short form of this
document; this is the reasoning behind it.

---

## What changed, and it is not the model

Since phase 6 this repo has treated one question as the gate on everything the map does: **is the embedder
any good?** `docs/issues.md` §14 proves the simulator cannot run `NLContextualEmbedding` at all, §6 ranks a
device run as the most valuable open item in the project, and §20 built an entire summary screen while saying
plainly that rank-invariance "fixes scale, not signal."

The map was then read on a device for the first time, and the complaint that came back was **not** that the
themes were wrong.

It was that there was **no reason to open it**, and that it **read as a feature rather than a use**.

That is a different failure, and it is worth being exact about why it outranks the other one: **a perfect
embedder does not fix it.** Verified `NLContextualEmbedding` output would have produced better themes on a
screen nobody visits. Every phase since 6 has been waiting on a measurement that could not have changed the
verdict.

§20 recorded the same complaint one level shallower — *"the tab still had no takeaway"* — and answered it by
rebuilding the screen. This answers it by deleting the room.

## The premise underneath

**The map and review want the same thing, and only one of them has a reason to be opened.**

`docs/decisions.md` §4 says review exists for *running into your own thinking again*, and gives it the two
properties that make somebody come back: it is a **ritual**, and it **ends**. The map has been a second
surface competing for that same instinct with neither property — an unbounded summary, always available,
never different, and therefore never urgent.

A **crossing** — the same idea reached from two different books, months apart — is *literally* running into
your own thinking again. It has been sitting in `MapView.crossingRows` as a computed property on a screen
nobody opens, and it is the best thing the linking engine computes.

So it moves to where the reader already is.

## The crossing card

A card in the daily review that is two notes rather than one. Read-only, one screen, paged like every other
card.

```
n.03 · n.19 · [◇] crossing

good error messages assume the
system is at fault, not the person
using it

— Norman · p. 62 · aug 2025

────────────────────────────────────

you are already part of the machine
you think you are repairing

— Pirsig · p. 210 · mar 2026

7 months apart · [x] not related
```

Three things carry the card, and **none of them is a claim the model makes**:

- **Two books.** A fact about where the notes were written.
- **The gap in time.** A fact about when — and the one that makes it land. *You thought this in August and
  again in March and never noticed.*
- **A hairline between them, never an arrow.** `NoteEdge` stores direction and the app has displayed both
  ways since phase 6 (`CLAUDE.md`: *backlinks are always shown*). A `→` here would be the first place the app
  contradicted that.

`Glyphs.tabMap` is free once the tab dies, so `[◇]` becomes `Glyphs.crossing`. The vocabulary does not grow.

### `[x] not related` — the one action, and the argument for it

It calls `Eraser.suppress` through `ConfirmSheet`, exactly as the map's disconnect did. Not straight to the
eraser: `CLAUDE.md` says every delete goes through one door and `erased` fires from that button.

**This is the first feedback loop in the entire linking system.** Today the app makes a guess about meaning
and the reader has no way, anywhere, to say it was wrong. Given that §14 means no human has ever seen output
from the model the design is built on, a reader's own "no" is worth more than any amount of tuning the floor
— and `CLAUDE.md` forbids that tuning anyway, for the reason phase 6 gave.

It is an affordance, never a question. It does not gate paging, it is not asked for, and skipping it costs
nothing. **Zero-work stays zero-work.**

Everything else a note can do — `star`, `add a thought` — is reached by tapping either note, which opens it
in the stream where those actions already live. The card does not duplicate them; `ActionRow`'s own comment
records that four labels already overflow a phone at 13pt mono.

### When it appears

- **At most one a day**, and only when an unshown crossing exists. It is punctuation in the set, not half of
  it.
- **Appended after the eight notes, before the closing card.** The day still ends where it ended.
- **Day-stable, and it rotates.** The crossings are ranked once, stably; the day picks
  `crossings[daySeed % crossings.count]`. `daySeed` advances by one a day, so the reader walks the ranked list
  an entry at a time and it cycles rather than repeating one crossing forever. **No new stored state and no
  model change** — the alternatives were a `lastShownAt` on `NoteEdge` (a schema change, for a rotation) or
  always showing the strongest (which shows one pair every day until it is suppressed). `daySeed` is private
  to `ReviewSetBuilder` today and becomes `internal` so both can use one definition of what a day is.
- **It avoids the day's own notes where it can.** `CrossingFinder` is told which ids are already cards, and
  skips candidates that overlap them; if every candidate overlaps, it shows the best one anyway rather than
  showing nothing. Seeing `n.03` as card 2 and again as half of card 9 is a small oddity; suppressing the
  feature on a small library is a bigger one.
- **Paging past a crossing surfaces nothing.** `ReviewWriter` is not called for it. The crossing is extra, and
  marking both notes surfaced would quietly reshape tomorrow's eight — `ReviewSetBuilder` scores on exactly
  that field.
- **`ReviewSetBuilder` does not change at all** beyond `daySeed`'s visibility. A new pure `CrossingFinder`
  returns the day's crossing and `ReviewView` composes the two.

## `CrossingFinder`

Pure, in the sense the rest of this repo means it: plain values in, plain values out, no `ModelContext` — the
same shape as `ReviewSetBuilder`, which likewise takes `[Note]` and a `Date`.

It is where `MapView.crossingRows` goes, with its rules intact:

- **Cross-book only.** Both notes must have a book, and the books must differ.
- **The Inbox is not a book.** A crossing prints `— Norman · p. 62`; an unfiled capture has nothing to put
  there. `BookWriter` and `Eraser` already treat the Inbox as a special case found by status, and this is the
  third.
- **Suppressed edges are excluded**, which is what makes `[x] not related` stick. `docs/decisions.md` §15:
  suppression *is* the memory of the deletion, and it must be, because every recompute is a full one and
  would otherwise redraw the same pair.
- **One appearance per note.** A display rule, not a claim about the data — the hub behaviour phase 6 measured
  (`n.02` and `n.13` turn up in half the shortlists; mutual k-NN does not stop it at forty notes) put `n.18`
  in three consecutive rows the first time this screen ran.
- **Strongest first, ties on the pair id** — the tie-break `AffinityEngine` and `ReviewSetBuilder` both use,
  for the reason phase 6 gave: a screen that reshuffles on every launch reads as the app changing its mind.

`RelativeTime` grows a fourth function, `gap`, beside `label` / `dayLabel` / `elapsed`. Numerals, lowercase,
and a guard against a negative interval, like `label` already has.

## What comes out

**2,764 lines of app code:**

| | lines |
|---|---|
| `Features/Map/` — `MapView`, `MapRows`, `ThemeDetailView`, `GraphView`, `GraphCanvas`, `MapGraph` | 1,779 |
| `Services/ThemeEngine` · `ThemeName` · `NounPhrases` | 644 |
| `Services/GraphLayout` | 341 |

**1,230 lines of tests — 92 `@Test` cases** — plus `ThemeDumpTests`. The suite goes from 402 to roughly 310.
`GraphLayoutTests` is the loss worth naming: nineteen tests over genuinely hard geometry, all correct, none
with a consumer any more.

**Wiring:**

- `Tab.map`; `Glyphs.tabMap` → `Glyphs.crossing`, same `[◇]`
- `web` / `openWeb` in `MarginaliaApp` — the app's first cross-tab route, now with nothing at the far end
- `[◇] connections` in **both** places it is offered: the stream row's long-press menu (`Rows.swift`) and the
  review card's action row, which drops from three rows of two to two
- Eight launch arguments: `-startTab map`, `-mapSelect`, `-mapNote`, `-mapBook`, `-mapTheme`,
  `-mapThemeGraph`, `-mapCrossings`, `-mapLines`. `-confirmDelete connection` is **repurposed** onto the
  crossing card rather than deleted

**Three tabs: stream · books · review.**

## What survives, and gets more load-bearing

`NoteEmbedding`, `AffinityEngine`, `LinkWriter`, `ConnectionIndex`, `NoteEdge`, `Eraser.suppress`,
`AffinityDumpTests`. Backlinks go on being drawn under every note on stream, book detail and the review card.
`NotePicker` and `→ link` stay — the manual override outlives the screen it was built beside.

**`docs/issues.md` §14 does not close, and should not.** The device read of `AffinityDumpTests` still matters,
because backlinks and crossings ride on the same scores. What changes is that it stops being a gate on a whole
tab and becomes an ordinary quality question about a line of text under a note.

## What closes by deletion

- **`docs/issues.md` §24** — the map's tap targets overlap above ~100 nodes, with the arithmetic showing the
  obvious fix is not physically available. The second-hardest open bug in the app, closed because the screen
  stops existing.
- **`docs/issues.md` §17** — the map's gestures have never been made.
- Both of `docs/phase-11.md` stage 3's remaining items.

## Verification

**New tests.** `CrossingFinderTests`, mirroring `ReviewSetBuilderTests` in shape: cross-book only · the Inbox
excluded · suppressed edges excluded · one appearance per note · strongest first with the tie-break · stable
within a day · **rotating across consecutive days, and cycling rather than exhausting** · avoiding the day's
own note ids where a candidate allows and falling back to the strongest where none does · `nil` on a library
with no cross-book edge, leaving review exactly as it is today. `RelativeTimeTests` grows `gap`: same day, days, months, negative interval.

**Regression.** ~310 tests on iPhone 17 and on iPhone 16 / iOS 18.5, own derived data each
(`docs/issues.md` §2).

**Screenshots, and this is where the defect is expected.** New launch argument `-reviewCrossing 1`, because
the simulator cannot be swiped to the ninth card. Both appearances, then
`accessibility-extra-extra-extra-large`. **Two full notes on one screen is the first card in this app designed
to hold two**, and AX5 is where it breaks. It inherits `ReviewCard`'s scroll-only-when-it-overflows, fixed in
phase 11 and about to get its real test. Five defects on this project were invisible in code review and
obvious in a picture.

**Not checkable here**, and to be said plainly rather than implied: whether any crossing is *true* — that is
the device and `AffinityDumpTests`, unchanged — and the `erased` haptic, which nobody has ever felt.

## The argument against, recorded rather than answered

**§20 is one day old.** Deleting it the next morning is either good judgment or thrash, and the difference is
whether *no reason to open it* is a durable read or a first impression.

It was taken as durable, because it is the same complaint §20 recorded about its own predecessor, answered one
level deeper. §11 wrote the escape clause — *"if the map doesn't earn its place in use, it moves back inside
Books"* — and §20 invoked it by rebuilding. This invokes it as written.

**If the crossing card is opened for a month and skipped every time**, the conclusion is not that it needs a
better screen. It is that automatic linking is interesting to build and not interesting to read, and that
would be worth knowing about a feature `docs/decisions.md` §10 already flagged: *because nobody types a link,
nobody learns the habit — if automatic linking underdelivers there is no fallback behavior to lean on.*
