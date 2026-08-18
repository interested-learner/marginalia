# Planning

Where the project stands and what happens next. **Read this first in a new session**, then `CLAUDE.md` for the rules.

Last updated 2026-08-18, after phase 12 — the map came out and a crossing became a card.

---

## State

**Phase 11 is the first time anybody used this app.** Read `docs/phase-11.md`. Ten phases were verified by unit tests, launch arguments and screenshots; `docs/issues.md` §12 said plainly that nothing here had ever been tapped, and on 2026-08-18 somebody finally did. Six reports came back and **two of them were crashes** — the record button and the end of the review set — in code paths a simulator physically cannot reach. Neither was visible in code review, in a full passing suite, or in any screenshot taken in ten phases.

The ratio is the finding, and it is worth writing down rather than getting past: **one session with a finger found more real defects than the whole of phase 10's screenshot pass.** Two of them had been shipped since phase 3 and phase 5.

The app **builds clean, runs on the simulator in both appearances — Debug and Release — and passes 389 tests in 35 suites (one of them a recorded known issue — see phase 6 below).** Every screen reads from SwiftData, and the app writes notes, books *and* follow-ups: `[+]` in the stream bar files a thought into the Inbox with a fresh id, the full sheet files one against a book, books arrive by Open Library search or barcode or by hand, and review pages through a day-stable set of eight whose actions all do something.

**And now removes them.** Notes, books and follow-ups all delete, through `Eraser` and the app's own confirmation — see the issues pass below.

**And now connects them.** Phase 6 landed: every note is vectorized on save, `AffinityEngine` scores every pair, and the connections that survive its three constraints are written as edges and drawn on the stream, on book detail and on the review card. Nobody was asked to link anything.

**And drew them, for five phases.** Phase 7 built the map — `GraphLayout`, `MapGraph`, a real force-directed graph — 12a made it legible, 12d made it a summary, and **phase 12 deleted all of it.** The connections themselves were never the problem and are untouched; the screen that drew them had no reason to be opened. `docs/decisions.md` §21.

**And now finds them, exports them, and comes back for them.** Phase 8 landed: one field searches every note, thread, book, author and tag; the library leaves as one Markdown document; settings carries the appearance, the reminder, the export and *rebuild connections*; and one notification a day is scheduled seven ahead, each one carrying the actual text of the note it will open.

**And the three things earlier phases wrote down and left are done.** `→ link` on a review card writes a pinned edge, so `isPinned` finally has a writer. The recompute was measured rather than argued about — and made twice as fast on the way past, with the graph unchanged. And both missing routes existed: a source line's book title opens the book, and `[◇] connections` opened a note's own corner of the map — that second one went with the map in phase 12.

**And now reads them off the page.** Phase 9 landed: `[s] scan` is the fourth capture type, the type selector is two rows of two, and VisionKit's scanner in text mode turns tapped lines into a passage that lands in an editable field. **The camera itself has never run** — no simulator has one, so what was seen here is the written fallback, exactly as the barcode has been since phase 4.

**And now it has a face, and it survives the largest text somebody can ask for.** Phase 10 landed: the app icon exists — `[m]`, rendered from a committed script — the app builds and passes **the whole suite on iOS 18.5 as well as 26.5**, chrome stops growing where content doesn't, and there are haptics. Three real defects came out of it and none was visible in code: iOS 26 destroys a transparent tinted icon, the tab bar and the stream header came apart at the accessibility sizes, and the app had been drawing curly quotes for ten phases while `docs/issues.md` recorded that it wasn't.

**Nothing in the app is scaffolding now**, and nothing in the spec is unbuilt except the map, which is unbuilt on purpose. All three tabs read and write the store, every capture type exists, and the placeholder that survived five phases is gone. **What's left is one evening on a real device** — see the open questions below, where it is now the only thing on the list that money or time can't substitute for.

History is one commit per phase on `main` — `git log --oneline` is the authority, not this file. Remote: `interested-learner/marginalia` (public). `gh` is **not** installed on this machine.

### Phases

| | Phase | State |
|---|---|---|
| 0 | Documentation | **done** |
| 1 | Scaffold + design system, four-tab shell | **done** |
| 2 | Model + Stream | **done** |
| 3 | Capture — text, then voice | **done** (voice needs a device) |
| 4 | Books — list, detail, add by search and ISBN | **done** (barcode needs a device) |
| 5 | Review — paged cards, `ReviewSetBuilder`, stars, follow-ups | **done** |
| 6 | Linking — embeddings + `AffinityEngine` | **done** · output read; see below |
| 7 | Map — `GraphLayout`, real graph | **done, then deleted** — phase 12 |
| 8 | Search, export, settings, notifications | **done** (the reminder has never been received — `docs/issues.md` §19) |
| 9 | Camera OCR capture | **done** (the camera needs a device) |
| 10 | Polish, app icon, device install | **done** — except the device, which is nobody's to fake |
| 11 | The first hands-on pass | **done** — `docs/phase-11.md` |
| 12a | The map says which lines are connections | **done, then deleted** |
| 12d | The map becomes a summary — themes, crossings, loose | **done, then deleted the next day** · §20 |
| 12 | The map comes out; a crossing becomes a card | **done** · `docs/decisions.md` §21 · `docs/phase-12.md` |
| 12b | The device run — the embedding verdict | **not started** · needs an iPhone, and it gates 12c. No longer a gate on a screen |
| 12c | A bundled CoreML embedder | **designed, not started** · conditional on 12b |

Full detail for every phase is in `docs/specs/2026-08-13-marginalia-design.md`. The reasoning behind the choices is in `docs/decisions.md` — **don't re-litigate those.**

---

## What phase 12 built

**The map was read on a device, and the complaint was not that the themes were wrong.** It was that there was **no reason to open it**, and that it **read as a feature rather than a use**. That is a different failure from the one this repo had been braced for since phase 6, and it outranks it, because **a perfect embedder does not fix it** — verified `NLContextualEmbedding` output would have produced better themes on a screen nobody visits. `docs/decisions.md` §21.

- **A crossing is now a card in the daily review.** Two notes from two different books that the app connected by meaning, with the gap in time between them — appended after the eight, before the closing card, at most one a day. §4 gives review the two properties that make somebody come back: it is a ritual and it ends. The map had neither, and a crossing is *literally* running into your own thinking again.
- **`CrossingFinder` is pure and rotates.** Cross-book only, the Inbox excluded, suppressed edges excluded, one appearance per note, strongest first with ties on the pair id — then `crossings[daySeed % count]`, so the reader walks the ranked list an entry at a time rather than seeing the same pair forever. **The fallback rotates too** when every candidate overlaps the day's own notes; pinning the strongest there would show one pair every day on a small library, which is the failure the rotation exists to prevent.
- **`[x] not related` is the first feedback loop in the linking system.** Since phase 6 the app has guessed at meaning and nothing anywhere could tell it it guessed wrong. It goes through `ConfirmSheet` and `Eraser.suppress` like every other delete, and suppression is what makes it stick, because every recompute is a full one. An affordance, never a question — skipping it is free.
- **Two halves at `noteBody`, a hairline between them, no arrow.** 18pt each would put the second note below the fold, and the gap between them is the point of the card. An arrow would be the first place the app contradicted *backlinks are always shown*.
- **`RelativeTime.gap`** — `29 days apart`, `7 months apart` — beside `label`, `dayLabel` and `elapsed`.
- New: `-reviewCrossing 1`, because the simulator cannot be swiped to the ninth card.

### What came out, measured

