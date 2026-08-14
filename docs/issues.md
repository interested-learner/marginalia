# Issues

What's currently wrong, fragile, or worth changing — and for each one, whether it's **proven** or **suspected**. `docs/planning.md` says what's built and what's next; this file says what's broken and what it will cost to fix.

Last updated 2026-08-14, after phase 10.

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

### 4. ~~The app has only ever run on iOS 26.5~~ — iOS 18.5 installed and run

**Done in phase 10.** The runtime was downloaded, the whole suite runs against `iPhone 16, OS=18.5`, and the app was installed and walked across all four tabs there. **402 tests pass on both runtimes**, and the two are not merely both-green: the map draws the *same graph, node for node and edge for edge*, on 18.5 and on 26.5. Phase 5's `scrollTargetBehavior(.paging)` / `scrollPosition(id:)` / `containerRelativeFrame` — the specific reason to worry — behave the same on both.

Use its own derived data, for the reason in §2:

```bash
xcodebuild -scheme Marginalia -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' \
  -derivedDataPath .build-ios18 build test
```

**One real difference came out of it**, and it's §21: the iOS 18.5 *test host* gets no embedder at all.

Still true that only two of roughly nine supported versions have ever run this code — but the two are the ends of the range, which is the pair worth having.

### 21. On iOS 18.5 the **test host** gets no embedder — the app does

**Proven, and the distinction is the whole entry.** In the iOS 18.5 test host, `NLEmbedding.sentenceEmbedding(for: .english)` returns nil, so `NoteEmbedding.init?` returns nil and nothing is embedded. `ManualLinkTests.aHandMadeLinkSurvivesARecompute` was the only test that noticed, because it was the only one that *required* an embedder to exist.

**The app on the same runtime embeds normally.** Installed on `iPhone 16, OS=18.5`, the map draws a graph identical to 26.5's — around fifty edges against the sixteen the seed pins, so the fallback ran. Whatever the test host is missing, the app process has.

**Nothing to fix in the app**, and this is not the test being bent to go green: `NoteEmbedding` has documented a nil embedder as a supported outcome since phase 6 — *"a library with no connections rather than a crash"* — so a test that required one was asserting a promise the app never made. It now asserts the pinned edge either way and checks `embeddedAt == nil` when there's no embedder, which is the harder case and the one that was never covered before.

**What's unresolved:** whether this is the 18.5 runtime's assets, the test host's sandbox, or iOS 18 itself. Same shape as §14 and the same answer — a device (§6) settles it.

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

### 15. ~~The recompute is O(N²) and nothing has measured it~~ — measured, and it's fine

**It has now been measured, and the paragraph that stood here was wrong about which half of the problem mattered.** `AffinityBenchmarkTests` times `AffinityEngine.links` over synthetic 512-dimension libraries. At `-O`:

| notes | pairs | ms | µs/pair |
|---:|---:|---:|---:|
| 100 | 4,950 | 5 | 0.98 |
| 250 | 31,125 | 23 | 0.73 |
| 500 | 124,750 | 90 | 0.72 |
| 1,000 | 499,500 | 356 | 0.71 |

Extrapolating the flat per-pair cost: **~9 seconds at five thousand notes**, off the main actor, which is what the spec predicted and what the design was willing to pay. Under a couple of thousand notes it's under two seconds. **The incremental path is not needed**, and building a background `ModelActor` speculatively would have been work in service of a number nobody had taken.

Two things came out of taking it:

**Half the cost was work that didn't belong in the loop.** `AffinityEngine` was normalizing both notes' tags and re-deriving both vectors' magnitudes *inside* the pair loop — O(N) jobs done O(N²) times. Hoisting them per subject took the pass from **1.50 µs a pair to 0.71**, with the resulting graph unchanged edge for edge at every size (273 / 551 / 1,069 / 2,583 — identical before and after, which is the check that the optimization was only an optimization).

**A Debug number is not a number.** The same pass measures **44 µs a pair** unoptimized — 62× slower, and 27 seconds for a thousand notes. Anyone re-running this must use Release with `SWIFT_ENABLE_TESTABILITY=YES`; the command is in `CLAUDE.md`.

What's still true: a delta would be wrong at any size, because mutual k-NN and the degree cap are properties of the whole graph. That was never a performance decision and it doesn't change.

### 16. One enormous book never quite settles

`GraphLayout` converges everywhere it was measured — a ring, three loose clumps, a scatter with no edges, at 46 and at 120 nodes — except for one shape: a single hub with a few hundred leaves and nothing else, which is what a book view looks like for a book with three hundred notes in it. The residual force stays several times higher than everywhere else at any budget worth spending.

**It draws as a hub in a halo, which is what it is.** The spacing guarantee and the box still hold, so nothing overlaps and nothing runs off the screen; the halo simply never stops shuffling, and two launches a week apart would arrange those three hundred notes differently around the same hub. Nobody has a book with three hundred notes in it yet. Worth knowing before somebody does.

