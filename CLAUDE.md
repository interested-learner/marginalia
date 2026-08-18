# CLAUDE.md

Working context for Claude Code in this repository. Read this before touching any file.

> **Starting a session?** Read [`docs/planning.md`](docs/planning.md) first — it says what's built, what's next, and what's temporary scaffolding waiting to be replaced. If a build hangs or the app crashes, read [`docs/issues.md`](docs/issues.md) before debugging — it is probably already in there.
>
> **Phase 11 is in progress — the first pass with a real finger on the app.** Read `docs/phase-11.md`. Every phase before it was verified by unit tests, launch arguments and screenshots, and `docs/issues.md` §12 said plainly that nothing here had ever been tapped. It has now been, once, and it came back with six reports and two crashes — **neither of them visible in code review, in 402 passing tests, or in any screenshot taken in ten phases.** Both were in code a simulator cannot reach.
>
> **The simulator still can't compile `NLContextualEmbedding`'s assets**, so every connection anyone has looked at came out of the `NLEmbedding` fallback, and about half of them are defensible — read `docs/planning.md` §phase 6 before tuning the floor or the weights, which were deliberately left at the spec's values.

## What this is

**marginalia** — a native iOS app for notes taken from books. Four tabs:

- **stream** — every note across every book, newest first, filterable by tag. A persistent capture bar sits at the bottom for text or voice. Focused, it grows `→ full note` — which carries the draft into the capture sheet — and the tab bar goes; unfocused it is one line and two buttons, and **the fast path is not allowed to get slower**. It does not name a book: `docs/decisions.md` §18.
- **books** — the library, and each book's notes.
- **map** — a summary of the ideas in the library: **themes**, ranked and named, each quoting the note at its centre; **crossings**, the connections that span two books; and **loose**, the notes joined to nothing. The force-directed graph survives one level down, where it is bounded and legible. `docs/decisions.md` §20 — and read it before proposing a whole-library canvas again, because there was one and it was a picture of opaque handles.
- **review** — a daily set of ~8 older notes, one per screen, swiped through. Resurfacing what you already thought.

Two screens have no tab and hang off the **stream's header**, which is the only header in the app that carries actions: **search** (one field over every note, thread, book, author and tag, with `#tag` filtering) and **settings** (the daily reminder, appearance, export, rebuild connections, about). Both keep the tab bar and both carry `← stream` — they're screens, not questions, so neither arrives as a sheet.

Notes are zettel-style: they carry ids (`n.11`), connect to each other, and accumulate threaded follow-ups. Quick captures with no book land in an **Inbox**, and `move to book…` on a row's long press is how they leave it — the spec has said "to be filed later" since phase 3 and until phase 11 there was no later.

**Nobody creates links by hand.** The app connects notes by meaning as they're written — see *Linking* below. Manual linking exists only as override, on the review card's `→ link` and nowhere else.

Built from a Claude Design prototype, archived at `docs/prototype/Marginalia.dc.html`. It is the authority on **look**; `docs/specs/` is the authority on **behavior** and overrides it where they disagree.

## Stack

Swift 6 · SwiftUI · SwiftData · deployment target **iOS 18.0** · Xcode 26.6.

## Design rules — these are not suggestions

The look comes from the **OpenCode design system**. It is severe on purpose, and it falls apart if any one of these slips. Full reference: `docs/design-system.md`.