**24 files changed, 12 insertions, 4,082 deletions.** Sixteen files removed: six under `Features/Map/` (`MapView`, `MapRows`, `ThemeDetailView`, `GraphView`, `GraphCanvas`, `MapGraph`), then `ThemeEngine`, `ThemeName`, `NounPhrases`, `GraphLayout`, and six test files. **The suite went from 479 tests in 42 suites to 389 in 35** — 90 `@Test` cases, verified on iPhone 17 *and* on iPhone 16 / iOS 18.5.

Also gone: the `map` tab, `Glyphs.tabMap` (recycled as `Glyphs.crossing`, same `[◇]`), the `web` / `openWeb` cross-tab route, `[◇] connections` in both places it was offered, and eight launch arguments.

**`GraphLayoutTests` is the loss worth naming**: nineteen tests over genuinely hard geometry, all correct, none with a consumer any more.

**What survives gets more load-bearing, not less.** `NoteEmbedding`, `AffinityEngine`, `LinkWriter`, `ConnectionIndex`, `NoteEdge`, `Eraser.suppress`, `AffinityDumpTests`, and the backlinks drawn under every note on stream, book detail and the review card. `NotePicker` and `→ link` stay.

### Unverified, and honestly so

- **The accessibility-size pass has not been done.** Both appearances are checked and read correctly — head `n.08 · n.40 · [◇] crossing`, two notes with a hairline between them, foot `29 days apart · [x] not related`. **Two full notes on one screen is the first card in this app designed to hold two**, and AX5 is where it will break if it breaks.
- **Nothing was tapped, again.** `[x] not related` has never been pressed and the `erased` haptic has still never been felt.
- **Whether any crossing is *true* is unchanged and unknown.** It rides on the same scores everything else does, and `docs/issues.md` §14 means every one anybody has read came out of the fallback embedder. That is still 12b, and it is now an ordinary quality question rather than the fate of a tab.
- **`ThemeIsolationTests` was deleted by mistake and restored the same day.** Four files begin with `Theme`; three tested `ThemeEngine` and one tests `Theme`, the color enum, which is still here — the guard on the app's worst crash class (`docs/issues.md` §1). Nothing went red when it went, which is the part worth remembering. Back on the branch before it merged.

---

## What phase 12d built — deleted the next day

Kept as a record, because `docs/decisions.md` §21 supersedes §20 one day after it was written and the reasoning only makes sense with both halves visible.

12d replaced the canvas with a summary — themes ranked and named, `crossings`, `loose` — on the diagnosis that **every node is an opaque handle**: `n.07` says nothing, so a screen of forty-six of them is a picture nobody can read. That diagnosis was right about the drawing and produced a better screen. `ThemeEngine` grouped by mutual top-6 and unweighted greedy modularity with **no threshold anywhere**, which was the genuinely good idea in it: an absolute similarity cut is a number tuned to a model the app is designed to abandon. `ThemeName` extracted names from the notes' own words and **never from a tag**, which cost real name quality and was accepted anyway, because the screen must not read as though tagging were the mechanism.

**None of it was wrong and all of it is gone.** Legibility was never what kept anyone out of the tab; there was no moment in a day that wanted it. §21.

---

## What phase 12a built

**A reader looked at the map and asked whether it only joined books to their notes** — they had thought the point was connecting ideas *across* books. The premise was wrong and the complaint was right, which is the interesting combination.

- **The cross-book graph was already the larger half of what was on screen: 46 note-to-note connections against 40 book attachments.** `MapGraph` has emitted both since phase 7 and `AffinityEngine` has deliberately never boosted same-book. Nothing about the linking was broken.
- **What was broken was the drawing.** Every edge was stroked identically at `Theme.hairline` with no reference to `isAttachment`, and force-directed layout pulls each note toward its hub — so forty structural lines and forty-six meaning lines resolved into one impression: a star per book.
- **The map now offers `all lines` / `connections only`** in a chip row under the header. With the attachments subtracted the hubs stand bare and the idea web is the only thing left. **It is a filter, not a second line style** — no dash, no second weight, no tint — so `docs/decisions.md` §15's one-line-weight rule survives untouched. §19 records why dashing was rejected.
- **It filters at the stroke and not in `web`**, which is the part worth remembering. `GraphLayout` goes on being told about every edge, so **not one node moves when the filter changes** — verified by comparing the dark-pixel distribution of both states across 1300 rows of canvas, where zero rows differ. Filtering in `web` would have re-keyed `.task(id: plan)` and reshuffled the screen on a tap — the loop phase 11 removed — and would also have stopped the hubs gathering their clusters, since the attachment is the force that gathers them.
- **The foot gains a third line, and only while filtered.** `hint`'s doc comment said "two sentences and no more" for two good reasons, so the third describes a state the reader chose rather than teaching a gesture. The comment was amended rather than silently contradicted — §18 and §1 of `docs/issues.md` are both entries about docs asserting things about code they hadn't opened.
- **The hub view has no attachments to subtract**, so there the chips go to `.opacity(0)` and keep their height, per the rule about siblings of a scroll view.

### Unverified, and honestly so

- **Nothing here was tapped.** The chip row was reached by `-mapLines connections`, like everything else on this screen.
- **This makes the idea graph legible, not good.** The connections are still the fallback embedder's and about half remain indefensible. Seeing the shape clearly is what makes the *next* judgement possible; it is not that judgement. That is 12b.

---

## What phase 11 built

- **Two crashes, and neither was where anybody had been looking.** `docs/issues.md` §22 and §23 have the full anatomy. The record button had four independent ways to die, two of them Objective-C exceptions a Swift `do/catch` cannot see; the review set had an `ImageRenderer` drawing a multi-megabyte bitmap *inside `body`*, once per visible card, on every redraw. Both files had shipped for phases with tests passing over them.
- **The audit this project had already written down had been done half way.** `docs/issues.md` §1's closing note said the `SpeechTranscription` closure audit was complete and named the audio tap. `requestAuthorization` was three lines further down the same file, unannotated, handed to a framework whose own header says it may call back on any thread. That is the second entry in `issues.md` to assert something about code it had never opened — §18 was the first. The lesson is not about Speech.
- **The map stopped reshuffling itself.** Selecting a node used to make the preview panel appear, which shrank the canvas, which changed the aspect ratio `GraphLayout` is told, which re-ran the whole force-directed layout — so a tap moved every node on screen, and two notes with different-length previews moved them *differently*. The foot is a constant height now and the graph is identical before and after a tap, node for node. What movement remains is animated.
- **And it says what it does.** With nothing selected the foot carries `tap a note to preview it, again to open it` over `hold a line to disconnect two notes`. The most gestural screen in the app had never had an affordance on it; the reader who found the hub-expand gesture found it by accident, and said so.
- **The tab bar comes off the screen while the capture field has focus.** It was riding up with the keyboard to sit between the capture bar and the keys, with its home-indicator clearance stranded above them. Ignoring the keyboard safe area would have fixed the tab bar by breaking the capture bar, so the signpost goes rather than the tool — and the root now respects the *bottom* safe area properly, which retires the hardcoded 26pt the tab bar had been carrying since phase 1.
- **The Inbox stopped being one-way.** The spec has described a quick capture as landing there "to be filed later" since phase 3, and there was no later: nothing in the app could change a note's book after it was written. `NoteWriter.refile` is the one path it takes now, reached from `move to book…` on a row's long press — and from a `book · Inbox ▼` line that appears in the capture bar only while it has focus. Unfocused, the bar is byte-for-byte what it was: the fast path is not allowed to get slower.
- **Reading progress came out.** `Book.currentPage` moved exactly once in the app's life, through four taps of the edit form, so the bar was always stale. `docs/decisions.md` §17 weighs the three options and says why deriving it from a note's page — the tempting one — would have been the app's first inference about the reader, in a design whose one firm rule about pages is that they are typed and never inferred. `pageCount` stays, as `499pp` in the byline, because how long a book is happens to be a fact.
- **Three more things stopped growing at `xLarge`**, all three found in one AX5 screenshot: the map's nodes (illegible — the layout is told label widths in *characters*), the map's foot (three quarters of the screen, leaving the graph a strip), and the capture bar's `[+]` and `[●]`, which rendered as `…` and as a burst bracket. **A marker truncated to an ellipsis has stopped being a marker.** That is the sixth time on this project that an image has said something a code review didn't.

