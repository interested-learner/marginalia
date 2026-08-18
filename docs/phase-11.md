# Phase 11 — the first hands-on pass

**Read `CLAUDE.md` first, then this.** `docs/planning.md` says what was built; this file says what the first
finger found and how far through fixing it we are.

Started 2026-08-18, and **closed the same day** — the pass that followed it deleted a whole tab (`docs/phase-12.md`).
Every phase before this one was verified by unit tests, launch arguments and screenshots —
`docs/issues.md` §12 has said since phase 5 that **nothing in this app had ever been tapped.** Nathaniel has
now run it on a device. Six reports came back, two of them crashes, and both crashes sit in code the simulator
physically cannot reach.

This is not a feature phase. It is the pass that closes §12 and §6 at once.

---

## The six reports, diagnosed

| # | What was seen | What it is | Stage |
|---|---|---|---|
| 1 | The tab bar rides up over the keyboard | `RootView` is one `VStack` of content + `TabBar`, and `.ignoresSafeArea(.container,…)` does **not** cover the `.keyboard` region, so the whole stack lifts | 2 |
| 2 | No way to tap off the capture field | Nothing in the app ever unfocuses it — no background tap, no `scrollDismissesKeyboard`, no `onSubmit` (the field is `axis: .vertical`) | 2 |
| 3 | A stream capture can't name a book | Deliberate (spec §Capture) — but nothing can re-file a note afterwards either, so the Inbox is a one-way drawer | 2 |
| 7 | The bar's picker is unpickable, `book · Inbox` is unreadable, and the bar is the weaker capture surface | The second pass, on the fix for 2 and 3. Answered by `→ full note` rather than by a bigger picker — `docs/decisions.md` §18 | 2 |
| 4 | `[●]` crashes the app | Four candidates in `SpeechTranscription`, ranked in stage 1a. The file has never executed | 1 |
| 5 | The map jolts when a node is tapped | The panel is a `VStack` sibling of the canvas: selecting shrinks the canvas ~120pt, which changes `plan.aspect`, which re-runs the whole force-directed layout | 3 |
| 6 | Review sticks at the closing card, then crashes | Three compounding defects — a layout feedback loop at the last page, a synchronous `ImageRenderer` inside `body`, and a SwiftData `save()` fired from the scroll callback | 1b |

**There is no zoom or pan on the map at all.** The "double-click zoom" was a second tap on a book hub
expanding into that book (`MapView.tap(_:)`) — a hidden gesture that duplicates the panel's own
`[◇] only this book` button.

---

## Checklist

### Stage 0 — evidence
- [ ] Crash logs off the device (Settings ▸ Privacy & Security ▸ Analytics & Improvements ▸ Analytics Data ▸ `Marginalia-…`, or Xcode ▸ Window ▸ Devices and Simulators ▸ View Device Logs). Reading recipe: `docs/issues.md` §1
- [x] This file

### Stage 1 — the two crashes
**1a · record** — `Services/SpeechTranscription.swift`, `Features/Capture/VoiceCapture.swift`
- [x] Re-entrancy: `record()` sets `.recording` only *after* two permission awaits, so a second tap installs a second tap on bus 0 → uncatchable `NSInternalInconsistencyException`
- [x] `SFSpeechRecognizer.requestAuthorization`'s closure is inferred `@MainActor` and Speech calls it off-thread — `docs/issues.md` §1 verbatim, missed by that entry's own audit
- [x] `@Sendable` on the audio tap and the recognition handler (free if already inferred; a `SIGTRAP` per buffer if not)
- [x] Reject a degenerate input format before `installTap` rather than letting it raise
- [x] `cancel()` guarded on `isRunning`; `finish()` must not overwrite a parked continuation

**1b · review** — `Features/Review/ReviewView.swift`, `ReviewCard.swift`
- [x] `ImageRenderer` out of `body` — it renders a ~6–9 MB bitmap per realized card per body pass
- [x] Reserve the `↑ swipe up for next` hint's height so the scroll container never resizes
- [x] Inner card `ScrollView` disabled when the content fits
- [x] Surfacing deferred off the scroll callback
- [x] `keepGoing()` — **resolved differently.** There is no scroll to add: the closing card carries the id `today.count`, so appending puts the first new note in the exact slot the reader is standing on. The geometry doesn't move and the card's content becomes the next note. Scrolling would animate *backwards* past the eight cards just inserted above the closing card, to arrive where you already were. The haptic is now fired by hand, because `position` genuinely doesn't change
- [x] `today` holding live `Note` references — **considered, not reachable.** Review has no delete affordance ("review is a reading surface", `docs/issues.md` §0), so deleting needs another tab — and `RootView` switches tabs with a `switch`, which destroys `ReviewView` and its `@State` with it. The set is rebuilt on return. Left alone rather than refactored on speculation

