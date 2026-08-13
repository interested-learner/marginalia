# Planning

Where the project stands and what happens next. **Read this first in a new session**, then `CLAUDE.md` for the rules.

Last updated 2026-08-13, after phase 1.

---

## State

The app **builds clean, runs on the simulator in both appearances, and passes 6 tests.** Everything on screen is static — there is no data model yet, nothing saves, and the map's node positions are hand-placed.

```
main
  3967882  docs
  be05845  automatic linking, map tab, visual revisions
  127d459  phase 1: scaffold and design system
```

Remote: `interested-learner/marginalia` (public). `gh` is **not** installed on this machine.

### Phases

| | Phase | State |
|---|---|---|
| 0 | Documentation | **done** |
| 1 | Scaffold + design system, four-tab shell | **done** |
| 2 | Model + Stream | **next** |
| 3 | Capture — text, then voice | |
| 4 | Books — list, detail, add by search and ISBN | |
| 5 | Review — paged cards, `ReviewSetBuilder`, stars, follow-ups | |
| 6 | Linking — embeddings + `AffinityEngine` | gates on a human reading output |
| 7 | Map — `GraphLayout`, real graph | |
| 8 | Search, export, settings, notifications | |
| 9 | Camera OCR capture | |
| 10 | Polish, app icon, device install | |

Full detail for every phase is in `docs/specs/2026-08-13-marginalia-design.md`. The reasoning behind the choices is in `docs/decisions.md` — **don't re-litigate those.**

---

## Next: phase 2 — model + stream

Replace the static content with SwiftData, keeping the views as they are.

1. **`Model/`** — `Book`, `Note`, `FollowUp`, `NoteEdge` exactly as specced in `docs/specs/`. Every property defaulted, every relationship optional, no `@Attribute(.unique)`; those are CloudKit's constraints and adopting them now is what makes sync a configuration change later instead of a migration.
2. **`ModelContainer+Marginalia.swift`** — container config, the Inbox book created on first launch, and seed data.
3. **Seed ~40 notes** across the prototype's six books, not the prototype's 12. A twelve-note map proves nothing in phase 7, and it's much cheaper to write good seed content now than to backfill it later. They need to be *real* notes with genuine conceptual overlap, because phase 6 tunes the affinity weights against them.
4. **`shortID`** — monotonic `Int` in `UserDefaults`. Never reused after a delete: a dangling `→ n.07` pointing at a *different* note is worse than one pointing at nothing.
5. **Stream reads from SwiftData** — date grouping (`today · wed aug 13` / `yesterday` / `earlier`), tag chips filtering for real, and the `marginalia://note/…` handler registered so a connection navigates to its note.

### Scaffolding phase 2 must remove

Phase 1 deliberately left temporary things. Don't leave them in place:

- **`Features/Stream/SampleData.swift`** — delete it entirely once the model exists.
- **`NoteRowData` / `BookRowData`** in `Design/Components/Rows.swift` — these stay, but should be built from the models rather than hand-written. Keeping views ignorant of SwiftData is deliberate and worth preserving.
- **`marginalia://note/…` links** in `NoteRow.sourceLine` are rendered but nothing handles them. Register an `.onOpenURL` or `openURL` handler.
- **`MapView`'s hand-placed positions and edges** — these survive until phase 7. Fine to leave.
- **`ReviewView`** pages through sample notes with non-functioning actions — phase 5's problem, fine to leave.

---

## Open questions for Nathaniel

Neither blocks phase 2.

1. **Is the dark palette right?** The prototype only ever specified light; every dark value is derived. Screenshots are in `~/Desktop/marginalia-phase1/`.
2. **Is the body leading comfortable?** `Typography.bodyLeading` is 4pt on 15pt text (~1.6). Tightened once already from 5. Hard to judge from code.
3. **Is the Apple Developer account paid?** Needed before CloudKit sync or notifications can be provisioned. Phase 8 hits this.
4. **Is "marginalia" available on the App Store?** Likely contested. Doesn't block anything — the bundle id can change — but worth knowing before phase 10.

---

## Things worth knowing before you touch the build

Learned the hard way in phase 1.

- **The project file needs no editing to add sources.** `PBXFileSystemSynchronizedRootGroup` means folders are referenced, not files. Drop a `.swift` file anywhere under `Marginalia/` and it compiles. If you find yourself editing `project.pbxproj`, stop — you almost certainly don't need to.
- **`-startTab <stream|books|map|review>`** launches straight to a tab. The simulator can't be tapped from the command line, so this is how you screenshot anything that isn't stream:
  ```bash
  xcrun simctl launch booted com.marginalia.app -startTab map
  ```
- **Run the tests, don't assume they pass.** `TEST_HOST` was malformed in phase 1 and the test bundle silently failed to link while `build` still reported success. `build test` is the command that tells the truth.
- **A `TEST FAILED` isn't always your code.** Repeated `simctl` launches leave the simulator wedged, and it surfaces as `Mach error -308 (ipc/mig) server died` / `Failed to install or launch the test runner`. Read the error before you go debugging: if it names the launcher rather than an assertion, reset and re-run.
  ```bash
  xcrun simctl shutdown all && xcrun simctl boot "iPhone 17"
  ```
- **Screenshot both appearances and actually look at them.** Two real layout bugs in phase 1 — the margin rule not meeting the row dividers, and source lines wrapping away from their links — were invisible in code and obvious in an image.
- **Info.plist lives at `Support/Info.plist`**, outside the synchronized group, so it isn't copied in as a resource.
- **Fonts are committed** to `Marginalia/Resources/Fonts/` under the SIL OFL, registered via `UIAppFonts`.

---

## Map of the docs

| File | What it's for |
|---|---|
| `CLAUDE.md` | The rules. Design constraints, model constraints, commands, what not to do |
| `docs/planning.md` | This file — state and what's next |
| `docs/specs/2026-08-13-marginalia-design.md` | What the app does. Authority on behavior |
| `docs/design-system.md` | Every token and component spec. Authority on visual values |
| `docs/decisions.md` | Why things were chosen. 12 entries. Settled — don't reopen without a changed premise |
| `docs/prototype/` | The original Claude Design prototype. Authority on look, overridden by the spec on behavior |
| `README.md` | Human-facing |