### Unverified, and honestly so

- **Which crash it actually was is still unknown.** §22 is fixed on four independent arguments and §23 on three; a crash log off the device would name the one that fired. The fixes stand either way and none of them can be exercised here.
- **Nothing in this phase was tapped either.** Every screen was reached by launch argument, as ever — including the new `-moveNote`. The fixes for the two crashes are, by their nature, the least verifiable things in the app.
- **The map's tap targets still overlap above ~100 nodes** (`docs/issues.md` §24 — closed by deletion in phase 12, which removed the canvas rather than the overlap), and the obvious fix — raising the spacing floor to 44pt — is not physically available: a hundred and twenty nodes at 44pt each need essentially the whole canvas. It wants a nearest-node hit test on the canvas, which is a change to the gesture layer of the least-verified screen in the app, on a pass that was already changing that screen.

---

## What phase 9 built

- **`ScannedPassage` — pure, and the half of the scanner with no camera in it.** Tapped lines become prose: whitespace collapses, a line break inside one recognized item closes up, and **a word broken at the margin is put back together** — `appear-` / `ance` is `appearance`. That last rule is wrong for a line whose last word genuinely ends in a hyphen, and there's no way to tell the two apart without a dictionary; it's the rarer case and the passage is editable either way. A hyphen with a space in front of it was typed rather than printed, and an en dash never breaks a word, so neither closes up.
- **`TextScanner` — `DataScannerViewController` in `.text()`, tap-to-select.** Everything in frame highlights and only what the reader touches is kept, so a facing page or a running head never arrives uninvited. The same line tapped twice is dropped, on `RecognizedItem.id`. It's the same controller `BarcodeScanner` points at a back cover, and the delegate is the only difference that matters.
- **The page number is still typed.** `ScannedPassage` deliberately does not hunt for a folio, which is the obvious place that rule would have quietly broken. A page number wrong one time in five is worse than a field somebody fills in.
- **`TextScannerScreen`** — the viewfinder under the app's own chrome, with the passage building at the foot in the quote rule it will wear as a note. The preview box is a **fixed** 150 and scrolls rather than grows: this is the one screen in the app operated while the other hand holds a book open, and buttons that move as lines are tapped would be the worst possible place for it.
- **Two rows of two.** `SegmentedRow` grew a `perRow`, and the capture type is the only caller that passes one — `docs/design-system.md` has said since phase 3 that a fourth segment clips its own label rather than the row shrinking its type. The book form's status and settings' appearance are untouched.
- **A scan is drawn as a passage and marked as a scan.** `NoteKind.isPassage` is what the quote rule keys on now, true for `.quote` and `.scan`; the marker still reads `[s] scan`. Same rule an edited transcript follows — how a note was captured is a fact about the note.
- **The scan panel mirrors the voice panel**, in the same 150pt box, which is now a shared `CaptureBox` rather than two copies of one. `scan more` appends rather than replaces, because a passage that runs over a page turn is two scans.
- **Two launch arguments**, `-scanner 1` and `-scanned "<text>"`, since the simulator can be neither tapped nor pointed at anything.

### Unverified, and honestly so

- **The camera has never run.** `DataScannerViewController.isSupported` is false on every simulator, so recognition, the tap that selects a line, the camera permission prompt, and the accuracy of any of it are all unobserved. This is the same position the barcode scanner has been in since phase 4, and phase 9 is the strongest argument yet for the device evening — `docs/issues.md` §6.
- **What was seen is the fallback**, in both appearances: the sheet on the scan segment, the scanner's no-camera state, the passage preview, and the field after a scan. The tap-to-select flow between them is proven by `ScannedPassageTests` and by nothing else.
- **De-hyphenation is a judgement, not a measurement.** No real OCR output has passed through it. On a device it wants a page of actual printed text read into it before anybody trusts the rule.

### The thing that couldn't be checked, and why

**The reminder still hasn't been received**, and the reason is worth writing down: it can't be, from a command line. `simctl privacy` has **no notifications service** — the list is TCC only — so authorization can't be granted, and `xcrun simctl push` reports `Notification sent` and then delivers nothing to an unauthorized app. Both were tried here. The toggle in settings is the one thing that calls `authorize()`, and it needs a finger. `docs/issues.md` §19 — the cost is unchanged at ten minutes, but they have to be somebody's.

## What phase 8 built

- **Search — `SearchQuery` and `SearchIndex`, both pure.** What was typed comes apart into words and `#tags`; a note matches when **every** word appears somewhere about it and **every** tag is on it, so a second word narrows rather than widens. What's searched is everything that is *about* a note: its text, the thread under it, its tags, and its book's title and author — being told nothing was found while four notes from *Thinking, Fast and Slow* sit in the library would read as a broken field. Results are note rows grouped by book, **the book with the most to say first**, and the rows drop the book from their source line because the header above already says it.
- **Search and settings hang off the stream's header**, which is now the only header in the app carrying actions. There is no tab spare for them and there isn't going to be another one; the stream is home, so its header carries the two screens that don't have a tab. Both keep the tab bar and both carry `← stream` — a screen, not a question.
- **`MarkdownExport` — pure, one section per book.** Notes oldest first, because a feed reads backwards and a document reads forwards. `[[n.05]]` wiki-links so an Obsidian vault understands them. Dates as `2026-08-14` rather than `aug 14`: an export is something else's software reading it. A quote is a blockquote and a thread is **nested one level under whatever it answers**, so a thread under a quote sits inside the quote it grew out of. Delivered as a real `.md` file through `ShareLink`, because a note that arrives as a file can be filed and one that arrives as text can only be pasted.
- **Settings, with no iOS controls on it.** A `Toggle` is a green pill and a `DatePicker` is a wheel; either would be the only thing in the app that looked like iOS. So a setting is on when its box is filled — `[*] one note a day` — and the time opens inline as a list of half-hours, the same field the capture sheet's book picker already is. Appearance is a three-segment row and it reaches the whole app through one `@AppStorage` read on the root view.
- **`NotificationPlan` is pure and `NotificationScheduler` is not**, the same split `AffinityEngine` and `LinkWriter` have. The plan asks `ReviewSetBuilder` what each of the next seven days looks like and takes **the first card of that day's set** — the whole set, not a set of one, because the "at least one book you're reading" rule can pick a different note when there's only one slot, and a reminder that named a note the screen doesn't open on would be its own small lie. Seven separate requests rather than one repeating trigger, because the note changes every day. Rewritten on every launch by `.reminders()`, which is the same shape as `.linking()` and for the same reason.
- **Manual linking, at last.** `LinkWriter.pin` is the only writer of `isPinned`, reached from `→ link` on a review card, which opens a picker over the library — the search sheet the spec asked for, built on the search machinery that had just been written. Pinning a pair the app already found adopts that edge and keeps its score; pinning a pair the reader once **disconnected** un-suppresses it, because both flags record a deliberate act and this is the newer one.
- **The recompute, measured.** `docs/issues.md` §15 asked for a number instead of a paragraph and now has a table. **0.71 µs a pair at `-O`** — 356 ms at a thousand notes, ~9 seconds at five thousand, off the main actor throughout. The incremental path the spec described is **not needed**, and that's now a measurement rather than an opinion.
- **And half that cost was work in the wrong place.** `AffinityEngine` was normalizing tags and re-deriving vector magnitudes inside the pair loop — O(N) jobs done O(N²) times. Hoisting them per subject took it from 1.50 µs a pair to 0.71, with the graph **unchanged edge for edge at every size measured**, which is the check that made it an optimization rather than a change.
- **The two routes.** A source line's book title opens the book, through a `marginalia://book/…` link resolved by the same route `→ n.11` already took — **a book is addressed by one of its notes**, because books have no id of their own and inventing one to shorten a URL would be a schema change in the service of a link. And `[◇] connections` opens a note's local map, from a stream row's long-press menu and from a third row on the review card.

