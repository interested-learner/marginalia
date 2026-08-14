# CLAUDE.md

Working context for Claude Code in this repository. Read this before touching any file.

> **Starting a session?** Read [`docs/planning.md`](docs/planning.md) first — it says what's built, what's next, and what's temporary scaffolding waiting to be replaced.
>
> **Phase 3 is complete.** The app builds, runs in both appearances, and passes its tests. Every screen reads from SwiftData and the app now **writes**: the stream bar files a thought or a voice note into the Inbox, and the full sheet files one against a book. Phase 4 is books — detail, search, ISBN.

## What this is

**marginalia** — a native iOS app for notes taken from books. Four tabs:

- **stream** — every note across every book, newest first, filterable by tag. A persistent capture bar sits at the bottom for text or voice.
- **books** — the library, and each book's notes.
- **map** — the whole library as a graph. Notes are nodes, books are hubs, edges are connections the app found on its own.
- **review** — a daily set of ~8 older notes, one per screen, swiped through. Resurfacing what you already thought.

Notes are zettel-style: they carry ids (`n.11`), connect to each other, and accumulate threaded follow-ups. Quick captures with no book land in an **Inbox**.

**Nobody creates links by hand.** The app connects notes by meaning as they're written — see *Linking* below. Manual linking exists only as override.

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
9. **Support Dynamic Type.** Every size in `Typography` scales with the reader's setting. Never a hardcoded `.system(size:)`.

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
- `AffinityEngine` scores pairs `0.8 · cosine + 0.2 · tagOverlap`. Same-book is deliberately **not** boosted; books are already hub nodes and rewarding it again just clumps each book into a ball.
- Three constraints keep the graph from becoming a hairball: a **floor** of `score ≥ 0.55`, **mutual k-NN** (each note in the other's top 8), and a **degree cap** of 6.
- **Automatic and manual links render identically.** `isPinned` and `isSuppressed` on `NoteEdge` exist only to make override work — never surface them in the UI, never draw a manual link differently.
- **Backlinks are always shown.** Edges store direction but display both ways, or half of every note's connections are invisible.

## Data model rules

Every `@Model` must stay **CloudKit-compatible**, even though sync is off. Enabling it later should be a container-configuration change, not a migration.

- Every stored property has a default value.
- Every relationship is optional (`[Note]? = []`, `Book?`).
- **No `@Attribute(.unique)`** — CloudKit rejects unique constraints.
- Embeddings are stored as `Data` (packed `Float32`), not `[Float]`.

`Note.shortID` is a monotonic `Int` from `UserDefaults`, rendered as `n.11`. Ids are never reused after a delete — a dangling `→ n.07` pointing at a *different* note is worse than one pointing at nothing.

## Keep these pure

Three types take plain values and return plain values, with no SwiftData inside. That's what makes them testable, and it's not negotiable:

- **`ReviewSetBuilder`** — `[Note]` + `Date` → the day's set (day-stable, ≤8, ≤2 per book, starred weighted, ≥1 currently-reading)
- **`AffinityEngine`** — vectors + tags → edges
- **`GraphLayout`** — nodes + edges → positions

## File map

```
Marginalia/
  MarginaliaApp.swift        @main, ModelContainer, root TabView
  Design/
    Theme.swift              every hex, light + dark. The only place colors live
    Typography.swift         font registration + Dynamic Type scale
    Glyphs.swift             the ASCII vocabulary, named
    Components/              shared views — see docs/design-system.md
  Model/
    Book  Note  FollowUp  NoteEdge      the four @Model types
    Library                  schema, container, first-launch bootstrap
    SeedLibrary              the 40 seed notes, as plain values
    ShortIDCounter           monotonic n.11 ids, never reused
    CaptureDraft             what's typed → what a Note stores. Pure
    NoteWriter               the one path a note takes to exist
    BookShelf                the order the library reads in. Pure
    RowMapping               models → NoteRowData / BookRowData. The only
                             file that knows about both sides
    RelativeTime             `2 mins ago`, `aug 01`, `0:07`
    ConnectionIndex          edges → who connects to whom, both directions
  Features/
    Stream/                  StreamView, StreamGrouping, TagIndex
    Capture/                 CaptureBar, CaptureSheet, VoiceCapture, AudioLevels
    Books/  Map/  Review/  Search/  Settings/
  Services/
    NoteEmbedding            NLContextualEmbedding + fallback
    AffinityEngine           scoring, mutual k-NN, pinning, suppression
    GraphLayout              force-directed, pure, background actor
    SpeechTranscription      SFSpeechRecognizer, on-device only
    TextScanner              VisionKit → passage text
    BarcodeScanner           VisionKit → ISBN
    BookLookup               Open Library
    NotificationScheduler    one per day, 7 scheduled ahead
    MarkdownExport
  Resources/Fonts/           JetBrains Mono (SIL OFL)
MarginaliaTests/
```

`Marginalia.xcodeproj` uses **synchronized file groups** (`PBXFileSystemSynchronizedRootGroup`, Xcode 16+). New `.swift` files under `Marginalia/` are picked up automatically — **do not hand-edit the project file to add sources.** If you're about to touch `project.pbxproj`, you almost certainly don't need to.

`Support/Info.plist` sits outside the synchronized group deliberately, so it isn't copied in as a resource.

**Views never see SwiftData.** They take `NoteRowData` / `BookRowData`, and `Model/RowMapping.swift` is the only file that knows about both sides. That separation is what let the whole design system be built and judged before the model existed, and it's worth keeping.

**Launch arguments are not scaffolding to remove.** The simulator can't be tapped from the command line, so they're the only way to screenshot anything but the top of the stream:

| | |
|---|---|
| `-startTab <stream\|books\|map\|review>` | opens on that tab |
| `-openNote <id>` | opens the stream scrolled to `n.<id>` |
| `-captureDraft "<text>"` | fills the capture bar and focuses it |
| `-captureBar <recording\|transcribing>` | the recording rows, without a microphone |
| `-captureSheet <quote\|thought\|voice>` | opens the full sheet on the first book |

## Commands

```bash
# build + test
xcodebuild -scheme Marginalia -destination 'platform=iOS Simulator,name=iPhone 17' build test

# run in the simulator
xcrun simctl boot "iPhone 17"
xcrun simctl install booted "$(xcodebuild -scheme Marginalia -showBuildSettings \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  | awk -F' = ' '/ BUILT_PRODUCTS_DIR/{d=$2} / FULL_PRODUCT_NAME/{n=$2} END{print d"/"n}')"
xcrun simctl launch booted com.marginalia.app

# check both appearances — do this after any UI change
xcrun simctl ui booted appearance dark      # or: light
xcrun simctl io booted screenshot /tmp/marginalia.png

# the simulator can't be tapped from the command line, so to screenshot
# any tab that isn't stream:
xcrun simctl launch booted com.marginalia.app -startTab map
```

Tests use **Swift Testing** (`@Test`, `#expect`), not XCTest.

**Run `build test`, not `build`.** A broken test target can fail to link while `build` alone still reports success — that happened in phase 1 and went unnoticed until the suite was actually run.

## Working notes

- **Verify visually, not by reasoning.** After a UI change, screenshot the simulator in *both* appearances and actually look at the images. Dark mode regressions are invisible in code review and obvious in a screenshot.
- **Tests can't tell you whether the links are any good.** They prove `AffinityEngine` respects its floor, its k-NN rule, and its degree cap. Whether the connections are *defensible* needs a human reading real output — dump each seed note's top 5 and judge them before building the map on top.
- **Permissions are requested at first use**, never at launch. Microphone, speech recognition, and camera each prompt at the moment the feature is invoked.
- **The simulator cannot test** microphone, transcription, camera OCR, or barcode scanning. Those need the device. Don't claim they work from a simulator run.
- **Open Library needs no API key** and imposes no attribution requirement. Manual book entry must always remain available — treat lookup failure as routine, not exceptional.
- **Seed ~40 notes**, not 12. A sparse map proves nothing about whether the layout works. `SeedLibrary` has them, and the cross-book tag overlap in them is deliberate — it's what phase 6 tunes against.
- **Pure enums used from a `@Model` need `nonisolated`.** The project defaults to `MainActor` isolation and SwiftData models aren't; `Glyphs`, `BookStatus`, `NoteKind`, `Inbox`, `AudioLevels` and `BookShelf` are marked accordingly.
- **Notes are written in exactly one place.** `NoteWriter.save` allocates the id, trims the body, and falls back to the Inbox. A second write path would drift from it — add a caller, not a copy.
- **A transcript is never saved unseen.** On-device recognition is wrong often enough that it lands in an editable field, both in the bar and in the sheet. Editing it leaves the note `[v] voice`: how it was captured is a fact about the note, not about the keystrokes.
- **`Synchronization.Mutex` can't be captured in a closure** — it's non-copyable. Where an audio callback has to hand a value back, `OSAllocatedUnfairLock` is what works (see `VoiceCapture.peak`).

## Don't

- Don't add a dependency without asking. The app has zero.
- Don't introduce SF Symbols, cover images, shadows, gradients, or a second typeface.
- Don't draw automatic and manual links differently. That was decided against deliberately.
- Don't enable CloudKit until the paid Apple Developer account is confirmed — it will fail to provision.
- Don't reformat the archived prototype in `docs/prototype/`. It's a reference artifact.
- Don't re-litigate settled decisions. `docs/decisions.md` records what was chosen and why.