1. **No raw color literals in views.** Every color comes from `Theme`. Not `Color.gray`, not `#f8f7f7`, not `.secondary`. If a color you need isn't in `Theme`, add it there with both appearances defined, then use it. This rule is the only reason dark mode works.
2. **No shadows. Anywhere.** Not on cards, sheets, buttons, or bars. Separation is done with hairlines (`Theme.hairline`, 1px) and surface tint (`Theme.surfaceSoft`) — nothing else. `--elevation-1` in the source system is a hairline, not a shadow.
3. **ASCII markers, not SF Symbols.** `[+] [x] [-] [~] [=] [◇] [↻] [q] [t] [v] [s]` and the arrows `→ ←`. Use the named cases in `Glyphs`, never a literal. There are no icons in this app — **and no dingbats either**: `★`, `✎`, `✓` and their kin read as icons and are just as forbidden. Every marker is bracket-plus-character, so `[ ] star` and `[+] add a thought`. Box-drawing and block characters (`▁▂▃▄▅▆▇`, `█░`, `■`, `●`, `▼`) are fine; they're terminal furniture, not pictures, and each one is in the prototype.
4. **Radius 4px on interactive elements only.** Buttons, inputs, chips. Everything else is square. Never a pill, never a circle, never 26pt iOS-style card corners.
5. **One font.** JetBrains Mono at every size and weight — body, headings, numbers, buttons. There is no sans face and no italic in this system.
6. **No cover art, no images, no color-coding.** Books are title + author + status marker + note count. The absence of imagery is the identity; a row of cover thumbnails would make this a different app.
7. **Lowercase chrome.** Tab labels, the wordmark, screen titles, and placeholder text are all lowercase (`stream`, `books`, `map`, `add a thought…`).
8. **One header per screen.** The wordmark appears on **stream only**. Every other screen gets a single header with its own name — never a wordmark row stacked above a title row.
9. **Support Dynamic Type.** Every size in `Typography` scales with the reader's setting. Never a hardcoded `.system(size:)`. **Chrome stops growing at `xLarge` and content never stops** — `chromeTypeSize()`, on the tab bar, `ScreenHeader`, review's foot, the map's nodes and foot, and the capture bar's `[+]` and `[●]`, and on nothing else. A note gets every point it asks for; a signpost that fills the room it points out of is worse at its job. **The margin folds** past `isAccessibilitySize` and the id moves above the note — the one conditional in the margin rule, and `docs/design-system.md` says why.
10. **A quote wears the rule and no quote marks.** `“ ”` is a rule *and* quote marks, which is not a convention, and it would be the closest thing to a dingbat in the app. The 2pt `ink` rule is the mark. `docs/issues.md` §18 — which asserted for three phases that the app didn't draw them while two files did.

Colors, condensed — but `Theme.swift` is authoritative:

| token | light | dark |
|---|---|---|
| `canvas` | `#fdfcfc` | `#201d1d` |
| `surfaceSoft` | `#f8f7f7` | `#302c2c` |
| `ink` | `#201d1d` | `#fdfcfc` |
| `onInk` | `#fdfcfc` | `#201d1d` |
| `textBody` | `#424245` | `#d8d6d6` |
| `textMute` | `#646262` | `#9a9898` |
| `textAsh` | `#9a9898` | `#787676` |
| `hairline` | ink @ 12% | paper @ 12% |
| `danger` | `#ff3b30` | `#ff453a` |

`danger` is the one saturated color in the app — the recording dot and destructive confirmations. Nothing else.

**Two layout devices carry the identity**, both new since the prototype and both described in `docs/design-system.md`:

- **The margin** — stream and book-detail rows put the note id in a 48pt column with a hairline down its trailing edge. The app is named after marks made in a margin; this is that margin.
- **The quote rule** — quotes get a 2pt `ink` rule on the leading edge, *not* a filled block. Quote text is `ink`; thought bodies are `textBody`.

## Linking — automatic

Notes connect themselves. The user is never asked to link anything and there is no accept/dismiss flow.