### The bug the screenshot caught

**The scheduler was asking for permission at launch.** `.reminders()` called `authorize()` — which can put a system alert on screen — on every launch where the reminder was on, breaking the app's own rule that permission is requested at first use and never at launch. It's invisible in code and it is the first thing in the screenshot. The fix is the split that should have been there: `isAuthorized()` never prompts and is what the scheduler uses; `authorize()` prompts and is reached only by the toggle in settings. That's the fourth time on this project that an image has said something a code review didn't.

The same screenshot cost half an hour, because **a stuck permission alert survives an uninstall** and sits over every screenshot taken afterwards. `simctl shutdown all && simctl boot` clears it. `docs/issues.md` §19.

### Unverified, and honestly so

- **The reminder has never been received.** Scheduling, the alert's wording on a lock screen, and the tap that should land on the right review card are all written and none has run. Local notifications *do* work in the simulator, so this is ten minutes of somebody's hands — `docs/issues.md` §19.
- **Nothing was tapped**, as ever. `search`, `settings`, a result row, a book title in a source line, `[◇] connections` in a long-press menu, `→ link` picking a note: every one reached by launch argument. The two worth doubting are the ones with no visible affordance — the title, which the design system says not to underline, and `connections`, which is inside a menu.
- **The share sheet still hasn't been opened.** `ShareLink` now has a `.md` file to hand over as well as an image, and what iOS actually does with either is unseen.
- **The export was read, though.** The document phase 8 writes from the seed library is in the simulator's container and it is correct: five sections, the empty book skipped, threads nested, `[[n.18]]` links where the edges are.

### Standing until later

- **Nothing links from the composer.** The spec puts `→ link` on the keyboard accessory bar *while composing* as well as on the review card. The card half is built; the composer half isn't, because a note being written doesn't exist yet and the edge would have to be held and written after the save. Worth doing when editing a note arrives, which wants the same machinery.
- **`surfaceCount` still has no way back** (§10), and the day's set still doesn't notice midnight (§11). Neither changed.

---

## What phase 7 built

- **`GraphLayout`** — spring-electrical, pure, off the main actor, exactly as the spec asks. Every pair pushes apart, every edge pulls together, a per-axis gravity keeps the eight notes nothing connected to from being shoved off the page, and a falling temperature makes it settle rather than oscillate. **Nothing in it is random**: nodes start on a phyllotaxis spiral, which is evenly spread and already asymmetric, so the same graph lays out the same way every launch. That's the same rule `AffinityEngine` breaks its ties by, and for the same reason.
- **It's told the shape of the box and the size of every label**, and both were learned from a screenshot rather than reasoned out in advance. A graph laid out square and drawn into a box twice as tall has every horizontal gap squeezed by half — that put `[Design]` through `n.05`. Spacing a hub as if it were a point put `[Meditations]` through `n.10`. Neither is visible in code and both are obvious in an image, which is the third time this project has learned that.
- **The convergence number is the force, not the step.** How far a node last *moved* is capped by the cooling schedule and shrinks toward zero whether or not the graph settled — a number that cannot report a failure. What's still pushing on a node can. Switching to it immediately found that gravity was too weak and the outermost nodes were pinned against the box, permanently mid-shove: it looked settled and wasn't, and the residual was seven times what it should have been. Gravity is now derived rather than tuned — the value that balances the library's outward push at exactly half the box.
- **The budget grows with the library.** Three hundred passes settle forty-six nodes and do not settle a hundred and twenty, and a graph still moving when the budget ran out is laid out *badly*, not slowly. It's O(passes · N²) with a tiny constant — forty-six nodes is three milliseconds — so the budget is `6 × count` and stays free.
- **`MapGraph`** — pure, and the other half of the same split `AffinityEngine` and `LinkWriter` have: this decides which nodes belong in a view and which lines join them, and `MapView` does all the fetching. Three views over one builder — the library, two hops from a note, one book — because the local view is simply the library builder over a smaller set of notes, and so is an expanded book.
- **A local view doesn't hop through a book.** One hop through a hub is every note in it and the view stops being local; hubs come back at the end, attached to whatever was actually reached. Two hops, twenty-five nodes, strongest connections first.
- **The collapse is built, not deferred.** Above 150 nodes the library view becomes book hubs alone, joined where a connection crosses between two books — once, however many cross — and a hub expands to its own book on a second tap. `docs/decisions.md` §11 said it had to exist before the map shipped rather than after.
- **A hub is the book's first word.** `[Meditations]` is a whole title; `Zen and the Art of Motorcycle Maintenance` is forty characters of bold mono lying across the graph it's meant to be organizing. A leading article is dropped because `[The]` names nothing. The panel at the foot carries the whole title.
- **Holding a line disconnects it — and the edge is kept.** `Eraser.suppress` sets `isSuppressed` rather than removing the row, because every recompute is a full one: delete the edge and the next pass scores the same pair, finds it just as strong, and draws the line straight back. Suppression *is* the memory of the deletion. It goes through the app's own confirmation like every other delete, and a relink follows so the degree budget the reader just freed goes to somebody else.
- **Attachments aren't connections.** A note's line to its own book is drawn like any other line — there's one line weight in this system — but it can't be held down on, and it doesn't count toward either end's weight. Otherwise every note in a well-stocked book would read as better connected than it is.
- **Four launch arguments and a fifth `-confirmDelete`**, because the simulator can't be tapped or held. `-mapSelect`, `-mapNote`, `-mapBook`, `-mapCollapse`, `-confirmDelete connection`.

### The bug worth remembering

A cancelled `.task(id:)` **still finishes what it was awaiting**. `Task.detached` isn't cancelled along with its awaiter, so when the graph changed, the superseded pass resumed after its detached work completed and wrote its result on top of the new one. It showed as one book's nine notes drawn at the coordinates they'd held in the whole-library graph — a clump in the corner of an empty screen, under a perfectly correct header. The fix is one line (`guard !Task.isCancelled`), and the lesson generalizes to any `.task(id:)` handing work to a detached task. It's in `CLAUDE.md` now.

### Unverified, and honestly so

- **Not one of the map's gestures has been made.** Selecting a node, expanding a hub, holding a line, tapping empty space to deselect — all four were reached by launch argument, which proves the state renders and proves nothing about getting there. The hold is the one to worry about: it's a `LongPressGesture` for the timing and a zero-distance `DragGesture` for the location, sitting under forty tappable node views, deciding which of seventy hairlines a thumb meant. `docs/issues.md` §17.
- **The graph is still the fallback embedder's graph.** Everything phase 6 said applies unchanged — what the map draws on this machine came out of `NLEmbedding.sentenceEmbedding`, and a device run changes the picture. The layout is geometry and doesn't care; whether the *shape* means anything still waits on `docs/issues.md` §6.
- **A book with three hundred notes never quite settles.** One hub, hundreds of leaves, nothing else: the residual stays high at any budget. It draws as a hub in a halo, which is what it is, and nothing overlaps or runs off the screen — but the halo would be arranged differently on two launches a week apart. `docs/issues.md` §16.
- **Only one screen size.** Everything here was seen on an iPhone 17 in portrait. The layout takes the aspect ratio it's given, so a rotation or an iPad should work; neither has been looked at.

### Standing until later