### 18. ~~Quotes are never wrapped in quote marks~~ — decided: no quote marks. **And this entry was wrong**

**The premise was false and it survived three phases.** This said nothing in the app drew curly quotes. Two things did: `QuoteRule` (so every stream row, book-detail row and the scanner's preview) and `ReviewCard`, each wrapping in `\u{201C}`/`\u{201D}` since phase 1. It was caught in phase 10 by a screenshot at the largest accessibility size — the quote mark is right there at the head of the card — while looking for something else entirely. Nobody had read the two files; the entry was written from the design system and never checked against the code, which is the actual lesson.

**Decided in favour of the rule.** The printer's convention is a rule *or* quote marks, never both, and the 2pt `ink` rule already says quoted matter. `“ ”` would also be the closest thing to a dingbat in a system that rules those out everywhere else. So the marks came *out* of both files, and the sentence came out of `docs/design-system.md`.

Worth knowing: the review card doesn't draw the rule either (it's centred and open, with nothing beside it to rule against), so a quote there is marked by `[q] quote` in the metadata and `— book · page` underneath. That was already true and is now the whole of it.

### 20. iOS 26 mangles a **tinted** app icon that has a transparent background

**Proven by isolation, in phase 10, on the home screen.** The first icon shipped all three appearance variants with the tinted one drawn as Apple documents it — grayscale artwork on transparency, system supplies the ground. iOS 26.5 drew a dark tile with a **white disc** in the middle and the `[m]` scattered black across it: unrecognizable, and nothing like any of the three source PNGs.

Isolated by shipping the variants one at a time and screenshotting each: light alone is correct, light + dark is correct, adding the transparent tinted variant breaks it. The cause is iOS 26's Liquid Glass pass, which puts a specular highlight behind the artwork — over a mostly-transparent image that highlight *is* the artwork.

**Fixed by making the tinted variant opaque**, on a neutral dark ground (`Tools/MakeAppIcon.swift`). All three render correctly now. Contrary to Apple's own guidance, which is written for the pre-26 compositor.

**What's still unverified:** the dark variant has never been *selected* on screen. This simulator's home screen is in Light icon appearance — every system icon, Photos and Reminders included, draws as a light tile in dark mode — so SpringBoard never asked for it. The PNG is correct and in the catalog; which one iOS picks is a system setting nothing on the command line reaches. A device (§6), or two taps in Settings.

---

### 19. The reminder has never been received

Phase 8's daily notification is written, scheduled and unobserved. `NotificationPlanTests` proves which note each of the next seven days carries and when it fires; nothing proves that iOS delivers it, that the alert reads well on a lock screen, or that tapping it lands on the right review card. `NotificationRouter` posts, `RootView` routes, and neither has run outside a compiler.

Local notifications **do** work in the simulator, so this is cheap to check by hand: turn the reminder on, set it a minute ahead, background the app, wait. It wasn't done here because the permission prompt is a system alert and the simulator can't be tapped from the command line — see below.

**Phase 9 tried the two command-line routes around that, and both are dead ends.** `xcrun simctl privacy` has **no notifications service** — its list is TCC only (calendar, contacts, location, photos, microphone, motion, reminders, siri), and notifications aren't TCC — so authorization cannot be granted from a shell. And `xcrun simctl push booted com.marginalia.app payload.apns` prints `Notification sent to 'com.marginalia.app'` and then delivers **nothing**, because the app has never been authorized; the exit code says success and the screen stays a home screen. Neither is a bug in the app and both are worth knowing before somebody spends the afternoon phase 9 spent twenty minutes on. The cost is still ten minutes — they just have to be a person's, with the simulator on screen.

**A stuck permission alert survives an uninstall.** Launching with `-preference.notifications 1` raises the notification prompt, and because nothing can answer it, it stays on the SpringBoard across app launches *and* across an uninstall/reinstall, sitting over every screenshot taken afterwards. `xcrun simctl shutdown all && xcrun simctl boot "iPhone 17"` clears it. This is the same class as the `simctl openurl` alert already noted in `docs/planning.md`.

**It did catch a real bug**, which is the argument for taking the screenshot: the scheduler was calling `authorize()` rather than `isAuthorized()`, so a reader with the reminder on got a permission prompt at launch — breaking the app's own rule that permission is asked at first use and never at launch. Invisible in code, obvious in an image, for the fourth time on this project.

## Open — coverage

### 12. Nothing in this app has ever been tapped

`simctl` can't tap or swipe. Every screen is reached by launch argument, and every interaction — saving, starring, filtering, going back, paging, sharing — is proven by unit tests and by the screen rendering, never by a finger.

This is the single biggest gap in what "verified" means here. **The cheapest fix is a small XCUITest target**: a launch, a tap on each tab, one capture, one star — and now a long press on a row and the map's two gestures, which is where the affordance-free interactions have collected.

