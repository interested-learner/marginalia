# Issues

What's currently wrong, fragile, or worth changing — and for each one, whether it's **proven** or **suspected**. `docs/planning.md` says what's built and what's next; this file says what's broken and what it will cost to fix.

Last updated 2026-08-14, after phase 6.

---

## Fixed today

### 0. The issues pass — 7, 8, 9, 13, and half of 2 and 5

Six of the thirteen entries below are closed. Each is struck through in its own section and in the table at the foot; what follows is what changed and how it was checked.

**7 — the `fatalError` is gone.** `MarginaliaApp` now holds `ModelContainer?`. Both the real store and the in-memory fallback still get tried in that order; when neither opens, the app draws `StoreFailureView` instead of dying — the wordmark, `[x] the library won't open`, a sentence saying the notes have not been deleted, and the store's own error under a hairline so a bug report has something in it. Nothing on the screen offers to retry: that would mean reopening a container from inside a screen that exists because it failed. **Seen** in both appearances via `-storeFailure 1`.

**8 — deleting works, for all three things.** New `Model/Eraser.swift`, the mirror of `NoteWriter` / `BookWriter` and there for a reason that isn't tidiness: `NoteEdge.from` and `.to` have no inverse, so `context.delete(note)` leaves SwiftData nilling one end of an edge instead of removing it, and an edge with one end missing can never be drawn and never be swept. `Eraser` prunes those (and any already-dangling ones it passes) before deleting. A book's notes and a note's thread are cascaded by the schema; the edges of every note a book takes with it are not. **The Inbox is refused**, like `BookWriter.apply` refuses to restatus it.

The way in: `delete` beside `edit` on book detail, and a long press on a stream or book-detail row for a note or one follow-up. **Not on the review card** — review is a reading surface. Every path opens `ConfirmSheet`, the app's own half-height sheet rather than `confirmationDialog`, whose pill buttons and 26pt radius would be the only iOS-looking thing in the app. The wording lives on `Erasure` in one place, so a book says how many notes go with it and a note says its id is retired rather than reused. **Seen** in both appearances via `-confirmDelete book|note`.

**9 — a duplicate book is named once, then allowed.** `BookShelf.duplicate` is pure and matches on normalized title, plus author only when both sides have one — Open Library returns titles with no author often enough that insisting on both would miss the case the check exists for. The first `add book` reports `you already have Meditations · Marcus Aurelius` and relabels itself `add it anyway`; the second one adds it. Refusing outright would overrule a reader with a legitimate second copy, and a re-read or a different translation is legitimate.

**13 — the empty states have now actually been seen.** `-tinyLibrary <n>` seeds `n` notes instead of forty. The first attempt at this was wrong in an instructive way: taking the first `n` notes takes them all from one book, `ReviewSetBuilder` allows two cards per book, so *every* value of `n` landed on the empty state. It spreads across books one at a time now. `2` gives review's empty state; `4` gives a full set with nothing left over, which is the only way to reach an exhausted `[↻] keep going`. Both screenshotted; neither had ever been drawn before.

**2 — the CLI has its own DerivedData.** `-derivedDataPath .build` is now in `CLAUDE.md`'s commands rather than a suggestion in this file. `.build/` was already in `.gitignore`. Nothing hung in this session's ten-odd builds.

**5 — Release has now been run.** Built at `-O`, installed, and launched onto all four tabs. No new crash report; `~/Library/Logs/DiagnosticReports/` is unchanged since 09:48, before the session. Simulator only — see 6.

The suite is **226 tests**, up from 210: `EraserTests` (edge pruning, cascades, the refused Inbox, a swept dangling edge, and what the confirmation says), plus duplicate detection in `BookShelfTests` and the tiny seed in `LibraryStoreTests`.

### 1. The app kept crashing — `Theme.pair`, and it was ours

**Symptom.** The app dies at random with no error message, usually while a screen is drawing, and never in the same place twice. Xcode reports a crash with no useful line highlighted.

**This is proven, not suspected.** Six crash reports sit in `~/Library/Logs/DiagnosticReports/`. **Five of the six are byte-for-byte identical** — the sixth is just a failing test trapping. Every one:

```
Exception: EXC_BREAKPOINT (SIGTRAP)
Thread:    com.apple.SwiftUI.AsyncRenderer
  libdispatch          _dispatch_assert_queue_fail
  libswift_Concurrency swift_task_isCurrentExecutorWithFlags(...)
  Marginalia           closure #1 in static Theme.pair(light:lightAlpha:dark:darkAlpha:)
  UIKitCore            -[UIDynamicProviderColor _resolvedColorWithTraitCollection:]
  SwiftUICore          ColorProvider._apply(color:to:)
```

**Cause.** Every color in the app is a dynamic `UIColor` built in `Theme.pair`:

```swift
Color(uiColor: UIColor { traits in ... })      // ← this closure
```

UIKit stores that closure and calls it back **on whatever thread is resolving the color.** For SwiftUI that is regularly `com.apple.SwiftUI.AsyncRenderer`, not main. The project builds with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` under Swift 6, so the closure was inferred `@MainActor` — and Swift 6 traps on entry to a main-actor closure from another thread.

So: **any color, resolved from SwiftUI's async renderer, was a hard crash.** It looked random because SwiftUI only takes the async render path some of the time, and it never pointed at the code that changed, because the failing frame is a color literal that has been correct since phase 1.

**Fix.** One word, and it's the idiom the project already uses everywhere else:

```swift
nonisolated enum Theme { ... }
```

`Glyphs`, `BookStatus`, `NoteKind`, `Inbox`, `AudioLevels`, `BookShelf`, `SeedLibrary` and `ReviewSetBuilder` were all already marked. `Theme` was the one that wasn't, and the only one handing a closure to a system framework.

**Guard.** `MarginaliaTests/ThemeIsolationTests.swift` resolves colors from a detached task on purpose. Before the fix it reproduced the crash exactly — the runner died with *"Restarting after unexpected exit, crash, or test timeout"*. After it, 210 tests pass. If `Theme` ever loses `nonisolated`, that file stops compiling.

**Reading a crash report yourself**, next time:

```bash
ls -t ~/Library/Logs/DiagnosticReports/Marginalia-*.ips | head -1
```

They're JSON with a one-line header. `faultingThread` indexes into `threads`; any frame whose image is `Marginalia` is ours.

---

## Open — environment

These are why builds fail or hang. None of them are the app's fault, and all of them cost real time.

### 2. ~~Xcode and command-line `xcodebuild` fight over DerivedData~~ — adopted

**Suspected, but strongly.** The Xcode GUI was running throughout this session, and two `xcodebuild ... build test` runs hung at **0% CPU for 13+ minutes** before being killed. Both drive the same `XCBBuildService` against the same build database in `DerivedData/Marginalia-dylnrbgwjyschpdtswjwyzhaafyj`, and they can deadlock or invalidate each other's state.

This is a strong candidate for a share of the "keeps failing" — a build that hangs, or fails with an error about a file another process is writing, and then succeeds on retry, is this.

**What to do.** Pick one at a time. If Claude Code or a terminal is going to run `build test`, don't have Xcode building the same scheme. If both are needed, give the CLI its own derived data:

```bash
xcodebuild -scheme Marginalia -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .build build test
```

**This is now the command in `CLAUDE.md`**, and `.build/` was already in `.gitignore`. It doesn't make it safe to run both at once — it makes the CLI's failures its own. Still pick one at a time when you can.

### 3. The simulator wedges, and it looks like a test failure

**Proven — it happened three times today.** Symptoms escalate: `simctl` commands stop returning, then `xcodebuild` hangs at 0% CPU, then a run fails with `Mach error -308 (ipc/mig) server died` or *"Failed to install or launch the test runner."*

**None of those name an assertion.** A `TEST FAILED` whose error names the launcher rather than a `#expect` is this, not your code.

```bash
pkill -9 -f CoreSimulator; killall -9 Simulator
xcrun simctl shutdown all && xcrun simctl boot "iPhone 17"
```

`docs/planning.md` already noted this; it's repeated here because it's the second most common time sink after issue 2, and the repeated `simctl launch` calls that screenshot passes depend on are what provoke it.

### 4. The app has only ever run on iOS 26.5

**Proven, and still true.** `xcrun simctl list runtimes` shows exactly one installed runtime, iOS 26.5. The deployment target is **18.0**, so roughly eight iOS versions of claimed support have never executed a line of this code.

Phase 5 added `scrollTargetBehavior(.paging)`, `scrollPosition(id:)` and `containerRelativeFrame` — all iOS 17+ and therefore legal, but "compiles against 18" and "behaves on 18" are different claims, and paging scroll views in particular changed behavior across releases.