- ~~**A local map is reachable from the map and nowhere else.**~~ Phase 8: `[◇] connections` in a stream row's long-press menu and on the review card.
- ~~**Nothing creates a link by hand.**~~ Phase 8: `→ link` on the review card, through `LinkWriter.pin`.

---

## What phase 6 built

- **`NoteEmbedding`** — `NLContextualEmbedding` mean-pooled over its token vectors, falling back to `NLEmbedding.sentenceEmbedding` when the contextual assets won't load, and asking for those assets once in the background so a later launch can upgrade. Vectors come out unit length, which turns every cosine in the engine into a dot product. Packed little-endian `Float32` into `Note.embedding`.
- **A vector carries which model made it.** New `Note.embeddingSourceRaw`. Two models produce two spaces and a cosine between them is a number with no meaning, so a note whose stored source isn't the one loaded today is stale and gets embedded again — the second way into the queue after `embeddedAt == nil`, and the one that re-embeds an entire library the day Apple's assets finish downloading. Without it the fallback would quietly poison every score the moment the better model arrived.
- **`AffinityEngine`** — pure, exactly as specified: `0.8 · cosine + 0.2 · tagOverlap`, floor `0.55`, mutual k-NN at 8, degree cap 6, same-book not boosted. Tag overlap is **Jaccard**; intersection alone would let a note tagged with everything score against everything, which is the failure mutual k-NN already exists to prevent. Ties break on note id so a recompute over unchanged notes returns the same graph — a map that reshuffled on every launch would read as the app changing its mind.
- **Pinned edges spend degree budget.** They're never pruned and never re-suggested, but the cap is about how many lines meet at a node, and a hand-made line is still a line. Suppression beats pinning where a pair is somehow both.
- **`LinkWriter`** — the one path an edge takes to exist, and the mirror of `NoteWriter`. It embeds what needs it, rescores the library, and diffs: an edge that still holds keeps its identity and takes a new score, one that no longer holds is deleted, dangling and self-joined and duplicated edges are swept. Both expensive halves run off the main actor and only plain values cross.
- **It's a full recompute, not the spec's delta.** Embedding one new note and comparing it against every stored vector gets *that* note's edges right, but can't notice that it displaced somebody else's eighth-best neighbour or filled their sixth slot. At the sizes this app holds, being right is free. Above a few thousand notes it wants the incremental path and a background `ModelActor` — a phase 8 job, written down rather than pretended away.
- **One trigger, in one place.** `.linking()` on the root view watches the note count and the unembedded count. That single rule covers the first-launch backfill and every capture after it, and a delete frees degree budget that the next pass hands to somebody else. Overlapping passes queue rather than drop — a dropped pass would leave the note that caused it unembedded until something else changed.
- **Backlinks needed no work.** `ConnectionIndex` already read edges both ways and all three surfaces already drew them; they were drawing an empty index. Seen in the app: `n.40 → n.08 · n.27` on the stream, `→ n.03 · n.05` on a review card, in both appearances.
- **`AffinityDumpTests`** — the phase's actual deliverable. Prints every seed note's five best candidates, the score, and whether the constraints let it through, plus degree and score distributions. Off unless `MARGINALIA_DUMP` is set; every line starts with `|` so it survives an `xcodebuild` log.

### What reading the output actually said

**The gate did not pass cleanly, and the reason is not the code.** `NLContextualEmbedding` — the model the whole design is built on — **cannot run in this simulator.** Its assets are downloaded and present, but compiling them writes to `/var/db/com.apple.naturallanguaged`, which an app sandbox can't create there. The app tries it, gets `Permission denied`, falls back, and keeps working, which is exactly what it was built to do. So everything below is the **fallback's** output, and none of it is evidence about the model that ships.

On `NLEmbedding.sentenceEmbedding`, over the forty seed notes: 30 connections found on top of the 16 seeded, mean degree 2.3, 8 notes isolated, 36 of 780 pairs over the floor. Reading them:

- **Defensible:** `n.05` slips/mistakes ↔ `n.19` stuckness-as-debugging (0.617). `n.28` hindsight ↔ `n.26` availability (0.631). `n.37` romantic vs classical ↔ `n.01` good design is invisible (0.600). `n.30` quality ↔ `n.23` the motorcycle is a system you're part of (0.584). Those are the connections the seed content was written to produce, and they're there.
- **Not:** `n.02` affordances ↔ `n.18` System 1 and System 2 is the **strongest** edge on the note (0.646), and it isn't a connection anyone would defend. `n.13` Marcus's repetition turns up in half the shortlists. Both are hub behaviour, which mutual k-NN is supposed to stop — and at 40 notes with `k = 8` a hub is comfortably inside everyone's top eight, so it doesn't.
- **Missed, and this is the worse half:** `n.03` "good error messages assume the system is at fault" ↔ `n.04` "human error is system error" scores **0.448** and would not have connected if it weren't seeded. A near-restatement of the same idea, below the floor, while affordances-and-System-1 sails over it.
- Measured directly in `NoteEmbeddingTests`: two paraphrases about attention score **0.267** against each other and **0.274** against an unrelated note about a kitchen tap. The fallback is not measuring meaning at note length. That test records the failure as a known issue rather than hiding it.

**Nothing was tuned.** The floor, the weights and `k` are at the spec's values on purpose: tuning them against a model the app abandons the moment the assets compile would be fitting to the wrong thing twice. The judgement the phase asks for needs one run on a device — which is `docs/issues.md` §6, already the second most valuable open item — and then the same dump read again.

### Standing until later

- ~~**Nothing creates a link by hand.**~~ Phase 8: `LinkWriter.pin`, reached from `→ link` on a review card. The composer half of the spec's answer — the keyboard accessory bar — is still unbuilt and now the only part outstanding.
- **A note can't be edited, so a note's vector can't go stale by editing.** When editing arrives, whatever writes the new text has to clear `embeddedAt` — the queue is the only thing that would notice.

### Unverified, and honestly so

- **The contextual path has never executed.** Asset request, load, `enumerateTokenVectors`, mean pooling, and the re-embed-on-source-change path are all written and all unexercised. The fallback path is what every test and every screenshot in this phase went through.
- **Nothing was tapped**, as ever. A capture that triggers a relink was proven by `LinkWriterTests` against a real store, not by typing into the bar.
- ~~**Timing is unmeasured.**~~ Phase 8 measured the scoring pass: 0.71 µs a pair at `-O`, and 2× faster than it was. **The embedding half is still unmeasured**, and can't honestly be measured here — the only model this machine will run is the fallback.

---

## What the issues pass did

Between phase 5 and phase 6, six of the thirteen entries in `docs/issues.md` were closed. Full detail is there, in §0; the short version:

- **`Eraser`** — the one path anything takes to stop existing, and the mirror of `NoteWriter` / `BookWriter`. It exists because `context.delete(note)` isn't enough: `NoteEdge` has no inverse relationship, so SwiftData nils one end instead of removing the edge. **The Inbox is refused**, like it refuses a status change.
- **`ConfirmSheet`** — the app's own half-height confirmation rather than `confirmationDialog`, whose pill buttons and 26pt radius would be the only iOS-looking thing in the app. `MarkerButton` grew a `danger` kind for its one filled button; `danger` still belongs to the confirmation and never to the link that opens one.
- **Long press deletes a row** where it's *listed* — stream and book detail — and not where it's being *read*. Book detail carries `delete` next to `edit`.
- **`StoreFailureView`** replaces the `fatalError`. A screen with the store's own error on it, not a crash log.
- **A duplicate book is named once and then allowed.** Refusing outright would overrule a reader with a legitimate second copy.
- **`-tinyLibrary <n>`** makes review's empty state and an exhausted `[↻] keep going` reachable. Both have now been drawn for the first time. It spreads across books rather than taking a prefix — a prefix is all one book, and the two-per-book cap meant every `n` produced the empty state.
- **Release runs** on the simulator, all four tabs, no new crash report. **`-derivedDataPath .build`** is now the build command.

