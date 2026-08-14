# Planning

Where the project stands and what happens next. **Read this first in a new session**, then `CLAUDE.md` for the rules.

Last updated 2026-08-14, after phase 6.

---

## State

The app **builds clean, runs on the simulator in both appearances — Debug and Release — and passes 273 tests (one of them a recorded known issue — see phase 6 below).** Every screen reads from SwiftData, and the app writes notes, books *and* follow-ups: `[+]` in the stream bar files a thought into the Inbox with a fresh id, the full sheet files one against a book, books arrive by Open Library search or barcode or by hand, and review pages through a day-stable set of eight whose actions all do something.

**And now removes them.** Notes, books and follow-ups all delete, through `Eraser` and the app's own confirmation — see the issues pass below.

**And now connects them.** Phase 6 landed: every note is vectorized on save, `AffinityEngine` scores every pair, and the connections that survive its three constraints are written as edges and drawn on the stream, on book detail and on the review card. Nobody was asked to link anything.

**Still inert:** everything on the map except the preview panel.

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
| 7 | Map — `GraphLayout`, real graph | **next** |
| 8 | Search, export, settings, notifications | |
| 9 | Camera OCR capture | |
| 10 | Polish, app icon, device install | |

Full detail for every phase is in `docs/specs/2026-08-13-marginalia-design.md`. The reasoning behind the choices is in `docs/decisions.md` — **don't re-litigate those.**

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

- **Nothing creates a link by hand.** `isPinned` is written by the seed and by nothing else, and `isSuppressed` by nothing at all — the machinery honours both, and `LinkWriterTests` proves it, but the reader has no way to produce either. The spec puts manual creation on the composer's keyboard accessory bar (`→ link · # tag · p. page`) and on the review card, opening a search sheet over notes; **no phase owns it.** It should be scheduled — probably phase 8, next to *rebuild connections* — and until it is, "manual linking exists as override" is true of the model and not of the app.
- **A note can't be edited, so a note's vector can't go stale by editing.** When editing arrives, whatever writes the new text has to clear `embeddedAt` — the queue is the only thing that would notice.

### Unverified, and honestly so

- **The contextual path has never executed.** Asset request, load, `enumerateTokenVectors`, mean pooling, and the re-embed-on-source-change path are all written and all unexercised. The fallback path is what every test and every screenshot in this phase went through.
- **Nothing was tapped**, as ever. A capture that triggers a relink was proven by `LinkWriterTests` against a real store, not by typing into the bar.
- **Timing is unmeasured.** Forty notes embed fast enough that nothing was ever seen to hang, but no one has run this at a thousand notes, and the O(N²) pass has no measurement behind the claim that it's fine.

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
- **The type selector offers three types, not four.** `[s] scan` opens the camera; it arrives with the scanner in phase 9 rather than as a segment that does nothing. See `docs/design-system.md` §Segmented control for what happens to the row when it does.

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

- **`MapView`'s hand-placed positions and lines** — phase 7. Only the preview panel is real.
- **`ReviewView` shows the newest eight**, not a day-stable set, and its actions do nothing — phase 5.

---

## Next: phase 7 — the map

`GraphLayout` — pure, nodes and edges in, positions out, on a background actor — and `MapView` reading the real graph instead of its hand-placed dots. Books are hub nodes; above ~150 nodes the global view collapses to hubs and expands one on tap (`docs/decisions.md` §11).

**Read the paragraph above first.** The graph phase 7 draws is the one phase 6 built, and on this machine that graph came out of the fallback embedder. A device run — `docs/issues.md` §6 — turns the contextual model on and changes what the map is drawing. It doesn't block starting the layout work, which is geometry and doesn't care where the edges came from, but it does block judging whether the map looks right.

---

## Open questions for Nathaniel

Nothing here blocks phase 7 except the first one, which blocks *judging* it.

-2. **Can we get an hour on your iPhone?** It's now the only way to see the model the app is designed around. Voice, transcription, camera OCR, barcode and the share sheet are all waiting on the same evening — see `docs/issues.md` §6 — but linking has joined them and it's the one that changes a design decision rather than confirming a feature.

-1. **Is once-per-day the right surfacing rule?** Phase 5 decided a card seen twice in one sitting counts once, so swiping back and forth doesn't bury a note for months. The spec only said "when a card is actually paged past" — say so if you meant every pass.

0. **Is `▼` allowed?** The capture sheet's book picker uses it, and the prototype does too. It's terminal furniture by the same argument that permits `■` and `→`, but it's the closest thing to a dingbat in the app — say so now if it reads as one, while there's exactly one of them.

1. **Is the dark palette right?** The prototype only ever specified light; every dark value is derived.
2. **Is the body leading comfortable?** `Typography.bodyLeading` is 4pt on 15pt text (~1.6). Tightened once already from 5.
3. **Do the seed notes read as real notes?** They're the content phase 6 tunes the linking against, so if any of them feel like filler it's much cheaper to say so now.
4. **Is the Apple Developer account paid?** Needed before CloudKit sync or notifications can be provisioned. Phase 8 hits this.
5. **Is "marginalia" available on the App Store?** Likely contested. Doesn't block anything — the bundle id can change — but worth knowing before phase 10.

---

## Things worth knowing before you touch the build

Learned the hard way in phases 1 and 2.

- **The project file needs no editing to add sources.** `PBXFileSystemSynchronizedRootGroup` means folders are referenced, not files. Drop a `.swift` file anywhere under `Marginalia/` or `MarginaliaTests/` and it compiles. If you find yourself editing `project.pbxproj`, stop.
- **Pure enums touched from a `@Model` need `nonisolated`.** The project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and SwiftData models aren't MainActor, so `Note.idLabel` calling `Glyphs.noteID` doesn't compile until `Glyphs` is marked. Same for `BookStatus` and `NoteKind`.
- **Launch arguments are how you screenshot anything but the top of the stream.** The simulator can't be tapped from the command line, so every screen reached by tapping has one. The full table is in `CLAUDE.md`; they compose.
  ```bash
  xcrun simctl launch booted com.marginalia.app -startTab map
  xcrun simctl launch booted com.marginalia.app -openNote 20
  xcrun simctl launch booted com.marginalia.app -startTab books -openBook "Meditations"
  xcrun simctl launch booted com.marginalia.app -startTab books -addBook 1 -bookSearch "meditations"
  xcrun simctl launch booted com.marginalia.app -startTab books -openBook "Med" -confirmDelete book
  xcrun simctl launch booted com.marginalia.app -tinyLibrary 2 -startTab review   # uninstall first
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
| `docs/specs/2026-08-13-marginalia-design.md` | What the app does. Authority on behavior |
| `docs/design-system.md` | Every token and component spec. Authority on visual values |
| `docs/decisions.md` | Why things were chosen. 13 entries. Settled — don't reopen without a changed premise |
| `docs/prototype/` | The original Claude Design prototype. Authority on look, overridden by the spec on behavior |
| `README.md` | Human-facing |
