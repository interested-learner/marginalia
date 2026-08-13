# CLAUDE.md

Working context for Claude Code in this repository. Read this before touching any file.

## What this is

**marginalia** — a native iOS app for notes taken from books. Three tabs:

- **stream** — every note across every book, newest first, filterable by tag. A persistent capture bar sits at the bottom for text or voice.
- **books** — the library, and each book's notes.
- **review** — a daily set of ~8 older notes, one per screen, swiped through. Resurfacing what you already thought.

Notes are zettel-style: they carry ids (`n.11`), link to each other (`n.01 → n.07`), and accumulate threaded follow-ups. Quick captures with no book land in an **Inbox**.

Built from a Claude Design prototype. The prototype is archived at `docs/prototype/Marginalia.dc.html` and is the visual source of truth — open it in a browser to check any layout question.

## Stack

Swift 6 · SwiftUI · SwiftData · deployment target **iOS 18.0** · Xcode 26.6.

## Design rules — these are not suggestions

The look comes from the **OpenCode design system**. It is severe on purpose, and it falls apart if any one of these slips. Full reference: `docs/design-system.md`.

1. **No raw color literals in views.** Every color comes from `Theme`. Not `Color.gray`, not `#f8f7f7`, not `.secondary`. If a color you need isn't in `Theme`, add it there with both appearances defined, then use it. This rule is the only reason dark mode works.
2. **No shadows. Anywhere.** Not on cards, sheets, buttons, or bars. Separation is done with hairlines (`Theme.hairline`, 1px) and surface tint (`Theme.surfaceSoft`) — nothing else. `--elevation-1` in the source system is a hairline, not a shadow.
3. **ASCII markers, not SF Symbols.** `[+] [x] [-] [~] [=] [↻] [q] [t] [v] [s]` and the arrows `→ ←`. Use the named cases in `Glyphs`, never a literal. There are no icons in this app.
4. **Radius 4px on interactive elements only.** Buttons, inputs, chips, quote blocks. Everything else is square. Never a pill, never a circle, never 26pt iOS-style card corners.
5. **One font.** JetBrains Mono at every size and weight — body, headings, numbers, buttons. There is no sans face and no italic in this system.
6. **No cover art, no images, no color-coding.** Books are title + author + status marker + note count. The absence of imagery is the identity; a row of cover thumbnails would make this a different app.
7. **Lowercase chrome.** Tab labels, the wordmark, and placeholder text are lowercase (`stream`, `books`, `add a thought…`). Screen titles are sentence case (`Daily review`, `Books`).

Colors, condensed — but read `Theme.swift` for the authoritative list:

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

`danger` is the one saturated color in the app. It is used for the recording dot and destructive confirmations. Nothing else.

## Data model rules

Every `@Model` must stay **CloudKit-compatible**, even though sync is currently off. Enabling it later should be a container-configuration change, not a migration.

- Every stored property has a default value.
- Every relationship is optional (`[Note]? = []`, `Book?`).
- **No `@Attribute(.unique)`** — CloudKit rejects unique constraints.
- No `@Attribute(.allowsCloudEncryption)` unless deliberately chosen.

`Note.shortID` is a monotonic `Int` from `UserDefaults`, rendered as `n.11`. Ids are never reused after a delete.

## File map

```
Marginalia/
  MarginaliaApp.swift        @main, ModelContainer, root TabView
  Design/
    Theme.swift              every hex, light + dark. The only place colors live
    Typography.swift         font registration + type scale
    Glyphs.swift             the ASCII vocabulary, named
    Components/              shared views — see docs/design-system.md
  Model/                     Book, Note, FollowUp, container config + seed
  Features/
    Stream/  Capture/  Books/  Review/  Search/  Settings/
  Services/
    SpeechTranscription      SFSpeechRecognizer, on-device only
    TextScanner              VisionKit → passage text
    BarcodeScanner           VisionKit → ISBN
    BookLookup               Open Library
    NotificationScheduler    one per day, 7 scheduled ahead
    MarkdownExport
  Resources/Fonts/           JetBrains Mono (SIL OFL)
MarginaliaTests/
```

`Marginalia.xcodeproj` uses **synchronized file groups** (`PBXFileSystemSynchronizedRootGroup`, Xcode 16+). New `.swift` files under `Marginalia/` are picked up automatically — **do not hand-edit the project file to add sources.**

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
```

Tests use **Swift Testing** (`@Test`, `#expect`), not XCTest.

## Working notes

- **Verify visually, not by reasoning.** After a UI change, screenshot the simulator in *both* appearances and actually look at the images. Dark mode regressions are invisible in code review and obvious in a screenshot.
- **`ReviewSetBuilder` is pure.** It takes `[Note]` and a `Date` and returns the day's set. Keep SwiftData out of it — that's what makes it testable, and its rules (day-stable, ≤8, ≤2 per book, starred weighted, at least one currently-reading) are all covered by tests.
- **Permissions are requested at first use**, never at launch. Microphone, speech recognition, and camera each prompt at the moment the feature is invoked.
- **The simulator cannot test** microphone, transcription, camera OCR, or barcode scanning. Those need the device. Don't claim they work from a simulator run.
- **Open Library needs no API key** and imposes no attribution requirement. Manual book entry must always remain available as a fallback — treat lookup failure as routine, not exceptional.

## Don't

- Don't add a dependency without asking. The app currently has zero.
- Don't introduce SF Symbols, cover images, shadows, gradients, or a second typeface.
- Don't enable CloudKit until the paid Apple Developer account is confirmed — it will fail to provision.
- Don't reformat or "clean up" the archived prototype in `docs/prototype/`. It's a reference artifact.
- Don't re-litigate settled decisions. `docs/decisions.md` records what was chosen and why.
