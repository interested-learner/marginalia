# Phase 12 — the map comes out

**Read `CLAUDE.md` first, then this.** `docs/planning.md` says what was built; `docs/decisions.md` §21 says
what was decided; this file says what the second evening on a device found and what it cost.

2026-08-18, the day after phase 11. Phase 11 was a defect list — six reports, two crashes, all of them things
the app did wrong. This one is not a defect list. **Nothing was broken.** The map worked, drew the same graph
on both runtimes, had been made legible in 12a and given a readable summary in 12d, and passed every test
written for it.

It was deleted anyway.

---

## What was found

The map was read on a device, and the complaint that came back was **not** that the themes were wrong.

It was that there was **no reason to open it**, and that it **read as a feature rather than a use**.

**That is the load-bearing fact of this phase**, and the reason it outranks everything else in `docs/issues.md`
is worth being exact about: **a better embedder could not have fixed it.** Since phase 6 this repo has treated
one measurement as the gate on the map — §14 proves the simulator cannot compile `NLContextualEmbedding`'s
assets at all, §6 ranks a device run as the most valuable open item in the project — and every phase since has
been waiting on it. Verified contextual-model output would have produced **better themes on a screen nobody
visits**. The measurement could not have changed the verdict, and five phases of work were gated on it.

The second thing found is why the answer was deletion rather than another rebuild.

**The map and review want the same thing, and only one of them has a reason to be opened.**
`docs/decisions.md` §4 gives review the two properties that bring somebody back: it is a **ritual**, and it
**ends**. The map had neither — unbounded, always available, never different, therefore never urgent. A
**crossing** — the same idea reached from two different books, months apart — is *literally* running into your
own thinking again, which is what §4 says review is for. It had been sitting in `MapView.crossingRows` as a
computed property on a screen nobody opened, and it is the best thing the linking engine computes.

**§20 is one day old, and it is not being called wrong.** It recorded the same complaint one level shallower —
*"the tab still had no takeaway"* — diagnosed it as illegibility, and answered by rebuilding the room. The
diagnosis was correct about the drawing: a node labelled `n.07` is an opaque handle and a canvas of forty-six
of them is a picture nobody can read. The summary that replaced it was a better screen than the canvas by
every measure §20 named. It was answering the wrong question. **Legibility was never what kept anyone out.**

---

## What was built

- **`RelativeTime.gap`** — `29 days apart`, `7 months apart` — a fourth function beside `label`, `dayLabel`
  and `elapsed`. Numerals, lowercase, and a guard against a negative interval, like `label` already carries.
- **`CrossingFinder`** — pure, the same shape as `ReviewSetBuilder`: plain models and a date in, one crossing
  out, no `ModelContext`. Cross-book only · the Inbox excluded (found by status and not a source — the third
  place it is special, after `BookWriter` and `Eraser`) · suppressed edges excluded, which is what makes
  `[x] not related` stick · **one appearance per note**, a display rule rather than a claim about the data ·
  strongest first with ties on the pair id.
- **Ranked, rotating, never thresholded.** The day picks `crossings[daySeed % count]`, so the reader walks the
  ranked list an entry at a time and it cycles rather than repeating one pair forever. Rejected: a
  `lastShownAt` on `NoteEdge` — a schema change bought for a rotation — and always showing the strongest,
  which shows one pair every day until it is suppressed. `daySeed` was private to `ReviewSetBuilder` and is
  now `internal`, so there is one definition of what a day is.
- **The fallback rotates too.** When every candidate overlaps the day's own eight notes, `CrossingFinder`
  rotates over the whole ranked list rather than pinning the strongest. Pinning it there would show one pair
  every day on a small library — the exact failure rotation exists to prevent, and a small library is
  precisely where the overlap happens. `docs/specs/2026-08-18-crossings-design.md` said *shows the best one
  anyway* and was wrong about both the code and the design; it has been corrected.
- **`CrossingCard` + `CrossingCardData`**, wired into `ReviewView` as a ninth card between the eight notes and
  the closing card. Two halves at `noteBody` rather than `reviewBody` — at 18pt each the second half is below
  the fold before the reader has a reason to look for it, and the gap between them is the point of the card. A
  `Hairline` between them and **never an arrow**: `NoteEdge` stores a direction and the app has displayed both
  ways since phase 6.
- **Paging past a crossing surfaces nothing.** `ReviewWriter` is not called for it — marking both notes
  surfaced would quietly reshape tomorrow's eight, because `ReviewSetBuilder` scores on exactly that field.
- **`[x] not related`, through `ConfirmSheet` and `Eraser.suppress`** — the first feedback loop in the linking
  system. Since phase 6 the app has guessed at meaning and nothing anywhere could tell it it guessed wrong. An
  affordance, never a question: it does not gate paging, it is not asked for, and skipping it costs nothing,
  so §10's promise that nobody is asked to link anything is unbroken.
- **`-reviewCrossing 1`**, because the simulator cannot be swiped to the ninth card.
- **`Glyphs.tabMap` became `Glyphs.crossing`**, same `[◇]`. The vocabulary did not grow.

---

## What was deleted, measured

**24 files changed, 12 insertions, 4,082 deletions.** Sixteen files removed:

| | |
|---|---|
| `Features/Map/` | `MapView` · `MapRows` · `ThemeDetailView` · `GraphView` · `GraphCanvas` · `MapGraph` |
| `Services/` | `ThemeEngine` · `ThemeName` · `NounPhrases` · `GraphLayout` |
| `MarginaliaTests/` | six files |

**The suite went from 479 tests in 42 suites to 389 in 35** — 90 `@Test` cases. Both figures verified on
iPhone 17 **and** on iPhone 16 / iOS 18.5, own derived data each (`docs/issues.md` §2).