**What that leaves at the top of the list:** an iOS 18 runtime (§4), a device run (§6), and a UI test target (§12, which needs the Xcode GUI to add a target).

## What phase 5 built

- **`ReviewSetBuilder`** — pure, `[Note]` + `Date` → the day's set. `daysUnseen + starBonus + jitter`, then the three caps: 8 total, 2 per book, and one card spent on a book currently being read even when nothing from it scored. A note never surfaced counts as a year unseen; a star is worth a week, which wins between two notes with the same history and loses to a month of neglect. The jitter is a hash of the day and the note id — `Double.random` would reshuffle on every redraw.
- **The set is built once, on arrival, and held in `@State`.** This is not incidental: the set is scored partly on `isStarred`, so a set rebuilt every redraw would reshuffle under the thumb the moment the reader starred a card.
- **`ReviewWriter`** — the one path a follow-up, a star, and a surfacing take. **Surfacing counts once per calendar day per note**, which the spec didn't say and which matters: swiping back and forth through the day's set is one reading of each card, not six, and an inflated `surfaceCount` would quietly bury a note for months.
- **Paging is vertical**, which is what the hint has always asked for. `ScrollView` + `scrollTargetBehavior(.paging)` + `scrollPosition`, not a rotated `TabView`. A card is surfaced when the position moves off it — paged past, exactly as specified, never at build time.
- **The card** — centered and open, no margin. Metadata, the note at 18/1.7, source, connections, thread, then the actions. Centering inside a scroll view is a `minHeight` frame against a `GeometryReader`; `Spacer` collapses there.
- **The action row is two rows of two.** `[+] add a thought` · `[ ] star` over `→ open book` · `share`. Four link buttons at 13pt mono are ~320pt of text before gaps and overflow a phone at the default text size — the same arithmetic that gave the capture sheet three segments instead of four.
- **The closing card** — `that's the set`, and `[↻] keep going`, which extends past the day's eight rather than restarting it. When nothing is left it says so and drops the button.
- **Follow-ups render everywhere the note does** — stream, book detail, and the card — behind a new `ThreadRule`: the quote rule's quieter half, a 1px hairline where a quote gets 2pt of ink. Oldest first, because a thread reads forward.
- **The share card** — `ImageRenderer` at 3× over a fixed 420pt width, delivered by `ShareLink`, rendered **in the appearance the reader is looking at** so a dark-mode user doesn't share a white card.
- **The first cross-tab route.** `→ open book` hands the book up to `RootView`, which switches tabs; `BooksView` pushes it on appear. Phase 4 deferred this to phase 7 — it turned out to be about fifteen lines, and phase 7's map and a tappable source-line title both want the same route.
- **Three seeded follow-ups**, out of forty notes. A fresh install has to *show* what `[+] add a thought` produces rather than only offering it, and a library where every note had a thread would misread as the normal state.
- **`BodyField` moved into `Design/Components/Controls.swift`**, shared by the capture sheet and the follow-up composer rather than copied into both.

### Unverified, and honestly so

- **Nothing was tapped.** `simctl` can't tap or swipe, so every screen was reached by launch argument. Starring, saving a follow-up, `→ open book`, `[↻] keep going`, and the share sheet are proven by `ReviewWriterTests` and `ReviewSetBuilderTests` against a real in-memory store and by the screens rendering — not by a finger.
- **Paging itself was never swiped.** `-reviewCard 3` sets the scroll position rather than dragging to it, so the paging *feel*, and the surfacing that fires on a real page-past, need a device or a tap.
- **The share sheet was never opened.** `ShareCard.rendered` returning an image is what gates the link appearing, and it appears — but what iOS actually puts on the share sheet is unseen.

### Standing until later

- ~~**The empty state was not seen.**~~ `-tinyLibrary 2` — seen, both appearances.
- ~~**`keep going` on an exhausted library was not seen.**~~ `-tinyLibrary 4` — seen.
- ~~**Nothing deletes a follow-up.**~~ Long press one in the stream or on book detail.

---

## What phase 4 built

- **Book detail** — the header carries `← books`, the title, the note count, `author · status`, and the progress bar `[████░░░░░░] p.214 / 499`. Under it, that book's notes in the same margin the stream uses, **minus the book title on every source line** — it's already at the top of the screen.
- **`[+] add book` and `[+] add note` are pinned at the foot**, in the same place the stream's capture bar sits. Each tab's create action is at the bottom of the screen, one thumb away, and that parallel is deliberate.
- **The library filters** by reading / queued / finished, with the stream's chip row. Only statuses actually on the shelf become chips. **The Inbox is never a chip** — it's a drawer rather than a reading state, and it stays visible under `all`.
- **`BookFormSheet` — the form is the screen; search and the barcode are two ways to fill it.** That's what keeps manual entry always available rather than buried behind a failure. A result never saves straight through: it fills the fields, and the reader corrects them.
- **`BookLookup`** — Open Library `/search.json` and `/isbn/{isbn}.json`, no key, no account. Fetching and parsing are separate, so every response shape is tested against a captured fixture rather than the network. The isbn endpoint returns an *edition*, whose authors are key references, so the name costs a second request — one that's allowed to fail.
- **`ISBN`** — hyphens and spaces out, Bookland (`978`/`979`) enforced, so a cereal-box EAN says "that isn't an isbn" instead of failing a lookup for no visible reason.
- **`BarcodeScanner`** — VisionKit in `.ean13` mode, fires once per scan, with a written fallback where the camera isn't available.
- **`BookWriter`** — the one path a book takes to exist and the one path it changes by. **The Inbox keeps its status whatever the form says**, and book detail doesn't offer `edit` on it.
- **Editing a book was added** on top of the phase's brief, because without it `currentPage` and `status` were unreachable and the progress bar could never move. Same form, same writer.
- **Shared out of the capture sheet:** `SegmentedRow` and `InputField` now live in `Design/Components/Controls.swift`, and `ScreenHeader` grew a `←` back link and a detail slot. `MarkerButton`'s disabled state is drawn rather than declared — SwiftUI's `.disabled` fades the label, and a faded `onInk` on a `disabled` fill is exactly what the design system says not to do.

### Unverified, and honestly so

- **The barcode scanner was not exercised.** The simulator has no camera, so `DataScannerViewController.isSupported` is false there and only the written fallback was seen. Scanning, the camera permission prompt, and the isbn → edition round trip need a device.
- **Nothing was tapped.** `simctl` can't tap, so every screen was reached by launch argument. `←` back, the filter chips, choosing a search result, and `save` are proven by their unit tests and by the screens rendering, not by a finger.
- **Search was run against the live API** and its results are in the screenshots, so the parsing is real. The fixtures in `BookLookupTests` are what pin the shapes down.

### Standing until later

- **A source line's book title isn't tappable yet.** `docs/design-system.md` says it should open the book. Phase 5 built the cross-tab route it was waiting on — `RootView.open(_ book:)` — so this is now a small job rather than a missing capability.
- ~~**Nothing deletes a book or a note.**~~ `Eraser` and `ConfirmSheet`, in the issues pass above.
- ~~**Adding a book you already have makes a second one.**~~ `BookShelf.duplicate` names it once, then lets it through.

---

## What phase 3 built

