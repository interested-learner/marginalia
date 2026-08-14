# Planning

Where the project stands and what happens next. **Read this first in a new session**, then `CLAUDE.md` for the rules.

Last updated 2026-08-13, after phase 2.

---

## State

The app **builds clean, runs on the simulator in both appearances, and passes 72 tests.** Every screen reads from SwiftData now. A fresh install seeds six books and forty notes, the stream groups and filters for real, and a `→ n.20` navigates to its note.

**Nothing writes yet.** The capture bar, the review actions, and everything on the map except the preview panel are still inert.

History is one commit per phase on `main` — `git log --oneline` is the authority, not this file. Remote: `interested-learner/marginalia` (public). `gh` is **not** installed on this machine.

### Phases

| | Phase | State |
|---|---|---|
| 0 | Documentation | **done** |
| 1 | Scaffold + design system, four-tab shell | **done** |
| 2 | Model + Stream | **done** |
| 3 | Capture — text, then voice | **next** |
| 4 | Books — list, detail, add by search and ISBN | |
| 5 | Review — paged cards, `ReviewSetBuilder`, stars, follow-ups | |
| 6 | Linking — embeddings + `AffinityEngine` | gates on a human reading output |
| 7 | Map — `GraphLayout`, real graph | |
| 8 | Search, export, settings, notifications | |
| 9 | Camera OCR capture | |
| 10 | Polish, app icon, device install | |

Full detail for every phase is in `docs/specs/2026-08-13-marginalia-design.md`. The reasoning behind the choices is in `docs/decisions.md` — **don't re-litigate those.**

---

## What phase 2 built

- **`Model/`** — `Book`, `Note`, `FollowUp`, `NoteEdge`, all CloudKit-shaped: every property defaulted, every relationship optional, no unique constraints. `statusRaw`/`kindRaw` are strings with typed accessors that fall back rather than crash.
- **`Library`** — schema, container, and a `prepare` that runs every launch: seeds an empty store, then raises the id counter past everything already in it.
- **`ShortIDCounter`** — monotonic, in `UserDefaults`. Deleting the newest note does not free its id.
- **`SeedLibrary`** — 40 notes across five books plus the Inbox, dated relative to first launch so the stream opens with all three date headers. **The cross-book tag overlap is deliberate**: `attention`, `error`, `quality`, `memory` and `systems` each run through three or four authors, and that's the signal phase 6 tunes against. 16 seeded edges are `isPinned`, so the first recompute won't prune them.
- **Stream** — real feed, date grouping, chips derived from the notes themselves, and `marginalia://note/…` handled so a connection scrolls to its note (clearing the tag filter first, or the link would land on an empty feed).
- **Books, review, map** — all reading from the store. Book detail, the real review set, and the real graph are phases 4, 5 and 7.

### Scaffolding phase 2 removed

`Features/Stream/SampleData.swift` is gone. `NoteRowData`/`BookRowData` stayed and are now built in `Model/RowMapping.swift` — that's the one file aware of both the models and the design system, and it should stay the only one.

### Still standing, deliberately

- **`MapView`'s hand-placed positions and lines** — phase 7. Only the preview panel is real.
- **`ReviewView` shows the newest eight**, not a day-stable set, and its actions do nothing — phase 5.
- **The capture bar doesn't save** — phase 3.

---

## Next: phase 3 — capture

1. **Text from the stream bar** — `[+]` files a thought into the Inbox with a fresh `shortID` from `ShortIDCounter`. Two taps from launch to a saved note is the bar to clear.
2. **`SpeechTranscription`** — `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`, an `AVAudioEngine` tap driving the waveform. Permissions at first use, never at launch.
3. **The voice flow exactly as the prototype has it**: `[●]` → live waveform and elapsed timer → `■ stop` → `[↻] transcribing…` → text lands in the field, **editable before saving**.
4. **The full capture sheet** from a book — type selector, book picker, body, page, tags. Phase 4 needs it too.

**The simulator cannot test microphone or transcription.** Those need the device; don't claim they work from a simulator run.

---

## Open questions for Nathaniel

None of these block phase 3.

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
- **`-startTab <stream|books|map|review>`** and **`-openNote <shortID>`** launch straight to a tab, and to a note in the stream. The simulator can't be tapped from the command line, so this is how you screenshot anything else:
  ```bash
  xcrun simctl launch booted com.marginalia.app -startTab map
  xcrun simctl launch booted com.marginalia.app -openNote 20
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
| `docs/specs/2026-08-13-marginalia-design.md` | What the app does. Authority on behavior |
| `docs/design-system.md` | Every token and component spec. Authority on visual values |
| `docs/decisions.md` | Why things were chosen. 13 entries. Settled — don't reopen without a changed premise |
| `docs/prototype/` | The original Claude Design prototype. Authority on look, overridden by the spec on behavior |
| `README.md` | Human-facing |
