# Issues

What's currently wrong, fragile, or worth changing — and for each one, whether it's **proven** or **suspected**. `docs/planning.md` says what's built and what's next; this file says what's broken and what it will cost to fix.

Last updated 2026-08-14, after phase 5.

---

## Fixed today

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

### 2. Xcode and command-line `xcodebuild` fight over DerivedData

**Suspected, but strongly.** The Xcode GUI was running throughout this session, and two `xcodebuild ... build test` runs hung at **0% CPU for 13+ minutes** before being killed. Both drive the same `XCBBuildService` against the same build database in `DerivedData/Marginalia-dylnrbgwjyschpdtswjwyzhaafyj`, and they can deadlock or invalidate each other's state.

This is a strong candidate for a share of the "keeps failing" — a build that hangs, or fails with an error about a file another process is writing, and then succeeds on retry, is this.

**What to do.** Pick one at a time. If Claude Code or a terminal is going to run `build test`, don't have Xcode building the same scheme. If both are needed, give the CLI its own derived data:

```bash
xcodebuild -scheme Marginalia -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .build build test
```

Add `.build/` to `.gitignore` if you adopt it.

### 3. The simulator wedges, and it looks like a test failure

**Proven — it happened three times today.** Symptoms escalate: `simctl` commands stop returning, then `xcodebuild` hangs at 0% CPU, then a run fails with `Mach error -308 (ipc/mig) server died` or *"Failed to install or launch the test runner."*

**None of those name an assertion.** A `TEST FAILED` whose error names the launcher rather than a `#expect` is this, not your code.

```bash
pkill -9 -f CoreSimulator; killall -9 Simulator
xcrun simctl shutdown all && xcrun simctl boot "iPhone 17"
```

`docs/planning.md` already noted this; it's repeated here because it's the second most common time sink after issue 2, and the repeated `simctl launch` calls that screenshot passes depend on are what provoke it.

### 4. The app has only ever run on iOS 26.5

**Proven.** `xcrun simctl list runtimes` shows exactly one installed runtime, iOS 26.5. The deployment target is **18.0**, so roughly eight iOS versions of claimed support have never executed a line of this code.

Phase 5 added `scrollTargetBehavior(.paging)`, `scrollPosition(id:)` and `containerRelativeFrame` — all iOS 17+ and therefore legal, but "compiles against 18" and "behaves on 18" are different claims, and paging scroll views in particular changed behavior across releases.

**What to do.** Install an iOS 18 simulator runtime and run the suite against it before phase 10. Cheap now, expensive as a launch-day bug report.

### 5. Release has never been built until today, and never run

**Proven.** `DerivedData/.../Build/Products/` contained only `Debug-iphonesimulator`. Release now **builds clean** — I checked — but has never been *run*.

This matters more than usual because of issue 1: concurrency isolation checks and the optimizer behave differently at `-O`, and a crash that only appears in a release build is the worst kind to find during App Store review.

### 6. Nothing has ever run on a device

Carried from phases 3, 4 and 5. Microphone, on-device transcription, camera OCR and barcode scanning **cannot** be tested in the simulator, and the share sheet has never been opened. Every claim about them rests on unit tests and on code reading.

---

## Open — the app

Ranked by how likely they are to bite.

### 7. `fatalError` on a store that won't open

`MarginaliaApp.swift:14` falls back to an in-memory container and then crashes if that also fails. The fallback covers the common case (a schema change in development), but the failure mode is a crash log rather than a screen that says what happened.

Low priority while there's one user; it becomes a launch blocker the moment there are others, because a corrupt store would make the app unopenable with no path out.

### 8. Nothing deletes anything

No note, book or follow-up can be removed. Standing since phase 4 and now worse — phase 5 added a third thing you can create. Deleting a book cascades to its notes, so it wants a real confirmation, and `danger` exists for exactly that.

### 9. Adding a book you already own makes a second one

No duplicate check on save. The two rows sort next to each other, which at least makes it visible.

### 10. `surfaceCount` and `lastSurfacedAt` have no way back

If review surfaces a note you didn't actually read — the app was open on the tab while you did something else — the note is pushed weeks down the queue with no way to undo it. Not urgent, but worth knowing before tuning the set in a later phase.

### 11. The card set doesn't notice midnight

`ReviewView` builds the day's set once, on arrival, and holds it. That is deliberate and correct within a session (see `docs/planning.md` §phase 5), but an app left open across midnight keeps yesterday's set until the tab is revisited. Harmless; noted so nobody "fixes" the holding behavior to chase it.

---

## Open — coverage

### 12. Nothing in this app has ever been tapped

`simctl` can't tap or swipe. Every screen is reached by launch argument, and every interaction — saving, starring, filtering, going back, paging, sharing — is proven by unit tests and by the screen rendering, never by a finger.

This is the single biggest gap in what "verified" means here. **The cheapest fix is a small XCUITest target**: a launch, a tap on each tab, one capture, one star. It would have caught nothing so far, but it's the only thing that can catch a dead button.

### 13. Empty states are unreachable

Review's empty state needs a library under three notes; the seed has forty. Same for `keep going` on an exhausted library. Both are simple code, neither has been seen. A launch argument that seeds a tiny library — `-tinyLibrary 1` — would make both screenshottable.

---

## What I'd change, in order

| | Change | Why | Cost |
|---|---|---|---|
| 1 | ~~`nonisolated enum Theme`~~ | **Done today.** It was the crash | done |
| 2 | Stop running Xcode and CLI builds at once, or split DerivedData | Most of the lost time | minutes |
| 3 | Install an iOS 18 runtime, run the suite on it | Eight versions of untested claimed support | ~an hour |
| 4 | Run once on Nathaniel's iPhone | Unblocks voice, OCR, barcode, share — four features asserted and never observed | an evening |
| 5 | A minimal XCUITest target | The only thing that can catch a dead button | half a day |
| 6 | Delete, with confirmation | Three things can now be created and none removed | half a day |
| 7 | Replace the `fatalError` with a real failure screen | Launch blocker later, cheap now | an hour |

Items 2 and 3 are the ones that pay for themselves this week.

---

## A note on the pattern behind issue 1

The crash is worth remembering as a class, not an incident. **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` means every closure handed to a system framework is `@MainActor` unless you say otherwise** — and system frameworks call those closures on their own threads whenever they like.

`Theme` was the one that escaped. The audit surface is small: search for closures stored by UIKit, AVFoundation, Vision or `URLSession`. `SpeechTranscription`'s audio tap is the other one and it is already handled (`nonisolated(unsafe) let sink`, `nonisolated private static func power`). Anything added later that hands a callback to the system needs the same treatment, and the failure mode is a `SIGTRAP` a long way from the change.