**Phase 7 made this worse rather than better**, and it should be said plainly: the map is the most gestural screen in the app and none of its gestures have been performed. See §17.

**Phase 8 added five more untapped things**, though the newest ones are ordinary buttons rather than invisible gestures: `search` and `settings` in the stream header, a result row that opens its note, a book title inside a source line, `[◇] connections` in a row's long-press menu, and `→ link` choosing a note to connect to. Every one was screenshot by launch argument. The two worth doubting are the ones with no visible affordance: the tappable book title (deliberately not underlined — see the design system) and `connections` inside the long-press menu.

**Phase 9 added a screen that is nothing but taps.** The text scanner's whole interaction is tapping recognized lines in a viewfinder, and not one of them has happened — the simulator has no camera, so what was screenshot is the written fallback. Unlike the map's gestures, an XCUITest can't reach this one either: it needs a camera and a printed page. It's a device job, and it's the only interaction in the app that is.

**Not done here on purpose.** A UI test target is a new target, and a new target means hand-editing `project.pbxproj` — which `CLAUDE.md` says not to do, and which the synchronized file groups don't cover. It's an Xcode-GUI job (File ▸ New ▸ Target ▸ UI Testing Bundle), a few minutes, and then the tests themselves are ordinary code.

### 13. ~~Empty states are unreachable~~ — fixed

`-tinyLibrary <n>`, and both states have now been seen. See §0. The trap worth remembering: the first cut took the first `n` seed notes, which are all from one book, and `ReviewSetBuilder`'s two-per-book cap meant *every* `n` produced the empty state. It spreads across books now.

### 17. The map's gestures have never been made

Four interactions were built and none has been performed: selecting a node, tapping a selected hub to expand it, **holding a line to disconnect it**, and tapping empty space to deselect. Every one of them was reached by launch argument instead — `-mapSelect`, `-mapBook`, `-confirmDelete connection` — which proves the state renders and proves nothing about the gesture that should get you there.

The hold is the one to worry about. It's assembled out of a `LongPressGesture` for the timing and a zero-distance `DragGesture` for the location, because neither reports both; it sits under forty-odd tappable node views; and it has to decide which of seventy hairlines the thumb meant. All of that is plausible and none of it is observed. It's also the app's only destructive gesture with no visible affordance whatsoever — §12's XCUITest target is the answer, and this is now the strongest argument for it.

---

## What I'd change, in order

| | Change | Why | Cost |
|---|---|---|---|
| 1 | ~~`nonisolated enum Theme`~~ | **Done.** It was the crash | done |
| 2 | ~~Split DerivedData for the CLI~~ | **Done.** `-derivedDataPath .build` is the command now | done |
| 3 | ~~Delete, with confirmation~~ | **Done.** `Eraser` + `ConfirmSheet` | done |
| 4 | ~~Replace the `fatalError` with a real failure screen~~ | **Done.** `StoreFailureView` | done |
| 5 | ~~Duplicate book check~~, ~~`-tinyLibrary`~~, ~~run Release~~ | **Done.** §0 | done |
| 6 | ~~Install an iOS 18 runtime, run the suite on it~~ | **Done.** §4 — 402 pass on 18.5, same graph as 26.5, and §21 came out of it | done |
| 7 | **Run once on Nathaniel's iPhone** | Unblocks voice, OCR, barcode, share — four features asserted and never observed, plus Release at `-O`, plus the dark app icon (§20) | an evening |
| 8 | **A minimal XCUITest target** | The only thing that can catch a dead button; delete-by-long-press and the map's hold-a-line have no visible affordance at all (§17) | half a day, and it needs the Xcode GUI |
| 9 | Say something when the store falls back to memory | The quiet half of §7 — notes written into it vanish | an hour, plus a decision |
| 10 | ~~Measure and then narrow the recompute~~ | **Done.** §15 — measured at 0.71 µs a pair, and 2× faster than it was | done |
| 11 | Receive one reminder | §19 — the whole feature is unobserved, and the simulator can deliver it. **Not from a shell**: phase 9 established that neither `simctl privacy` nor `simctl push` can get past authorization | ten minutes of somebody's hands |

**Item 7 is now the only expensive thing left, and it is first.** It was four features asserted and never observed; phase 6 added a fifth, and that one decides whether the app's defining feature works at all (§14). Item 6 is done, and doing it is what produced §21.

---

## A note on the pattern behind issue 1

The crash is worth remembering as a class, not an incident. **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` means every closure handed to a system framework is `@MainActor` unless you say otherwise** — and system frameworks call those closures on their own threads whenever they like.

`Theme` was the one that escaped. The audit surface is small: search for closures stored by UIKit, AVFoundation, Vision or `URLSession`. `SpeechTranscription`'s audio tap is the other one and it is already handled (`nonisolated(unsafe) let sink`, `nonisolated private static func power`). Anything added later that hands a callback to the system needs the same treatment, and the failure mode is a `SIGTRAP` a long way from the change.