Also gone: the `map` tab, the `web` / `openWeb` cross-tab route (the app's first, now with nothing at the far
end), `[◇] connections` in **both** places it was offered — the stream row's long-press menu and the review
card's action row, which drops from three rows of two to two rows and a single — and eight launch arguments:
`-startTab map`, `-mapSelect`, `-mapNote`, `-mapBook`, `-mapTheme`, `-mapThemeGraph`, `-mapCrossings`,
`-mapLines`. **`-confirmDelete connection` was repurposed rather than deleted** — it read out of
`GraphView` and now reads out of `ReviewView.openAtLaunch`, opening the disconnect confirmation over the
crossing card. It survives because `[x] not related` is a button on the ninth card, and the simulator can
neither swipe to that card nor tap that button; without the argument the sheet could never be screenshot.

**`GraphLayoutTests` is the loss worth naming**: nineteen tests over genuinely hard geometry — convergence
measured as residual force rather than step size, gravity derived rather than tuned, a budget that grows with
the library — all correct, none with a consumer any more.

**Three tabs: stream · books · review.**

### What closed by deletion rather than by being fixed

- **`docs/issues.md` §24** — the map's tap targets overlap above ~100 nodes, with the arithmetic showing the
  obvious fix was not physically available. The second-hardest open bug in the app.
- **`docs/issues.md` §17** — the map's four gestures were built and none was ever performed, including the
  app's only destructive gesture with no visible affordance. `[x] not related` replaces the hold-a-line
  disconnect and is a labelled button on a card.
- **Both of `docs/phase-11.md` stage 3's remaining items**, which were the two things that pass declined to do
  to the least-verified file in the app.

### What survives, and gets more load-bearing

`NoteEmbedding`, `AffinityEngine`, `LinkWriter`, `ConnectionIndex`, `NoteEdge`, `Eraser.suppress`,
`AffinityDumpTests`. Backlinks go on being drawn under every note on stream, book detail and the review card.
`NotePicker` and `→ link` stay — the manual override outlives the screen it was built beside. **Nothing about
the linking engine changed in this phase.** What changed is where its output is read.

---

## What went wrong in the sweep

**`ThemeIsolationTests.swift` was deleted by mistake, and restored the same day.** Four test files began with
`Theme`; three of them tested `ThemeEngine` and `ThemeName` and were right to go. The fourth tests `Theme` —
the color enum, which is very much still here — by resolving colors from a detached task, and it is the guard
on the worst crash class in this project's history (`docs/issues.md` §1, five identical `EXC_BREAKPOINT`s).

**The suite was green without it**, which is the whole problem: the file that fails when `Theme` loses
`nonisolated` was the file that had been removed, so nothing reported its absence. It was caught in the
documentation pass and restored verbatim from `8321340^` before the branch merged, which is why the counts
above are 389 in 35 rather than 386 in 34. §1 records it as a caught over-deletion rather than an open bug.

A name is not an argument. That is the third time this document family has had to write that sentence.

---

## What can and can't be checked here

Both runtimes, own derived data (`docs/issues.md` §2):

```bash
xcodebuild -scheme Marginalia -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .build build test
xcodebuild -scheme Marginalia -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' \
  -derivedDataPath .build-ios18 build test
```

**389 tests in 35 suites**, one of them a recorded known issue (`NoteEmbeddingTests`, see phase 6). Verified on both.

### Checked

- **The crossing card renders in both appearances.** Head `n.08 · n.40 · [◇] crossing`, two notes separated by
  a hairline, foot `29 days apart · [x] not related`. Reached with `-reviewCrossing 1`.
- **The disconnect confirmation renders over it.** `-startTab review -confirmDelete connection -reviewCrossing 1`
  puts `disconnect n.08 and n.40?` on screen over the card, with `[x] disconnect` filled `danger` and `cancel`
  beneath it — the app's own `ConfirmSheet`, not a system dialog. The header still clamps to `8 of 8`.

### Not checked, and to be said plainly rather than implied

- **The accessibility sizes.** `accessibility-extra-extra-extra-large` has **not** been run against the
  crossing card, and it is the next thing to do. **Two full notes on one screen is the first card in this app
  designed to hold two**, so this is where it will break if it breaks. It inherits `ReviewCard`'s
  scroll-only-when-it-overflows guard, fixed in phase 11 and about to get its real test. Five defects on this
  project were invisible in code review and obvious in a picture.
- **Nothing was tapped.** `[x] not related` has never been pressed, the crossing has never been swiped to, and
  the `erased` haptic has still never been felt — the simulator has no Taptic Engine.
- **Whether any crossing is *true*.** This is unchanged and it is the one thing this phase did not move.
  Crossings ride on exactly the same scores backlinks do, and `docs/issues.md` §14 means every score anybody
  has ever looked at came out of the `NLEmbedding` fallback, which measurably does not measure meaning at note
  length. **A device and `AffinityDumpTests` are still the only answer**, and §14 and §6 stay open. What
  changed is the size of what they decide: an ordinary quality question about two notes on a card, rather than
  the fate of a tab.

---

## The thing to hold on to

**If the crossing card is opened for a month and skipped every time, the conclusion is not that it needs a
better screen.** There have now been three drawings of this idea — a force-directed canvas, a filtered
canvas, a ranked summary — and each was better than the last and none of them was opened. A fourth would be
the same mistake with a different shape.

It would mean that automatic linking is interesting to build and not interesting to read, and that is
`docs/decisions.md` §10's own flagged risk coming true, written down before any of this existed:

> **Known risk:** because nobody types a link, nobody learns the habit. If automatic linking underdelivers
> there's no fallback behavior to lean on.

That would be worth knowing. There is now exactly one screen where it can be observed, and one button on it
where the reader can say so.