- **`NoteWriter`** — the one path a note takes to exist. Allocates the id from `ShortIDCounter`, trims the body, files to the Inbox when no book was given, and **recreates the Inbox** rather than swallowing the note if the store has lost it. A refused save spends no id: a gap in the sequence reads as a deleted note.
- **`CaptureDraft`** — pure. What was typed (`"p.214"`, `"#Attention, memory"`) becomes what a `Note` stores (`214`, `["attention", "memory"]`). Every rule in it is tested without a container.
- **The capture bar**, moved out of `StreamView` into `Features/Capture/`. Three rows, one at a time: input, live waveform with the elapsed timer, and `[↻] transcribing…`.
- **`SpeechTranscription`** — `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`, an `AVAudioEngine` tap driving the waveform, permissions asked at first use. It waits up to six seconds for a final result and hands back the best partial rather than losing what it heard.
- **`AudioLevels`** — dBFS → `▁▂▃▄▅▆▇`, pure, so the waveform is judged by assertions rather than by eye.
- **`CaptureSheet`** — type selector, inline book picker, body, page, tags. Phase 4 opens it from book detail.
- **Four launch arguments** for states the simulator can't be tapped into — see the table in `CLAUDE.md`.

**A transcript is never saved unseen.** It lands in an editable field in both places, and editing it leaves the note `[v] voice` — how it was captured is a fact about the note, not about the keystrokes.

### Unverified, and honestly so

- **Voice was not exercised.** The simulator has no microphone and cannot run on-device recognition. Every recording state was screenshot from `VoiceCapture.demo`, which is fixed values, not audio. Recording, transcription, and both permission prompts need a device before anyone claims they work.
- **Nothing was tapped.** `simctl` can't tap, so the save path is proven by `NoteWriterTests` against a real in-memory store rather than by pressing `[+]`. The bar's behaviour with the software keyboard up is also unseen — the simulator had a hardware keyboard attached.

### Standing until later

- **Tapping a book opened the capture sheet against it.** That was phase 3's entry point to the full sheet; **phase 4 replaced it** with book detail, and `[+] add note` lives there now.
- ~~**The type selector offers three types, not four.**~~ Phase 9: `[s] scan` landed, and the row became two rows of two exactly as `docs/design-system.md` §Segmented control said it would.

---

## What phase 2 built

- **`Model/`** — `Book`, `Note`, `FollowUp`, `NoteEdge`, all CloudKit-shaped: every property defaulted, every relationship optional, no unique constraints. `statusRaw`/`kindRaw` are strings with typed accessors that fall back rather than crash.
- **`Library`** — schema, container, and a `prepare` that runs every launch: seeds an empty store, then raises the id counter past everything already in it.
- **`ShortIDCounter`** — monotonic, in `UserDefaults`. Deleting the newest note does not free its id.
- **`SeedLibrary`** — 40 notes across five books plus the Inbox, dated relative to first launch so the stream opens with all three date headers. **The cross-book tag overlap is deliberate**: `attention`, `error`, `quality`, `memory` and `systems` each run through three or four authors, and that's the signal phase 6 tunes against. 16 seeded edges are `isPinned`, so the first recompute won't prune them.
- **Stream** — real feed, date grouping, chips derived from the notes themselves, and `marginalia://note/…` handled so a connection scrolls to its note (clearing the tag filter first, or the link would land on an empty feed).
- **Books, review, map** — all reading from the store. Book detail landed in phase 4; the real review set and the real graph are phases 5 and 7.

### Scaffolding phase 2 removed

`Features/Stream/SampleData.swift` is gone. `NoteRowData`/`BookRowData` stayed and are now built in `Model/RowMapping.swift` — that's the one file aware of both the models and the design system, and it should stay the only one.

### Still standing, deliberately

- ~~**`MapView`'s hand-placed positions and lines**~~ — phase 7. `GraphLayout` and `MapGraph` replaced every one of them.
- ~~**`ReviewView` shows the newest eight**, not a day-stable set, and its actions do nothing~~ — phase 5.

---

## What phase 10 built

- **The app icon — `[m]`, and it is a script rather than an export.** `Tools/MakeAppIcon.swift` reads the same JetBrains Mono the app ships and the same two hexes `Theme` defines, and writes three 1024s plus the catalog's `Contents.json`. The icon is the one image in an app whose identity is the absence of images, so it had to be the *vocabulary* applied to itself: every affordance in this app is bracket-plus-character, and so is the icon. It cannot drift from the palette without the script drifting too.
- **The brackets are opened by 5.5% of the point size**, and that number was tuned on a screenshot of a home screen rather than reasoned about. JetBrains Mono sets `[m]` tight enough that at 40pt the two bracket stems and the `m`'s three stems read as one five-bar smear.
- **iOS 26 destroys a transparent tinted icon** — a white disc with the marker scattered across it, nothing like the source. Found on the home screen, isolated by shipping the three variants one at a time, fixed by making the tinted variant opaque. That is contrary to Apple's own guidance, which was written for the pre-26 compositor. `docs/issues.md` §20.
- **Chrome stops growing; content never does.** One modifier, `chromeTypeSize()`, capping the tab bar, every screen header and review's foot at `xLarge`. At `accessibility-extra-extra-extra-large` the four tab labels wrapped through each other with `map` sitting a line below its neighbours, `marginalia · stream · search · settings` came apart into eleven lines, and a ten-cell `[████░░░░░░]` progress bar wrapped — which is a bar that has stopped being a bar. The rule is about what text is *for*: a note is what the reader came to read and gets every point it asks for; a signpost that fills the room it points out of is worse at its job, not better.
- **The margin folds at the accessibility sizes.** It's a `@ScaledMetric` 48, so at AX5 it was 110pt of a 393pt screen and the note it annotates got about five characters a line. The margin is the app's identity at every size somebody reads at by choice; at the sizes somebody reads at by necessity it cost nearly half the width of the thing it exists to annotate. The id doesn't disappear, it moves — to exactly where the review card has always put it. This is the one place the design system's margin rule is conditional, and `docs/design-system.md` says so now.
- **A book row stacks its author and status** at those sizes rather than wrapping `Kahnem/an` through `readi/ng`.
- **Haptics — one vocabulary, five events.** `Design/Haptics.swift`, named for what happened rather than how it feels: `saved` `starred` `erased` `paged` `captured`. Six call sites, and `erased` is fired from `ConfirmSheet`'s own button, which is the single door every delete in the app goes through — the same one-path-in rule `Eraser` follows. Navigation is silent on purpose: a haptic marks something that happened to the *library*.
- **iOS 18.5, at last.** `docs/issues.md` §4 is closed. All 402 tests of the day passed on 18.5 and on 26.5, the app was installed and walked across all four tabs there, and the map drew **the same graph node for node and edge for edge** on both. (The count is 389 now and the map is gone; both runtimes are still checked on every phase.) Phase 5's paging scroll view — the specific reason anyone was worried — behaves identically.
- **The curly quotes that weren't supposed to exist did.** See below.

### The two things a screenshot said that the code review hadn't

**The app had been drawing curly quotes for ten phases.** `docs/issues.md` §18 said no surface wrapped a quote in `“ ”` and asked for a decision. Two surfaces did — `QuoteRule` and `ReviewCard`, since phase 1. The entry had been written from the design system and never checked against the code, and it survived three phases that way. It was caught in an AX5 screenshot taken to look at something else, where the quote mark sits at the head of the card. Decided in favour of the rule and the marks came out of both files: the printer's convention is a rule *or* quote marks, never both.

**The largest accessibility size had never been set**, and it broke every screen in the app at once. That is the fifth time on this project that an image has said something a code review didn't, and the first four are already written down.

### Unverified, and honestly so

- **No haptic has ever been felt.** The simulator has no Taptic Engine. Five events fire on paths that unit tests cover, and what any of them feels like under a thumb is unobserved — including whether `erased` at `.heavy` reads as irreversible or merely as loud.
- **The dark app icon has never been selected on screen.** It's correct in the catalog and it renders; this simulator's home screen is in Light icon appearance — every system icon draws as a light tile in dark mode there — so SpringBoard never asked for it. `docs/issues.md` §20.
- **AX5 was walked on one device in portrait**, like everything else here. The map at AX5 was not examined closely: it's a graph of laid-out labels rather than a stack of rows, and `GraphLayout` is told the size of every label, so it should absorb the change — should.
- **Nothing was tapped**, as ever.