### Stage 2 — the capture bar
- [x] Tab bar hidden while the capture field is focused (**not** `.ignoresSafeArea(.keyboard)` on the root — that would pin the bar behind the keyboard too)
- [x] Tap off / drag to dismiss, leaving the draft intact — **revised.** The tap was on the `LazyVStack`'s background, which is exactly the part a stream with notes in it covers: every tap landed on a row and the row swallowed it. It is a scrim over the header, chips and feed now, present only while the field has focus
- [x] `BookPickerField` extracted out of `CaptureSheet`, shown in the bar **only while focused** — **and taken back out of the bar the next day.** Too small to use at 40pt rows in a 240pt box above the keyboard, and `book · Inbox` closed read as a choice nobody had made. Replaced by `→ full note`, which carries the draft into `CaptureSheet`. `docs/decisions.md` §18
- [x] The Inbox is `— no book —` in the picker, not a row: `nil` and the Inbox's own `Book` were two indistinguishable routes into the same drawer
- [x] `CaptureSheet` takes `text:` and reports `onSaved`, so escalating is never destructive — cancel and the draft is still in the bar
- [x] `NoteWriter.refile(_:to:)` + `move to book…` in a row's long-press menu
- [x] `cancel` beside `■ stop` while recording
- [x] `[+]` and `[●]` stop growing at `xLarge` — at AX5 the save button rendered as `…` inside its own 48pt box and the record button burst its brackets. A marker truncated to an ellipsis has stopped being a marker
- [x] `-moveNote <id>`, since the simulator can't be long-pressed, and `-captureMore 1` for the escalated sheet

### Stage 3 — the map
Two more came out of the AX5 screenshot, which is the sixth time an image has said something a code review didn't:
- [x] Map nodes stop growing at `xLarge` — the layout is told label widths in *characters*, so uncapped type turned the library into a pile of overlapping words
- [x] The foot stops growing too — uncapped it took three quarters of the screen and left the graph a strip
- [x] The foot keeps a constant height, so selecting a node never re-lays out the graph
- [x] `withAnimation` on the `placed` assignment, keeping the `Task.isCancelled` guard
- [x] A second tap on a selected note opens it, like a hub expands
- [x] Node separation floor matched to the 44pt hit area — **closed by deletion.** Phase 12 removed the map (`docs/decisions.md` §21), so there is no canvas to space. The arithmetic below stood and still stands; what changed is that nothing needs it. Originally: **not done, and it can't be done that way.** A hundred and twenty nodes at 44pt each need essentially the whole canvas, so raising the floor makes the graph worse than the overlap does. Written up as `docs/issues.md` §24 with the arithmetic; the real answer is a nearest-node hit test on the canvas, the same thing `nearestEdge` already does for lines
- [x] `web` hoisted out of the body pass — **closed by deletion.** `web` and the file it lived in are gone. The reasoning for leaving it alone was right at the time and is worth keeping for the next time somebody proposes a refactor of the least-verified file in the app on the same pass that is already changing it. Originally: **left alone deliberately.** It is O(N+E) per redraw with a tiny constant, and now that selecting a node no longer resizes the canvas the map barely redraws at all. Removing it means threading `web` through `header`, `canvas`, `panel`, `nearestEdge` and `openAtLaunch` in the least-verified file in the app, on the same pass that is already changing that file. Not worth the risk against a cost nobody can see

### Stage 4 — reading progress comes out
Decided 2026-08-18. `Book.currentPage` had one entry point and one display and was never going to move on
its own. Per-note `page` stays — it is the useful half. See `docs/decisions.md` §17.
- [x] `Book.currentPage`, `Book.progress`
- [x] `BookDraft.current` and its clamping
- [x] The `on p.` field, the progress bar, the `currentPage` writes, the seed's arguments
- [x] `pageCount` **stays** and moves into book detail's byline, so it isn't data nothing shows
- [x] `docs/decisions.md` §17, and the lines struck from `docs/design-system.md` and the spec

### Stage 5 — the general review
- [x] `CaptureDraft.pageNumber` is a byte-identical copy of `TypedPage.parse` — delete it, and write the `TypedPageTests` that never existed
- [x] `ConnectionIndex.build(edges:)` is a computed property read inside a `ForEach` — rebuilt per row, per redraw, on three screens
- [x] `ReviewView.remaining` runs a whole `ReviewSetBuilder` pass per body evaluation to decide one button
- [x] `TabBar`'s hardcoded 26pt home-indicator padding should read the real inset
- [x] `Support/Info.plist` was reformatted by Xcode and lost all four of its comments
- [x] `docs/issues.md` §1's audit claim is wrong and says so about the file that crashed

---

## What can and can't be checked here

Both runtimes, own derived data (`docs/issues.md` §2):

```bash
xcodebuild -scheme Marginalia -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .build build test
xcodebuild -scheme Marginalia -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' \
  -derivedDataPath .build-ios18 build test
```

389 tests in 35 suites must pass on both — it was 402 when this file was written, and phase 12 took 90 `@Test` cases out with the map. Screenshot both appearances **and** `accessibility-extra-extra-extra-large`
after every UI stage and look at the whole image — five real defects on this project were invisible in code
and obvious in a picture.

**Stages 1–3 have a device as their only real verdict**: press `[●]` twice quickly, swipe the full review set
to the closing card and back, and tap `keep going`. Stage 3's other half — tapping around the map watching
whether the graph holds still — was answered instead by the device read that started phase 12: the graph held
still and nobody wanted to look at it. `docs/phase-12.md`.
