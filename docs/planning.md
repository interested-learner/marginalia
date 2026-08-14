# Planning

Where the project stands and what happens next. **Read this first in a new session**, then `CLAUDE.md` for the rules.

Last updated 2026-08-13, after phase 3.

---

## State

The app **builds clean, runs on the simulator in both appearances, and passes 127 tests.** Every screen reads from SwiftData, and the app now **writes**: `[+]` in the stream bar files a thought into the Inbox with a fresh id, and the full sheet files one against a book with a page and tags.

**Still inert:** the review actions, and everything on the map except the preview panel.

History is one commit per phase on `main` — `git log --oneline` is the authority, not this file. Remote: `interested-learner/marginalia` (public). `gh` is **not** installed on this machine.

### Phases

| | Phase | State |
|---|---|---|
| 0 | Documentation | **done** |
| 1 | Scaffold + design system, four-tab shell | **done** |
| 2 | Model + Stream | **done** |
| 3 | Capture — text, then voice | **done** (voice needs a device) |
| 4 | Books — list, detail, add by search and ISBN | **next** |
| 5 | Review — paged cards, `ReviewSetBuilder`, stars, follow-ups | |
| 6 | Linking — embeddings + `AffinityEngine` | gates on a human reading output |
| 7 | Map — `GraphLayout`, real graph | |
| 8 | Search, export, settings, notifications | |
| 9 | Camera OCR capture | |
| 10 | Polish, app icon, device install | |

Full detail for every phase is in `docs/specs/2026-08-13-marginalia-design.md`. The reasoning behind the choices is in `docs/decisions.md` — **don't re-litigate those.**

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

### Standing until phase 4

- **Tapping a book opens the capture sheet against it.** That's phase 3's entry point to the full sheet, not the final one — phase 4 gives each book a detail screen and moves `[+] add note` there. `BooksView` says so at the top.
- **The type selector offers three types, not four.** `[s] scan` opens the camera; it arrives with the scanner in phase 9 rather than as a segment that does nothing. See `docs/design-system.md` §Segmented control for what happens to the row when it does.

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

---

## Next: phase 4 — books

1. **Book detail** — the header (title, author, note count · status · progress) over that book's notes, using the margin the stream uses. `[+] add note` opens `CaptureSheet(book:)`, which already exists, and **replaces the row tap that opens it today**.
2. **Adding a book** — Open Library `/search.json` by title, then `/isbn/{isbn}.json` behind a VisionKit barcode scan. Manual entry always available; lookup failure is routine, not exceptional.
3. **Filter the library** by reading / finished / queued, with the same chip row the stream uses.

`BookLookup` parses against captured fixtures, including missing-author and missing-page-count responses. No API key, no attribution requirement.

---

## Open questions for Nathaniel

None of these block phase 4.

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