**What to do.** Install an iOS 18 simulator runtime and run the suite against it. It's a multi-gigabyte download, which is why it wasn't done for you — it's one command and then a rerun:

```bash
xcodebuild -downloadPlatform iOS -buildVersion 18.5
xcodebuild -scheme Marginalia -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' \
  -derivedDataPath .build build test
```

### 5. ~~Release has never been built, and never run~~ — run on the simulator

**Fixed as far as a simulator can fix it.** Release builds clean at `-O`, installs, and was launched onto all four tabs: stream, books, map and review all draw, and no new crash report appeared. Issue 1 was the reason to care — concurrency checks and the optimizer behave differently at `-O` — and that specific risk is now retired for the simulator.

**Still unrun on a device at `-O`**, which is what App Store review sees. That's issue 6.

### 6. Nothing has ever run on a device

Carried from phases 3, 4 and 5. Microphone, on-device transcription, camera OCR and barcode scanning **cannot** be tested in the simulator, and the share sheet has never been opened. Every claim about them rests on unit tests and on code reading.

**Phase 6 moved this up the list.** It used to be four features asserted and never observed; it's now those four plus the embedding model the entire linking design rests on. See §14 — the simulator physically cannot run `NLContextualEmbedding`, so a device is the only place the app's real connections have ever been possible.

### 14. `NLContextualEmbedding` cannot run in the simulator

**Proven, in both the app and the test host.** The assets are downloaded and present — the log names the bundle, `mBERT.bundle/embeddings.mil`, under `MobileAsset/AssetsV2` — and `hasAvailableAssets` is `true`. Loading them compiles the model into a cache under `/var/db/com.apple.naturallanguaged`, and an app sandbox can't create that directory in the simulator:

```
Failed to load embedding from MIL representation: filesystem error:
  in create_directories: Permission denied ["/var/db/com.apple.naturallanguaged/com.apple.e5rt.e5bundlecache"]
Embedding model 'mul_Latn' is not compiled (error: … Code=7 "Compilation failed…")
```

**The app handles it correctly** — `NoteEmbedding.init?` treats a failed `load()` the same as absent assets and falls back to `NLEmbedding.sentenceEmbedding`, which is precisely the case the fallback exists for, and the library still comes out connected. Nothing to fix in the app.

**What it costs is the judgement.** Every connection anyone has looked at came from the fallback, and the fallback measurably doesn't measure meaning at note length: two paraphrases about attention score 0.267 against each other and 0.274 against a note about a kitchen tap (`NoteEmbeddingTests`, recorded as a known issue). `docs/planning.md` §phase 6 has the full read of the seed library — roughly half the found edges are defensible and one near-restatement scores below the floor.

**What to do.** Run it on a device (§6) and read `AffinityDumpTests` again. **Do not tune the floor, the weights or `k` against the fallback** — that fits the numbers to a model the app abandons the moment the assets compile. There is no simulator workaround: the directory belongs to the host, not to the app.

---

## Open — the app

Ranked by how likely they are to bite.

### 7. ~~`fatalError` on a store that won't open~~ — fixed

Replaced by `StoreFailureView`. See §0.

**What's left, and it's real:** the *silent* half of the fallback. If the disk store won't open but the in-memory one will, the app comes up on an empty library and says nothing, and notes written into it vanish on quit. That's arguably worse than the crash was — it's just quieter. Naming it on screen is the follow-on job, and it needs a decision about what the app should do rather than only a screen.

### 8. ~~Nothing deletes anything~~ — fixed

Notes, books and follow-ups all delete, through `Eraser` and a confirmation. See §0.

**Untapped, like everything else here.** The confirmation was screenshotted by launch argument, and `EraserTests` proves what a delete takes with it against a real store — but no finger has ever long-pressed a row, so the *gesture* is unproven. That's issue 12, and this is now the most valuable thing it would cover.

### 9. ~~Adding a book you already own makes a second one~~ — fixed

Named on the first save, allowed on the second. See §0.

### 10. `surfaceCount` and `lastSurfacedAt` have no way back

If review surfaces a note you didn't actually read — the app was open on the tab while you did something else — the note is pushed weeks down the queue with no way to undo it. Not urgent, but worth knowing before tuning the set in a later phase.

### 11. The card set doesn't notice midnight