## Still open after phase 10

- **One evening on a device**, and it is now the only item of its kind. Voice, transcription, camera OCR, the barcode, the share sheet, `NLContextualEmbedding`, the dark icon, and every haptic — eight things asserted and never observed, and they all clear at once. `docs/issues.md` §6.
- **The reminder, received** — `docs/issues.md` §19. Phase 9 established the shell can't get past the permission prompt: `simctl privacy` has no notifications service and `simctl push` reports success and delivers nothing. Ten minutes of somebody's hands.
- **A UI test target** — `docs/issues.md` §12. Still needs the Xcode GUI to add a target, which is why it isn't here.
- **The keyboard accessory bar's `→ link` while composing**, the one piece of the spec still unbuilt. It waits on editing a note, which wants the same machinery — see phase 8's *standing until later*.

Notifications turned out **not** to need the paid Apple Developer account — local notifications need no entitlement and no provisioning. Open question 4 still stands for CloudKit.

---

## Open questions for Nathaniel

Nothing here blocks phase 10 except the first one, which now blocks *seeing* three features rather than only judging one.

-2. **Can we get an hour on your iPhone?** It's now the only way to see the model the app is designed around. Voice, transcription, camera OCR, barcode and the share sheet are all waiting on the same evening — see `docs/issues.md` §6 — but linking has joined them and it's the one that changes a design decision rather than confirming a feature.

-1. **Is once-per-day the right surfacing rule?** Phase 5 decided a card seen twice in one sitting counts once, so swiping back and forth doesn't bury a note for months. The spec only said "when a card is actually paged past" — say so if you meant every pass.

0. **Is `▼` allowed?** The capture sheet's book picker uses it, and the prototype does too. It's terminal furniture by the same argument that permits `■` and `→`, but it's the closest thing to a dingbat in the app — say so now if it reads as one, while there's exactly one of them.

1. **Is the dark palette right?** The prototype only ever specified light; every dark value is derived.
2. **Is the body leading comfortable?** `Typography.bodyLeading` is 4pt on 15pt text (~1.6). Tightened once already from 5.
3. **Do the seed notes read as real notes?** They're the content phase 6 tunes the linking against, so if any of them feel like filler it's much cheaper to say so now.
4. **Is the Apple Developer account paid?** Needed before CloudKit sync. **Not** needed for the daily reminder after all — a local notification needs no entitlement, so phase 8 shipped it without touching this.
5. **Is "marginalia" available on the App Store?** Likely contested. Doesn't block anything — the bundle id can change — but worth knowing before phase 10.

---

## Things worth knowing before you touch the build

Learned the hard way in phases 1 and 2.

- **The project file needs no editing to add sources.** `PBXFileSystemSynchronizedRootGroup` means folders are referenced, not files. Drop a `.swift` file anywhere under `Marginalia/` or `MarginaliaTests/` and it compiles. If you find yourself editing `project.pbxproj`, stop.
- **Pure enums touched from a `@Model` need `nonisolated`.** The project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and SwiftData models aren't MainActor, so `Note.idLabel` calling `Glyphs.noteID` doesn't compile until `Glyphs` is marked. Same for `BookStatus` and `NoteKind`.
- **Launch arguments are how you screenshot anything but the top of the stream.** The simulator can't be tapped from the command line, so every screen reached by tapping has one. The full table is in `CLAUDE.md`; they compose.
  ```bash
  xcrun simctl launch booted com.marginalia.app -startTab review -reviewCrossing 1
  xcrun simctl launch booted com.marginalia.app -openNote 20
  xcrun simctl launch booted com.marginalia.app -startTab books -openBook "Meditations"
  xcrun simctl launch booted com.marginalia.app -startTab books -addBook 1 -bookSearch "meditations"
  xcrun simctl launch booted com.marginalia.app -startTab books -openBook "Med" -confirmDelete book
  xcrun simctl launch booted com.marginalia.app -tinyLibrary 2 -startTab review   # uninstall first
  xcrun simctl launch booted com.marginalia.app -search "error"
  xcrun simctl launch booted com.marginalia.app -startTab books -openBook "Med" -captureSheet scan -scanner 1
  xcrun simctl launch booted com.marginalia.app -settings 1
  xcrun simctl launch booted com.marginalia.app -startTab review -link 1
  ```
- **A permission prompt sticks to the simulator, and it survives an uninstall.** `-preference.notifications 1` raises the notification alert; nothing on the command line can answer it, so it sits on the SpringBoard over every screenshot taken afterwards — including after `simctl uninstall` and a reinstall. Reboot the simulator to clear it.
  ```bash
  xcrun simctl shutdown all && xcrun simctl boot "iPhone 17"
  ```
- **`simctl openurl` is not the in-app path.** Opening `marginalia://note/20` from outside raises the system's *Open in "marginalia"?* alert, which blocks the simulator until it's dismissed by hand. In-app taps are intercepted by `OpenURLAction` in `RootView` and never reach the system. Use `-openNote` to screenshot that path.
- **Reinstall before screenshotting a seed change.** The seed only runs against an empty store, so an existing install keeps the old notes.
  ```bash
  xcrun simctl uninstall booted com.marginalia.app
  ```
- **CoreData logs `Sandbox access to file-write-create denied` during `test`.** That's the app's `init` opening a store inside the test host; it falls back to in-memory and the tests are unaffected. The persistent store works in a normal run — check the file if you doubt it.
- **Run the tests, don't assume they pass.** `TEST_HOST` was malformed in phase 1 and the test bundle silently failed to link while `build` still reported success. `build test` is the command that tells the truth.
- **A `TEST FAILED` isn't always your code.** Repeated `simctl` launches leave the simulator wedged, and it surfaces as `Mach error -308 (ipc/mig) server died` / `Failed to install or launch the test runner`. If the error names the launcher rather than an assertion, reset and re-run.
  ```bash
  xcrun simctl shutdown all && xcrun simctl boot "iPhone 17"
  ```
- **Screenshot both appearances and actually look at them.** Three real layout bugs so far — the margin rule not meeting the row dividers, source lines wrapping away from their links, and a `→` separating from the id it points at — were invisible in code and obvious in an image.
- **Info.plist lives at `Support/Info.plist`**, outside the synchronized group, so it isn't copied in as a resource. It registers the `marginalia` URL scheme.
- **Fonts are committed** to `Marginalia/Resources/Fonts/` under the SIL OFL, registered via `UIAppFonts`.

---

## Map of the docs

| File | What it's for |
|---|---|
| `CLAUDE.md` | The rules. Design constraints, model constraints, commands, what not to do |
| `docs/planning.md` | This file — state and what's next |
| `docs/issues.md` | What's broken or fragile right now, and what to change. **Read it when a build hangs or the app crashes** |
| `docs/specs/2026-08-13-marginalia-design.md` | What the app does. Authority on behavior — the map sections in it are superseded by `docs/decisions.md` §21 |
| `docs/specs/2026-08-18-crossings-design.md` | Why the map came out and the crossing card went in |
| `docs/phase-11.md` · `docs/phase-12.md` | The two hands-on passes, in the order they happened |
| `docs/design-system.md` | Every token and component spec. Authority on visual values |
| `docs/decisions.md` | Why things were chosen. 21 entries. Settled — don't reopen without a changed premise |
| `docs/prototype/` | The original Claude Design prototype. Authority on look, overridden by the spec on behavior |
| `README.md` | Human-facing |