- `NoteEmbedding` vectorizes each note with `NLContextualEmbedding`, falling back to `NLEmbedding.sentenceEmbedding` when Apple's assets aren't downloaded yet. **The app must work on first launch either way.** On-device only — no network, no key.
- **A vector is only comparable to a vector from the same model.** `Note.embeddingSourceRaw` records which one produced it, and a note whose source isn't the one loaded today is stale — that's the second way into the embedding queue after `embeddedAt == nil`, and it's what re-embeds a whole library the day the contextual assets finally arrive. Never score across sources.
- `LinkWriter` is the one path an edge takes to exist, and it does a **full recompute**, not a delta: a new note can displace somebody else's eighth-best neighbour or fill their sixth slot, and only a whole pass notices. It runs off the main actor and is triggered in exactly one place — `.linking()` on the root view.
- `AffinityEngine` scores pairs `0.8 · cosine + 0.2 · tagOverlap`. Same-book is deliberately **not** boosted; books are already hub nodes and rewarding it again just clumps each book into a ball.
- Three constraints keep the graph from becoming a hairball: a **floor** of `score ≥ 0.55`, **mutual k-NN** (each note in the other's top 8), and a **degree cap** of 6.
- **Automatic and manual links render identically.** `isPinned` and `isSuppressed` on `NoteEdge` exist only to make override work — never surface them in the UI, never draw a manual link differently.
- **Backlinks are always shown.** Edges store direction but display both ways, or half of every note's connections are invisible.
- **`LinkWriter.pin` is the only writer of `isPinned`**, reached from `→ link` on a review card and from nowhere else. Pinning a pair the reader once disconnected un-suppresses it: both flags record a deliberate act and this is the newer one.
- **The recompute has been measured**, so nobody has to guess again: **0.71 µs a pair at `-O`** — 350 ms at a thousand notes, ~9 seconds at five thousand, off the main actor throughout. `AffinityBenchmarkTests` is the measurement and it must be run in **Release**; the same pass is 60× slower unoptimized, so a Debug number says nothing about the app anybody installs.

## The map — a summary first, a graph second

- **The tab's top level is `MapView`, and it is a list.** Themes, crossings, loose. That is what a reader can actually take away, and it is the form Dynamic Type and VoiceOver work on — the canvas never could. `docs/decisions.md` §20.
- **`ThemeEngine` groups; `ThemeName` names; both are pure.** Neither sees a model, exactly as `AffinityEngine` never does.
- **Ranked, never thresholded — this is the load-bearing decision.** An absolute similarity cut is a number tuned to a model the app is designed to abandon: at `0.45` today's fallback embedder yields *zero* themes, and the day `NLContextualEmbedding`'s assets compile the magnitudes move wholesale. So a note ranks every other by `AffinityEngine.score`, pairs survive where each is in the other's top 6, and communities come from **unweighted** greedy modularity. **Do not feed scores into the merge** — modularity gain isn't invariant under a non-uniform change in weights, and that is exactly what changing embedder is. `ThemeEngineTests` has the test that guards it.
- **It deliberately ignores the floor, the k-NN at 8 and the degree cap of 6.** Those keep a *drawing* legible; grouping is a different job. That independence is what finally connects `n.03` and `n.04` — the near-restatement scoring 0.448 that phase 6 called the worse half of its own output.
- **A name is extracted, never invented, and never a tag.** `ThemeName` takes noun phrases from `NounPhrases` (the impure half, which runs `NLTagger`) and picks the ones distinctive to the theme; if its notes share nothing, there is **no name** and the exemplar leads. Tags named themes for one afternoon: the grouping never needed them, but six of seven seed themes came out tag-named and the screen read as though tagging were the mechanism. **Don't put them back** — `docs/decisions.md` §20 records what it cost and why it was accepted.
- **The names are mediocre and that is downstream of the grouping.** `truth · weather` is a bad name for a loosely-coherent group, and no extractor names a bad cluster well. Don't tune `ThemeName` against the fallback embedder's output — that is phase 6's mistake, twice.
- **The exemplar is evidence, not decoration.** It is the only reason a reader can catch a grouping the app got wrong, which matters more here than anywhere, because the themes ride on an embedder nobody has verified.
- **`MapGraph` decides what's in a view; `GraphLayout` decides where it goes.** Both pure. `GraphView` is the half that touches the store; `GraphCanvas` is handed a built graph and hands back what was tapped.
- **Every graph view is bounded: one theme, two hops from a note, or one book.** The whole-library view and the book-hub collapse are gone, along with `collapseAbove` and `-mapCollapse`.
- **A local view never hops *through* a book.** One hop through a hub is every note in it, and the view stops being local. Hubs come back at the end, attached to whatever notes were reached.
- **`GraphLayout` is told the shape of the box and the size of every label**, and both matter. A graph laid out square and drawn into a box twice as tall squeezes every horizontal gap by half; a hub spaced as if it were a point sits straight through the note beside it. Both were seen on screen before they were understood.
- **Two kinds of line meet here and they are not the same fact.** A **connection** is note-to-note, scored on meaning, and it crosses books freely. An **attachment** is a note to the book it was written from — structure, not something the app found. Both are drawn at the same hairline, because there is one line weight in this system, but the reader can **subtract** the attachments with `connections only` in the chip row. That adds no vocabulary — no dash, no second weight, no color — it only stops drawing. **Filter at the stroke, never in `web`:** `GraphLayout` must go on being told about every edge or nothing stays where it was, and an attachment is what gathers a book's notes around its hub in the first place.
- **Deleting a connection doesn't delete the edge.** `Eraser.suppress` sets `isSuppressed` and keeps the row, because the next recompute — and every recompute is a full one — would otherwise score the same pair, find it just as strong, and draw the line straight back. Suppression *is* the memory of the deletion.
- **A crossing shows each note once.** A display rule, not a claim about the data: unfiltered, one hub note took three consecutive rows with its text repeated each time.
- **The themes are well-formed, not verified.** Rank-invariance fixes scale, not signal. Read `ThemeDumpTests` on a device beside `AffinityDumpTests` before trusting a single theme name.

## Data model rules

Every `@Model` must stay **CloudKit-compatible**, even though sync is off. Enabling it later should be a container-configuration change, not a migration.

- Every stored property has a default value.
- Every relationship is optional (`[Note]? = []`, `Book?`).
- **No `@Attribute(.unique)`** — CloudKit rejects unique constraints.
- Embeddings are stored as `Data` (packed `Float32`), not `[Float]`.

`Note.shortID` is a monotonic `Int` from `UserDefaults`, rendered as `n.11`. Ids are never reused after a delete — a dangling `→ n.07` pointing at a *different* note is worse than one pointing at nothing.

## Keep these pure

These types take plain values and return plain values, with no SwiftData inside. That's what makes them testable, and it's not negotiable:

- **`ThemeEngine`** — vectors + tags → themes and loose notes. Ranked, never thresholded
- **`ThemeName`** — tags + words → what a theme is called, or nothing
- **`ReviewSetBuilder`** — `[Note]` + `Date` → the day's set (day-stable, ≤8, ≤2 per book, starred weighted, ≥1 currently-reading)
- **`AffinityEngine`** — vectors + tags → edges
- **`GraphLayout`** — nodes + edges → positions
- **`SearchQuery` / `SearchIndex`** — what was typed → which notes, grouped by book
- **`MarkdownExport`** — plain records → the document. Only `file(_:)` at the foot of it touches a disk
- **`NotificationPlan`** — `[Note]` + a time → the next seven reminders. `NotificationScheduler` is the half that talks to iOS
- **`ScannedPassage`** — the lines a reader tapped → the passage as it was printed. `TextScanner` is the half that talks to the camera

## File map

```
Marginalia/
  MarginaliaApp.swift        @main, ModelContainer, root TabView
  Design/
    Theme.swift              every hex, light + dark. The only place colors live
    Typography.swift         font registration + Dynamic Type scale, and
                             `chromeTypeSize()` — the one ceiling in the app
    Glyphs.swift             the ASCII vocabulary, named
    Haptics.swift            the five events, named for what happened
    Components/              shared views — see docs/design-system.md
  Model/
    Book  Note  FollowUp  NoteEdge      the four @Model types
    Library                  schema, container, first-launch bootstrap
    SeedLibrary              the 40 seed notes, as plain values
    ShortIDCounter           monotonic n.11 ids, never reused
    CaptureDraft             what's typed → what a Note stores. Pure
    BookDraft                what's typed → what a Book stores. Pure
    TypedPage                `"p. 214"` → `214`, for every page field. Pure —
                             and `CaptureDraft` really does call it now
    NoteWriter               the one path a note takes to exist, and `refile`,
                             the one path it takes to change books
    BookWriter               the one path a book takes to exist, and changes by
    ReviewWriter             the one path a follow-up, a star and a surfacing
                             take. Surfacing counts once per day, never at build
    Eraser                   the one path anything takes to stop existing, and
                             `Erasure` — what a confirmation is about to remove
    BookShelf                the order the library reads in, and its filters. Pure
    RowMapping               models → NoteRowData / BookRowData, and models →
                             MarkdownExport's records. The only file that knows
                             about both sides
    Preferences              appearance, reminder time, reminder on/off — the
                             keys, once, plus `Appearance` and `ClockTime`. Pure
    RelativeTime             `2 mins ago`, `aug 01`, `0:07`
    ConnectionIndex          edges → who connects to whom, both directions
    LinkWriter               the one path an edge takes to exist, and `.linking()`,
                             the one place a recompute is triggered from
  Features/
    Stream/                  StreamView, StreamGrouping, TagIndex
    Capture/                 CaptureBar, CaptureSheet, VoiceCapture, AudioLevels,
                             BookPickerField — the one book picker, shared by the
                             sheet and MoveNoteSheet, where the Inbox is
                             `— no book —` rather than a row — and MoveNoteSheet,
                             which is how a note leaves the Inbox
    Review/                  ReviewView, ReviewCard + ShareCard, ReviewSetBuilder,
                             FollowUpSheet
    Map/                     MapView — the overview: themes, crossings, loose —
                             and MapRows, ThemeDetailView, GraphView (the graph
                             screen, which touches the store), GraphCanvas (the
                             canvas, which doesn't), and MapGraph — which nodes
                             belong in a view and which lines join them. Pure
    Search/                  SearchView, SearchQuery, SearchIndex — and
                             NotePicker, the one sheet that makes a link by hand
    Settings/                SettingsView — the reminder, appearance, export,
                             rebuild connections, about
    Books/
  Services/
    NoteEmbedding            NLContextualEmbedding + fallback, and the packing
    AffinityEngine           scoring, mutual k-NN, pinning, suppression. Pure
    GraphLayout              force-directed, pure, off the main actor. Told the
                             shape of the box and the size of every label
    ThemeEngine              which notes belong together. Mutual top-6 by
                             AffinityEngine.score, then unweighted modularity.
                             No threshold anywhere. Pure
    ThemeName                a theme's name: the reader's tag, else the
                             distinctive terms, else nothing. Pure
    SpeechTranscription      SFSpeechRecognizer, on-device only
    TextScanner              VisionKit in text mode, tap-to-select, and
                             `TextScannerScreen` — the camera under the app's
                             own chrome
    ScannedPassage           tapped lines → the passage as printed. Pure, and
                             the one place a word broken at the margin is
                             rejoined. It never infers a page number
    BarcodeScanner           VisionKit → ISBN
    BookLookup               Open Library
    NotificationPlan         which note each of the next 7 days carries. Pure
    NotificationScheduler    the half that talks to UserNotifications, and
                             `.reminders()`, the one place scheduling happens
    MarkdownExport           the library as one document. Pure
  Resources/Fonts/           JetBrains Mono (SIL OFL)
MarginaliaTests/
Tools/
  MakeAppIcon.swift          the icon, as source. `swift Tools/MakeAppIcon.swift`
```

**The app icon is generated, not exported.** `Tools/MakeAppIcon.swift` reads the repo's own JetBrains Mono and the two hexes `Theme` defines, and writes the three PNGs and the catalog's `Contents.json`. Edit the script, re-run it, rebuild — never hand-edit the PNGs, or the icon and the palette drift apart silently. **The tinted variant must stay opaque**: iOS 26's Liquid Glass pass puts a specular highlight behind the artwork and over a transparent image that highlight *becomes* the artwork. See `docs/issues.md` §20.

`Marginalia.xcodeproj` uses **synchronized file groups** (`PBXFileSystemSynchronizedRootGroup`, Xcode 16+). New `.swift` files under `Marginalia/` are picked up automatically — **do not hand-edit the project file to add sources.** If you're about to touch `project.pbxproj`, you almost certainly don't need to.

`Support/Info.plist` sits outside the synchronized group deliberately, so it isn't copied in as a resource.

**Views never see SwiftData.** They take `NoteRowData` / `BookRowData`, and `Model/RowMapping.swift` is the only file that knows about both sides. That separation is what let the whole design system be built and judged before the model existed, and it's worth keeping.

**Launch arguments are not scaffolding to remove.** The simulator can't be tapped from the command line, so they're the only way to screenshot anything but the top of the stream:

| | |
|---|---|
| `-startTab <stream\|books\|map\|review>` | opens on that tab |
| `-openNote <id>` | opens the stream scrolled to `n.<id>` |
| `-captureDraft "<text>"` | fills the capture bar and focuses it — which is also the only way to see `→ full note`, the tap-off scrim and the hidden tab bar |
| `-captureMore 1` | opens the capture sheet the way `→ full note` does, over the stream. With `-captureDraft`, carrying that draft |
| `-bookPicker 1` | opens every book picker's list — the half a closed field never shows. Pair it with `-captureMore`, `-captureSheet` or `-moveNote` |
| `-moveNote <id>` | opens `move to book…` over the stream for `n.<id>` |
| `-captureBar <recording\|transcribing>` | the recording rows, without a microphone |
| `-captureSheet <quote\|thought\|voice\|scan>` | opens the full sheet over the first book's detail |
| `-scanner 1` | with `-captureSheet scan`, opens the text scanner — **the simulator has no camera**, so what you see is the written fallback |
| `-scanned "<text>"` | the passage a scan produced, without one. With `-scanner` it fills the scanner's preview; without it, the sheet's field |
| `-openBook "<title>"` | opens that book's detail — matched on any part of the title |
| `-addBook 1` | opens the add-book form |
| `-bookSearch "<query>"` | fills the form's search field and runs it |
| `-bookFilter <reading\|queued\|finished>` | opens the library on that chip |
| `-reviewCard <n>` | opens review on the nth card of the day's set |
| `-reviewEnd 1` | opens review on the closing card |
| `-followUp 1` | opens the follow-up composer over the current card |
| `-confirmDelete <book\|note>` | opens the delete confirmation over book detail |
| `-confirmDelete connection` | with `-startTab map`, the disconnect confirmation |
| `-mapSelect <id>` | opens the graph with `n.<id>` selected — the panel, and an inverted node |
| `-mapNote <id>` | opens the graph two hops out from `n.<id>` |
| `-mapBook "<title>"` | opens the graph on that book alone — matched on any part of the title |
| `-mapTheme <id>` | opens the theme whose **exemplar** is `n.<id>` — an identity, not an ordinal |
| `-mapThemeGraph <id>` | that theme's graph |
| `-mapCrossings 1` | scrolls the overview to `crossings` — the lower sections are otherwise unscreenshottable |
| `-mapLines <all\|connections>` | the map with the book attachments subtracted — and the third line of the foot's hint, which only appears then |
| `-search "<query>"` | opens the search screen with that query already run |
| `-settings 1` | opens settings |
| `-preference.notifications 1` | settings with the reminder on — **and the permission prompt, which sticks to the simulator until it's answered by hand.** Reboot the simulator to clear it |
| `-link 1` | opens the link picker over the current review card |
| `-linkSearch "<query>"` | fills the link picker's field |
| `-tinyLibrary <n>` | seeds `n` notes instead of forty — **uninstall first** |
| `-storeFailure 1` | opens the "library won't open" screen |

`-tinyLibrary` spreads its notes **across books**, one at a time, rather than taking them off the front of the seed. `ReviewSetBuilder` allows two cards per book, so a prefix of one book's notes builds a set of two and always lands on review's empty state, whatever number you asked for. `2` is the empty state; `4` is a full set with nothing left over, which is the only way to see an exhausted `[↻] keep going`.

## Commands

```bash
# build + test. -derivedDataPath keeps the CLI out of Xcode's build database:
# they drive the same XCBBuildService and deadlock each other. See issues.md §2.
xcodebuild -scheme Marginalia -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .build build test

# run in the simulator
xcrun simctl boot "iPhone 17"
xcrun simctl install booted .build/Build/Products/Debug-iphonesimulator/Marginalia.app
xcrun simctl launch booted com.marginalia.app

# check both appearances — do this after any UI change
xcrun simctl ui booted appearance dark      # or: light
xcrun simctl io booted screenshot /tmp/marginalia.png

# and the largest text, which is where layout actually breaks. Note the
# underscore — `content-size` is not the option name and prints the usage.
xcrun simctl ui booted content_size accessibility-extra-extra-extra-large
xcrun simctl ui booted content_size large   # put it back

# the other supported runtime. Its own derived data, for the reason in issues.md §2
xcodebuild -scheme Marginalia -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' \
  -derivedDataPath .build-ios18 build test

# the app icon, after editing Tools/MakeAppIcon.swift
swift Tools/MakeAppIcon.swift

# the simulator can't be tapped from the command line, so to screenshot
# any tab that isn't stream:
xcrun simctl launch booted com.marginalia.app -startTab map
```

Tests use **Swift Testing** (`@Test`, `#expect`), not XCTest.

**Run `build test`, not `build`.** A broken test target can fail to link while `build` alone still reports success — that happened in phase 1 and went unnoticed until the suite was actually run.

## Working notes

- **Verify visually, not by reasoning.** After a UI change, screenshot the simulator in *both* appearances **and at `accessibility-extra-extra-extra-large`**, and actually look at the images. Five real defects so far were invisible in code review and obvious in an image — and the AX5 screenshot that found the tab bar coming apart is also what caught the app drawing curly quotes it had been documented for three phases as not drawing. Look at the whole image, not the thing you changed.
- **Haptics go through `Haptics`**, never a `UIFeedbackGenerator` at a call site. Five events named for what happened — `saved` `starred` `erased` `paged` `captured` — and navigation gets none: a haptic marks something that happened to the *library*. `erased` fires from `ConfirmSheet`'s button, the one door every delete goes through. **No haptic has ever been felt**; the simulator has no Taptic Engine.
- **Tests can't tell you whether the links are any good.** They prove `AffinityEngine` respects its floor, its k-NN rule, and its degree cap. Whether the connections are *defensible* needs a human reading real output — `AffinityDumpTests` prints each seed note's top 5, and it's off unless asked for:
  ```bash
  TEST_RUNNER_MARGINALIA_DUMP=1 xcodebuild -scheme Marginalia \
    -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath .build \
    test -only-testing:MarginaliaTests/AffinityDumpTests 2>&1 | grep '^|'
  ```
- **A performance number from a Debug build is not a number.** `AffinityEngine` is 60× slower unoptimized, so `AffinityBenchmarkTests` is only worth running at `-O`. Release disables `-enable-testing`, so `@testable` needs it turned back on by hand:
  ```bash
  TEST_RUNNER_MARGINALIA_BENCH=1 xcodebuild -scheme Marginalia \
    -configuration Release SWIFT_ENABLE_TESTABILITY=YES \
    -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath .build-release \
    test -only-testing:MarginaliaTests/AffinityBenchmarkTests 2>&1 | grep '^|'
  ```
- **The simulator gets the fallback embedder, always.** `NLContextualEmbedding`'s assets are present but can't compile — `/var/db/com.apple.naturallanguaged` isn't writable from an app sandbox there, and the log says `Permission denied` before the fallback takes over. Nothing seen on this machine is evidence about the model the app is actually built around. See `docs/issues.md` §14.
- **Permissions are requested at first use**, never at launch. Microphone, speech recognition, camera and notifications each prompt at the moment the feature is invoked. That rule is why `NotificationScheduler` has both `isAuthorized` (never prompts, used by the scheduler on every launch) and `authorize` (prompts, used only by the toggle in settings) — a scheduler that asked would break the rule every time the app opened, and the screenshot that caught it is the only reason anybody noticed.
- **The simulator cannot test** microphone, transcription, camera OCR, or barcode scanning. Those need the device. Don't claim they work from a simulator run.
- **Open Library needs no API key** and imposes no attribution requirement. Manual book entry must always remain available — treat lookup failure as routine, not exceptional.
- **Seed ~40 notes**, not 12. A sparse map proves nothing about whether the layout works. `SeedLibrary` has them, and the cross-book tag overlap in them is deliberate — it's what phase 6 tunes against.
- **Pure enums used from a `@Model` need `nonisolated`.** The project defaults to `MainActor` isolation and SwiftData models aren't; `Glyphs`, `BookStatus`, `NoteKind`, `Inbox`, `AudioLevels` and `BookShelf` are marked accordingly.
- **So does anything handing a closure to a system framework**, and this one is a crash rather than a compile error. `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` makes such a closure `@MainActor`; UIKit, AVFoundation, Speech and Vision call them on their own threads; Swift 6 traps. `Theme` is `nonisolated` for exactly this reason — it cost five identical `EXC_BREAKPOINT` crashes before anyone read the report. **Mark the closure `@Sendable` at the call site**, every time: it costs nothing where the compiler had already inferred it and removes a crash where it hadn't. `docs/issues.md` §1 declared this audit complete for two phases while `SFSpeechRecognizer.requestAuthorization` sat three lines below the one line it had checked (§22).
- **Nothing expensive in a `body`.** An `ImageRenderer` inside `ShareCardLink.body` drew a multi-megabyte bitmap for every realized review card on every redraw — a render pass nested inside a render pass — and it is the best candidate for the crash at the end of the set. The same rule caught three cheaper versions of itself in the same pass: `ConnectionIndex.build` read from inside a `ForEach` rebuilds per row, and `ReviewSetBuilder.set` behind a computed property runs over the whole library per redraw. **Build it once above the loop, or hold it in `@State`.** `docs/issues.md` §23.
- **Two siblings in a `VStack` where one of them scrolls is a feedback loop waiting to happen.** Review's foot hid a line on the last card, which grew the paging scroll view by 27pt, which changed every page's height while one was mid-flight. Hide with `.opacity`, never by removing from the layout. The map had the same shape: its panel appearing shrank the canvas, which changed the aspect `GraphLayout` is told, which re-laid out the entire graph on every tap.
- **Notes are written in exactly one place.** `NoteWriter.save` allocates the id, trims the body, and falls back to the Inbox. A second write path would drift from it — add a caller, not a copy. **Books likewise go through `BookWriter`**, whether they arrived by search, by barcode, or typed in.
- **And deleted in exactly one place.** `Eraser` exists because `context.delete(note)` is not enough: `NoteEdge.from` and `.to` have no inverse, so SwiftData nils them instead of removing the edge, and an edge with one end missing is a connection that can never be drawn and never be cleaned up. Follow-ups and a book's notes *are* cascaded by the schema; the edges of every note a book takes with it are not.
- **Every delete goes through a confirmation, and the Inbox refuses.** `Eraser.delete(book:)` returns `false` for it, for the same reason `BookWriter.apply` won't restatus it — it's found by status, and deleting it would take every quick capture with it while the next one silently built a second drawer.
- **The Inbox can't be edited.** It's found by status and it's where every unfiled capture falls back to, so `BookWriter.apply` refuses to change its status and book detail doesn't offer `edit` on it. An Inbox marked `reading` would quietly stop being one and the next quick capture would build a second.
- **A lookup result fills the form; it never saves straight through.** Open Library gets authors and page counts wrong often enough that the last word has to belong to the reader — and it holds a separate work record per translation, so `BookLookup` collapses repeats of the same title and author.
- **A transcript is never saved unseen, and neither is a scan.** On-device recognition is wrong often enough that it lands in an editable field, both in the bar and in the sheet; OCR off a printed page is the same bet and lands in the same kind of field. Editing either leaves the note `[v] voice` or `[s] scan`: how it was captured is a fact about the note, not about the keystrokes.
- **A scan is drawn as a passage and marked as a scan.** `NoteKind.isPassage` is what the quote rule keys on, and it's true for `.quote` and `.scan` — a scan is somebody else's words off a page. The marker still says `[s]`, by the rule above. Never test `kind == .quote` to decide how a body is drawn.
- **The page number is typed, never inferred.** A folio or a running head is text like any other in the frame, and `ScannedPassage` deliberately doesn't hunt for one — a page number that's wrong one time in five is worse than a field the reader fills in.
- **A note has a page; a book does not have a bookmark.** `Book.currentPage`, `Book.progress` and the progress bar came out in phase 11 — the only way to move that number was four taps through `edit`, so it was always stale, and deriving it from a note's page would be the app's first inference about the reader. `Book.pageCount` stays: it's how long the book is, which is a fact, and it reads as `499pp` in book detail's byline. `docs/decisions.md` §17.
- **The day's review set is built once and held in `@State`.** Rebuilding it every redraw would reshuffle the deck the moment the reader starred something, because a star is one of the things the set is scored on.
- **Don't name a property `set`.** `private var counter: String { set.count … }` fails to parse — Swift reads `set` at the start of a property body as the setter keyword.
- **`Spacer` collapses inside a `ScrollView`.** Content there sizes to itself, so vertical centering is a `.frame(minHeight:)` against a `GeometryReader`, which is how the review card does it.
- **A cancelled `.task(id:)` still finishes what it was awaiting.** `Task.detached` is not cancelled with its awaiter, so the superseded pass resumes when the detached work completes and writes its result — after the new one. On the map that drew one book's nine notes at the coordinates they'd had in the whole-library graph: a clump in the corner of an empty screen, with a perfectly correct header above it. **Guard on `Task.isCancelled` before assigning**, in any `.task(id:)` that hands work to a detached task.
- **`Synchronization.Mutex` can't be captured in a closure** — it's non-copyable. Where an audio callback has to hand a value back, `OSAllocatedUnfairLock` is what works (see `VoiceCapture.peak`).

## Don't

- Don't add a dependency without asking. The app has zero.
- Don't introduce SF Symbols, cover images, shadows, gradients, or a second typeface.
- Don't draw automatic and manual links differently. That was decided against deliberately.
- Don't enable CloudKit until the paid Apple Developer account is confirmed — it will fail to provision.
- Don't reformat the archived prototype in `docs/prototype/`. It's a reference artifact.
- Don't re-litigate settled decisions. `docs/decisions.md` records what was chosen and why.