`ReviewView` builds the day's set once, on arrival, and holds it. That is deliberate and correct within a session (see `docs/planning.md` §phase 5), but an app left open across midnight keeps yesterday's set until the tab is revisited. Harmless; noted so nobody "fixes" the holding behavior to chase it.

### 15. The recompute is O(N²) and nothing has measured it

`LinkWriter.relink` rescores every pair on every pass, off the main actor. At forty notes it's imperceptible; at five thousand it's 12.5 million pairs of 512-float dot products on each save, and the spec's incremental path — embed the new note, compare against every stored vector — exists for a reason.

**Deliberate, and the tradeoff is written into the code.** A delta gets the new note's edges right but can't notice that it displaced someone else's eighth-best neighbour or filled their sixth slot; a full pass is simply correct, and correctness was worth more at this size. What it needs before a real library gets big: the incremental path, a background `ModelActor` with its own context rather than `Task.detached` handing values back, and a measurement instead of this paragraph. Phase 8, alongside *rebuild connections* in settings.

---

## Open — coverage

### 12. Nothing in this app has ever been tapped

`simctl` can't tap or swipe. Every screen is reached by launch argument, and every interaction — saving, starring, filtering, going back, paging, sharing — is proven by unit tests and by the screen rendering, never by a finger.

This is the single biggest gap in what "verified" means here. **The cheapest fix is a small XCUITest target**: a launch, a tap on each tab, one capture, one star — and now a long press on a row, which is the one interaction in the app with no visible affordance at all.

**Not done here on purpose.** A UI test target is a new target, and a new target means hand-editing `project.pbxproj` — which `CLAUDE.md` says not to do, and which the synchronized file groups don't cover. It's an Xcode-GUI job (File ▸ New ▸ Target ▸ UI Testing Bundle), a few minutes, and then the tests themselves are ordinary code.

### 13. ~~Empty states are unreachable~~ — fixed

`-tinyLibrary <n>`, and both states have now been seen. See §0. The trap worth remembering: the first cut took the first `n` seed notes, which are all from one book, and `ReviewSetBuilder`'s two-per-book cap meant *every* `n` produced the empty state. It spreads across books now.

---

## What I'd change, in order

| | Change | Why | Cost |
|---|---|---|---|
| 1 | ~~`nonisolated enum Theme`~~ | **Done.** It was the crash | done |
| 2 | ~~Split DerivedData for the CLI~~ | **Done.** `-derivedDataPath .build` is the command now | done |
| 3 | ~~Delete, with confirmation~~ | **Done.** `Eraser` + `ConfirmSheet` | done |
| 4 | ~~Replace the `fatalError` with a real failure screen~~ | **Done.** `StoreFailureView` | done |
| 5 | ~~Duplicate book check~~, ~~`-tinyLibrary`~~, ~~run Release~~ | **Done.** §0 | done |
| 6 | **Install an iOS 18 runtime, run the suite on it** | Eight versions of claimed support have never executed a line | a download + an hour |
| 7 | **Run once on Nathaniel's iPhone** | Unblocks voice, OCR, barcode, share — four features asserted and never observed, plus Release at `-O` | an evening |
| 8 | **A minimal XCUITest target** | The only thing that can catch a dead button, and delete-by-long-press has no visible affordance at all | half a day, and it needs the Xcode GUI |
| 9 | Say something when the store falls back to memory | The quiet half of §7 — notes written into it vanish | an hour, plus a decision |
| 10 | Measure and then narrow the recompute | §15 — O(N²) on every save, unmeasured | a day, and phase 8 wants it anyway |

**Item 7 has been promoted to first.** It was four features asserted and never observed; phase 6 added a fifth, and that one decides whether the app's defining feature works at all (§14). Item 6 is still the cheap one.

---

## A note on the pattern behind issue 1

The crash is worth remembering as a class, not an incident. **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` means every closure handed to a system framework is `@MainActor` unless you say otherwise** — and system frameworks call those closures on their own threads whenever they like.

`Theme` was the one that escaped. The audit surface is small: search for closures stored by UIKit, AVFoundation, Vision or `URLSession`. `SpeechTranscription`'s audio tap is the other one and it is already handled (`nonisolated(unsafe) let sink`, `nonisolated private static func power`). Anything added later that hands a callback to the system needs the same treatment, and the failure mode is a `SIGTRAP` a long way from the change.
