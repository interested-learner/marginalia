# CLAUDE.md

Working context for Claude Code in this repository. Read this before touching any file.

> **Starting a session?** Read [`docs/planning.md`](docs/planning.md) first — it says what's built, what's next, and what's temporary scaffolding waiting to be replaced. If a build hangs or the app crashes, read [`docs/issues.md`](docs/issues.md) before debugging — it is probably already in there.
>
> **Phase 12 removed a whole tab.** Read `docs/phase-12.md` and `docs/decisions.md` §21. The map was read on a device and the verdict was not that it was wrong but that there was **no reason to open it** — so the summary, the graph and everything under them came out, and the one thing worth keeping moved into review as the **crossing card**. 4,082 lines and 90 tests went with it. If you are about to propose a screen that draws the library, read §21 first.
>
> **Phase 13 removed things the app was saying twice.** Read `docs/decisions.md` §22. `[t] thought` became `thought`, `→ n.11` came off every row on every screen, and the crossing card's bare hairline became a `LabeledRule` carrying `29 days apart`. The rule that decided the first: **a glyph earns its place beside a verb, never beside the glyph's own name.** If you are about to add a marker to a label, or an id to a line, read §22 first.
>
> **Phase 11 was the first pass with a real finger on the app.** Read `docs/phase-11.md`. Every phase before it was verified by unit tests, launch arguments and screenshots, and `docs/issues.md` §12 said plainly that nothing here had ever been tapped. It has now been, and it came back with six reports and two crashes — **neither of them visible in code review, in a full passing suite, or in any screenshot taken in ten phases.** Both were in code a simulator cannot reach.
>
> **The simulator still can't compile `NLContextualEmbedding`'s assets**, so every connection anyone has looked at came out of the `NLEmbedding` fallback, and about half of them are defensible — read `docs/planning.md` §phase 6 before tuning the floor or the weights, which were deliberately left at the spec's values.

## What this is

**marginalia** — a native iOS app for notes taken from books. Three tabs:

- **stream** — every note across every book, newest first, filterable by tag. A persistent capture bar sits at the bottom for text or voice. Focused, it grows `→ full note` — which carries the draft into the capture sheet — and the tab bar goes; unfocused it is one line and two buttons, and **the fast path is not allowed to get slower**. It does not name a book: `docs/decisions.md` §18.
- **books** — the library, and each book's notes.
- **review** — a daily set of ~8 older notes, one per screen, swiped through. Resurfacing what you already thought. **It reopens exactly where you left it** — same notes, same card, same crossing — until the calendar day turns, including across a relaunch and a night in the background. `ReviewSession` is the memory and `docs/decisions.md` §23 is why it can't be recomputed. **A ninth card**, when the library has one to show, is a **crossing**: two notes from two different books that the app connected by meaning, with the gap in time between them. It is the one place a reader can contradict the linking engine — `[x] not related`. `docs/decisions.md` §21.

**There was a fourth tab, `map`, and it is gone** — read `docs/decisions.md` §21 before proposing any screen that draws the library, because there were three of them and the last one was deleted the day after it shipped. The complaint that killed it was never that the drawing was illegible or that the themes were wrong; it was that there was no reason to open it.

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
3. **ASCII markers, not SF Symbols.** `[+] [x] [-] [~] [=] [◇] [↻] [q] [t] [v] [s]` and the arrows `→ ←`. Use the named cases in `Glyphs`, never a literal. There are no icons in this app — **and no dingbats either**: `★`, `✎`, `✓` and their kin read as icons and are just as forbidden. Every marker is bracket-plus-character, so `[ ] star` and `[+] add a thought`. **But a marker beside its own name says one thing twice** — `[t] thought` became `thought` in phase 13, and the kind markers now appear only in the capture sheet's type selector, where they mark a *control*. The test: a glyph earns its place beside a **verb**, never beside the glyph's own name. `docs/decisions.md` §22. Box-drawing and block characters (`▁▂▃▄▅▆▇`, `█░`, `■`, `●`, `▼`) are fine; they're terminal furniture, not pictures, and each one is in the prototype.
4. **Radius 4px on interactive elements only.** Buttons, inputs, chips. Everything else is square. Never a pill, never a circle, never 26pt iOS-style card corners.
5. **One font.** JetBrains Mono at every size and weight — body, headings, numbers, buttons. There is no sans face and no italic in this system.
6. **No cover art, no images, no color-coding.** Books are title + author + status marker + note count. The absence of imagery is the identity; a row of cover thumbnails would make this a different app.
7. **Lowercase chrome.** Tab labels, the wordmark, screen titles, and placeholder text are all lowercase (`stream`, `books`, `review`, `add a thought…`).
8. **One header per screen.** The wordmark appears on **stream only**. Every other screen gets a single header with its own name — never a wordmark row stacked above a title row.
9. **Support Dynamic Type.** Every size in `Typography` scales with the reader's setting. Never a hardcoded `.system(size:)`. **Chrome stops growing at `xLarge` and content never stops** — `chromeTypeSize()`, on the tab bar, `ScreenHeader`, review's foot, the capture bar's `[+]` and `[●]`, and the crossing card's head, and on nothing else. A note gets every point it asks for; a signpost that fills the room it points out of is worse at its job. **The margin folds** past `isAccessibilitySize` and the id moves above the note — the one conditional in the margin rule, and `docs/design-system.md` says why.
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
- `AffinityEngine` scores pairs `0.8 · cosine + 0.2 · tagOverlap`. Same-book is deliberately **not** boosted — a line between two books is the only kind worth anything here, and rewarding proximity again would bury it.
- Three constraints keep the web from becoming a hairball: a **floor** of `score ≥ 0.55`, **mutual k-NN** (each note in the other's top 8), and a **degree cap** of 6.
- **Automatic and manual links render identically.** `isPinned` and `isSuppressed` on `NoteEdge` exist only to make override work — never surface them in the UI, never draw a manual link differently.
- **Edges store direction and it is never displayed.** Both ends of a connection are equal wherever one is shown, or half of every note's connections are invisible. **`→ n.11` is no longer one of those places** — phase 13 took the id links off every row, because a bare id gives the reader nothing to decide with. What still shows the graph: the markdown export (`[[n.03]] · [[n.09]]`), settings' connection count, `NotePicker`'s already-joined filter, and the crossing card. `docs/decisions.md` §22.
- **`LinkWriter.pin` is the only writer of `isPinned`**, reached from `→ link` on a review card and from nowhere else. Pinning a pair the reader once disconnected un-suppresses it: both flags record a deliberate act and this is the newer one.
- **There is exactly one place a reader can contradict the app**, and it is `[x] not related` on the crossing card in review. It goes through `ConfirmSheet` and `Eraser.suppress` like every other delete in the app — the flag is the memory of the deletion, because every recompute is a full one and would otherwise score the same pair and find it just as strong. **It is an affordance, never a question**: it does not gate paging and skipping it costs nothing, so §10's promise that nobody is asked to link anything is unbroken. It is also the linking system's only feedback loop; before it, the app guessed at meaning and nothing anywhere could tell it it was wrong.
- **Deleting a connection doesn't delete the edge.** `Eraser.suppress` sets `isSuppressed` and keeps the row, for the reason above. `CrossingFinder` skips suppressed edges, which is what makes the answer stick.
- **The recompute has been measured**, so nobody has to guess again: **0.71 µs a pair at `-O`** — 350 ms at a thousand notes, ~9 seconds at five thousand, off the main actor throughout. `AffinityBenchmarkTests` is the measurement and it must be run in **Release**; the same pass is 60× slower unoptimized, so a Debug number says nothing about the app anybody installs.

## The crossing card

- **A crossing is one connection that spans two books**, and it is the best thing the linking engine computes. It lived on the map as `MapView.crossingRows`, on a screen nobody opened; `docs/decisions.md` §21 is why it moved into review and the drawing did not.
- **`CrossingFinder` is pure and ranked, never thresholded.** Cross-book only, the Inbox excluded (it is found by status and is not a source — the third place it is special, after `BookWriter` and `Eraser`), suppressed edges excluded, strongest first with ties on the pair id.
- **A crossing shows each note once.** A display rule, not a claim about the data: unfiltered, one hub note took three consecutive rows with its text repeated each time. Every one of those connections still exists under the note itself.
- **At most one a day, and it rotates.** `crossings[daySeed % count]` — `daySeed` advances by one a day, so the reader walks the ranked list an entry at a time and it cycles rather than repeating one pair forever. **Never pin the strongest**, including in the fallback when every candidate overlaps the day's own eight notes: that shows one pair every day on a small library, which is exactly what the rotation exists to prevent, and a small library is where the overlap happens.
- **Paging past a crossing surfaces nothing.** `ReviewWriter` is not called for it. The crossing is extra, and marking both notes surfaced would quietly reshape tomorrow's eight — `ReviewSetBuilder` scores on that field.
- **Two notes at `noteBody`, never `reviewBody`.** Every other review card is one note filling the screen at 18pt; at 18pt each the second half of a crossing is below the fold before the reader has a reason to look for it, and the gap between them is the point of the card.
- **A `LabeledRule` between the halves carrying the gap, never an arrow.** `NoteEdge` stores a direction and the app has displayed both ways since phase 6; a `→` here would be the first place it contradicted that, and a label is not a direction. It is labeled rather than bare because a bare hairline means *these are separate items* everywhere else in the app, which is the opposite of what this card says.
- **The head names the claimant, not the claim** — `[◇] crossing` over `the app connected these two notes`, and it is capped by `chromeTypeSize()`. Not *the same idea*: that would be a claim the model makes, which §21 rules out, and it is the app's line that `[x] not related` contradicts. No ids.
- **The card opens notes; it does not duplicate their actions.** Tapping either half opens it where `star` and `add a thought` already live. `ActionRow`'s own note records that four labels overflow a phone at 13pt mono.
- **`RelativeTime.gap` renders the distance** — `29 days apart`, `7 months apart` — beside `label` / `dayLabel` / `elapsed`, numerals and lowercase like the rest of them. **It sits in the seam, not the foot**: below both notes it read as chrome, and it is the fact that lands.
- **Whether any crossing is *true* is unverified and cannot be verified here.** It rides on the same scores everything else does, and `docs/issues.md` §14 means every one anybody has read came out of the fallback embedder. Read `AffinityDumpTests` on a device.

## Data model rules

Every `@Model` must stay **CloudKit-compatible**, even though sync is off. Enabling it later should be a container-configuration change, not a migration.

- Every stored property has a default value.
- Every relationship is optional (`[Note]? = []`, `Book?`).
- **No `@Attribute(.unique)`** — CloudKit rejects unique constraints.
- Embeddings are stored as `Data` (packed `Float32`), not `[Float]`.

`Note.shortID` is a monotonic `Int` from `UserDefaults`, rendered as `n.11`. Ids are never reused after a delete — a dangling `[[n.07]]` in an exported document, pointing at a *different* note, is worse than one pointing at nothing.

## Keep these pure

These types take plain values and return plain values, with no SwiftData inside. That's what makes them testable, and it's not negotiable:

- **`ReviewSetBuilder`** — `[Note]` + `Date` → the day's set (day-stable, ≤8, ≤2 per book, starred weighted, ≥1 currently-reading)
- **`AffinityEngine`** — vectors + tags → edges
- **`CrossingFinder`** — edges + a date → the day's crossing. Ranked, rotated, never thresholded
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
    NoteWriter               the one path a note takes to exist, `refile`, the
                             one path it takes to change books, and `update`, the
                             one path it takes to change its own words
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
    ReviewSession            where the reader is in the day's review — the day,
                             the ordered ids, the card, the crossing's pair.
                             The reason review reopens where you left it
    RelativeTime             `2 mins ago`, `aug 01`, `0:07`, `7 months apart`
    ConnectionIndex          edges → who connects to whom, both directions
    LinkWriter               the one path an edge takes to exist, and `.linking()`,
                             the one place a recompute is triggered from
  Features/
    Stream/                  StreamView, StreamGrouping, TagIndex
    Capture/                 CaptureBar, CaptureSheet, VoiceCapture, AudioLevels,
                             BookPickerField — the one book picker, shared by the
                             sheet and MoveNoteSheet, where the Inbox is
                             `— no book —` rather than a row — and MoveNoteSheet,
                             which is how a note leaves the Inbox, and
                             EditNoteSheet, the only way a note's own words change
    Review/                  ReviewView, ReviewCard + ShareCard, ReviewSetBuilder,
                             FollowUpSheet — and CrossingFinder, which picks the
                             day's crossing (pure), with CrossingCard +
                             CrossingCardData, the two-note card that draws it
    Search/                  SearchView, SearchQuery, SearchIndex — and
                             NotePicker, the one sheet that makes a link by hand
    Settings/                SettingsView — the reminder, appearance, export,
                             rebuild connections, about
    Books/
  Services/
    NoteEmbedding            NLContextualEmbedding + fallback, and the packing
    AffinityEngine           scoring, mutual k-NN, pinning, suppression. Pure
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
| `-startTab <stream\|books\|review>` | opens on that tab |
| `-openNote <id>` | opens the stream scrolled to `n.<id>` |
| `-captureDraft "<text>"` | fills the capture bar and focuses it — which is also the only way to see `→ full note`, the tap-off scrim and the hidden tab bar |
| `-captureMore 1` | opens the capture sheet the way `→ full note` does, over the stream. With `-captureDraft`, carrying that draft |
| `-bookPicker 1` | opens every book picker's list — the half a closed field never shows. Pair it with `-captureMore`, `-captureSheet` or `-moveNote` |
| `-moveNote <id>` | opens `move to book…` over the stream for `n.<id>` |
| `-editNote <id>` | opens `edit` over the stream for `n.<id>` — a context menu can't be reached from the command line, so this is the only way to see the sheet |
| `-captureBar <recording\|transcribing>` | the recording rows, without a microphone |
| `-captureSheet <quote\|thought\|voice\|scan>` | opens the full sheet over the first book's detail |
| `-scanner 1` | with `-captureSheet scan`, opens the text scanner — **the simulator has no camera**, so what you see is the written fallback |
| `-scanned "<text>"` | the passage a scan produced, without one. With `-scanner` it fills the scanner's preview; without it, the sheet's field |
| `-openBook "<title>"` | opens that book's detail — matched on any part of the title |
| `-addBook 1` | opens the add-book form |
| `-bookSearch "<query>"` | fills the form's search field and runs it |
| `-bookFilter <reading\|queued\|finished>` | opens the library on that chip |
| `-reviewCard <n>` | opens review on the nth card of the day's set |
| `-reviewCrossing 1` | with `-startTab review`, opens review on the crossing card — the ninth, which is otherwise reachable only by swiping past all eight |
| `-reviewEnd 1` | opens review on the closing card |
| `-reviewYesterday 1` | backdates the stored review session by a day, so the next launch reads as a new one — **the only way to see the midnight rollover**, since `simctl` can't move the clock. Read in `open()` rather than `openAtLaunch()`, because it has to run before the resume |
| `-followUp 1` | opens the follow-up composer over the current card |
| `-confirmDelete <book\|note>` | opens the delete confirmation over book detail |
| `-confirmDelete connection` | with `-startTab review`, the disconnect confirmation over the crossing card — `[x] not related` is a button on the ninth card, and the simulator can neither swipe to one nor tap the other. Stands alone: `ReviewView.openAtLaunch` positions itself on the crossing, so `-reviewCrossing 1` isn't needed alongside it |
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
xcrun simctl launch booted com.marginalia.app -startTab review
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
- **Seed ~40 notes**, not 12. A dozen notes produce almost no edges, and a library with no cross-book edge has no crossing to show. `SeedLibrary` has them, and the cross-book tag overlap in them is deliberate — it's what phase 6 tunes against.
- **Pure enums used from a `@Model` need `nonisolated`.** The project defaults to `MainActor` isolation and SwiftData models aren't; `Glyphs`, `BookStatus`, `NoteKind`, `Inbox`, `AudioLevels` and `BookShelf` are marked accordingly.
- **So does anything handing a closure to a system framework**, and this one is a crash rather than a compile error. `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` makes such a closure `@MainActor`; UIKit, AVFoundation, Speech and Vision call them on their own threads; Swift 6 traps. `Theme` is `nonisolated` for exactly this reason — it cost five identical `EXC_BREAKPOINT` crashes before anyone read the report. **Mark the closure `@Sendable` at the call site**, every time: it costs nothing where the compiler had already inferred it and removes a crash where it hadn't. `docs/issues.md` §1 declared this audit complete for two phases while `SFSpeechRecognizer.requestAuthorization` sat three lines below the one line it had checked (§22).
- **Nothing expensive in a `body`.** An `ImageRenderer` inside `ShareCardLink.body` drew a multi-megabyte bitmap for every realized review card on every redraw — a render pass nested inside a render pass — and it is the best candidate for the crash at the end of the set. The same rule caught three cheaper versions of itself in the same pass: `ConnectionIndex.build` read from inside a `ForEach` rebuilds per row, and `ReviewSetBuilder.set` behind a computed property runs over the whole library per redraw. **Build it once above the loop, or hold it in `@State`.** `docs/issues.md` §23.
- **Two siblings in a `VStack` where one of them scrolls is a feedback loop waiting to happen.** Review's foot hid a line on the last card, which grew the paging scroll view by 27pt, which changed every page's height while one was mid-flight. Hide with `.opacity`, never by removing from the layout. The deleted map had the same shape twice over, which is why the rule is written as a rule and not as one bug.
- **Notes are written in exactly one place.** `NoteWriter.save` allocates the id, trims the body, and falls back to the Inbox. A second write path would drift from it — add a caller, not a copy.
- **And edited in exactly one place.** `NoteWriter.update` takes the body, the page and the tags — never the kind, because how a note was captured is a fact about the note and not about the keystrokes. **A changed body clears `embedding` *and* `embeddedAt`, and those are two different bugs, not one.** `embedding` is what `LinkWriter.embed` reads as `hasVector`, so a note that keeps it is skipped by the pass meant to re-embed it; `embeddedAt` is what `.linking()` counts as `pending`, and without clearing it the recompute never fires at all. A changed page or tag clears neither — `AffinityEngine` scores tags separately and never reads a page. `docs/decisions.md` §24.
- **Books likewise go through `BookWriter`**, whether they arrived by search, by barcode, or typed in.
- **And deleted in exactly one place.** `Eraser` exists because `context.delete(note)` is not enough: `NoteEdge.from` and `.to` have no inverse, so SwiftData nils them instead of removing the edge, and an edge with one end missing is a connection that can never be drawn and never be cleaned up. Follow-ups and a book's notes *are* cascaded by the schema; the edges of every note a book takes with it are not.
- **Every delete goes through a confirmation, and the Inbox refuses.** `Eraser.delete(book:)` returns `false` for it, for the same reason `BookWriter.apply` won't restatus it — it's found by status, and deleting it would take every quick capture with it while the next one silently built a second drawer.
- **The Inbox can't be edited.** It's found by status and it's where every unfiled capture falls back to, so `BookWriter.apply` refuses to change its status and book detail doesn't offer `edit` on it. An Inbox marked `reading` would quietly stop being one and the next quick capture would build a second.
- **A lookup result fills the form; it never saves straight through.** Open Library gets authors and page counts wrong often enough that the last word has to belong to the reader — and it holds a separate work record per translation, so `BookLookup` collapses repeats of the same title and author.
- **A transcript is never saved unseen, and neither is a scan.** On-device recognition is wrong often enough that it lands in an editable field, both in the bar and in the sheet; OCR off a printed page is the same bet and lands in the same kind of field. Editing either leaves the note a `voice` or a `scan`: how it was captured is a fact about the note, not about the keystrokes.
- **A scan is drawn as a passage and marked as a scan.** `NoteKind.isPassage` is what the quote rule keys on, and it's true for `.quote` and `.scan` — a scan is somebody else's words off a page. The marker still says `[s]`, by the rule above. Never test `kind == .quote` to decide how a body is drawn.
- **The page number is typed, never inferred.** A folio or a running head is text like any other in the frame, and `ScannedPassage` deliberately doesn't hunt for one — a page number that's wrong one time in five is worse than a field the reader fills in.
- **A note has a page; a book does not have a bookmark.** `Book.currentPage`, `Book.progress` and the progress bar came out in phase 11 — the only way to move that number was four taps through `edit`, so it was always stale, and deriving it from a note's page would be the app's first inference about the reader. `Book.pageCount` stays: it's how long the book is, which is a fact, and it reads as `499pp` in book detail's byline. `docs/decisions.md` §17.
- **The day's review set is built once a day and stored**, in `ReviewSession` (`UserDefaults`, keyed on `ReviewSetBuilder.daySeed`), not in `@State`. Rebuilding it every redraw would reshuffle the deck the moment the reader starred something, because a star is one of the things the set is scored on — and holding it in `@State` was worse than it looked: `RootView` is a `switch tab`, so leaving review destroys it, **and the rebuild is not the same set.** `ReviewSetBuilder` scores on `lastSurfacedAt`, which paging past a card writes, so every card actually read scores ~0 on the way back and falls out of the eight. The more of the set you read, the less of it came back. The set has to be remembered, not recomputed: `docs/decisions.md` §23.
- **Don't name a property `set`.** `private var counter: String { set.count … }` fails to parse — Swift reads `set` at the start of a property body as the setter keyword.
- **`Spacer` collapses inside a `ScrollView`.** Content there sizes to itself, so vertical centering is a `.frame(minHeight:)` against a `GeometryReader`, which is how the review card does it.
- **A cancelled `.task(id:)` still finishes what it was awaiting.** `Task.detached` is not cancelled with its awaiter, so the superseded pass resumes when the detached work completes and writes its result — after the new one. On the map it drew one book's nine notes at the coordinates they'd held in the whole-library graph: a clump in the corner of an empty screen, under a perfectly correct header. **Guard on `Task.isCancelled` before assigning**, in any `.task(id:)` that hands work to a detached task. The screen this was found on is deleted; the rule is not about that screen.
- **`Synchronization.Mutex` can't be captured in a closure** — it's non-copyable. Where an audio callback has to hand a value back, `OSAllocatedUnfairLock` is what works (see `VoiceCapture.peak`).

## Don't

- Don't add a dependency without asking. The app has zero.
- Don't introduce SF Symbols, cover images, shadows, gradients, or a second typeface.
- Don't draw automatic and manual links differently. That was decided against deliberately.
- Don't enable CloudKit until the paid Apple Developer account is confirmed — it will fail to provision.
- Don't reformat the archived prototype in `docs/prototype/`. It's a reference artifact.
- Don't re-litigate settled decisions. `docs/decisions.md` records what was chosen and why.
