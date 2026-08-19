# Crossings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Delete the map tab and its machinery, and move the one thing it computed worth keeping — a crossing, two notes from two books months apart — into the daily review as a card.

**Architecture:** Two new pure functions (`RelativeTime.gap`, `CrossingFinder`) and one new view (`CrossingCard`), composed into `ReviewView` as a ninth card between the day's eight notes and the closing card. Then 2,764 lines of app code and 92 tests come out. Tasks 1–4 add; task 5 deletes; the app builds and the suite passes at every commit.

**Tech Stack:** Swift 6 · SwiftUI · SwiftData · Swift Testing (`@Test`/`#expect`, never XCTest) · iOS 18.0 · Xcode 26.6.

**Spec:** `docs/specs/2026-08-18-crossings-design.md` — read it before task 1. It carries the reasoning; this plan carries the steps.

## Global Constraints

Copied from `CLAUDE.md`. These apply to **every** task and are not negotiable.

- **No raw color literals.** Every color comes from `Theme`. Not `Color.gray`, not `.secondary`.
- **No shadows anywhere.** Separation is `Hairline()` (1px, `Theme.hairline`) and `Theme.surfaceSoft`.
- **ASCII markers only**, via the named cases in `Glyphs` — never a literal, never an SF Symbol, never a dingbat (`★ ✎ ✓` are forbidden; `█ ░ ■ ● ▼ ▁▂▃` are fine).
- **Radius 4px on interactive elements only.** Never a pill, never a circle.
- **One font** — JetBrains Mono, via `Typography`. Never `.system(size:)`.
- **Lowercase chrome.** Titles, labels and placeholders are lowercase.
- **Dynamic Type everywhere.** `chromeTypeSize()` caps signposts at `xLarge`; content never caps.
- **A quote wears the 2pt `ink` rule and no quote marks.**
- **Views never see SwiftData.** They take `NoteRowData` / `BookRowData`; `Model/RowMapping.swift` is the only file that knows both sides.
- **Pure enums used from a `@Model` need `nonisolated`** — the project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
- **Nothing expensive in a `body`.** Build once above the loop or hold it in `@State`.
- **Never add a source file to `project.pbxproj` by hand.** The project uses synchronized file groups; new `.swift` files under `Marginalia/` are picked up automatically.
- **Tests are Swift Testing** — `@Test`, `#expect`. Not XCTest.

**The two build commands.** Separate derived-data paths are mandatory (`docs/issues.md` §2 — the CLI and Xcode deadlock over one XCBBuildService):

```bash
xcodebuild -scheme Marginalia -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .build build test
xcodebuild -scheme Marginalia -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' \
  -derivedDataPath .build-ios18 build test
```

**Run `build test`, never `build` alone** — a broken test target can fail to link while `build` still reports success.

---

### Task 1: `RelativeTime.gap`

The distance between two notes, in the app's own voice. Numerals and lowercase, like every other function in this file — `2 mins ago`, never "two".

**Files:**
- Modify: `Marginalia/Model/RelativeTime.swift`
- Test: `MarginaliaTests/RelativeTimeTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `RelativeTime.gap(from: Date, to: Date, calendar: Calendar = .current) -> String`. Returns `"7 months apart"`, `"3 days apart"`, `"1 year apart"`, or `"the same day"`. Symmetric — argument order does not matter.

- [ ] **Step 1: Write the failing tests**

Append to `MarginaliaTests/RelativeTimeTests.swift`, inside the existing test struct:

```swift
    // MARK: gap — the crossing card's distance line
    //
    // Reuses the `calendar` and `date(_:_:_:)` helpers already at the top of
    // this struct. Do not add a second UTC calendar beside them.

    @Test func gapWithinADayIsTheSameDay() {
        #expect(RelativeTime.gap(from: date(2026, 3, 1), to: date(2026, 3, 1), calendar: calendar)
                == "the same day")
    }

    @Test func gapOfOneDayIsSingular() {
        #expect(RelativeTime.gap(from: date(2026, 3, 1), to: date(2026, 3, 2), calendar: calendar)
                == "1 day apart")
    }

    @Test func gapInDaysBelowAMonth() {
        #expect(RelativeTime.gap(from: date(2026, 3, 1), to: date(2026, 3, 20), calendar: calendar)
                == "19 days apart")
    }

    @Test func gapInMonths() {
        #expect(RelativeTime.gap(from: date(2025, 8, 14), to: date(2026, 3, 20), calendar: calendar)
                == "7 months apart")
    }

    @Test func gapInYears() {
        #expect(RelativeTime.gap(from: date(2024, 1, 10), to: date(2026, 3, 20), calendar: calendar)
                == "2 years apart")
    }

    /// A crossing has no direction, so neither does the line that measures it.
    @Test func gapIsSymmetric() {
        let earlier = date(2025, 8, 14)
        let later = date(2026, 3, 20)
        #expect(RelativeTime.gap(from: later, to: earlier, calendar: calendar)
                == RelativeTime.gap(from: earlier, to: later, calendar: calendar))
    }
```

- [ ] **Step 2: Run the tests and watch them fail**

```bash
xcodebuild -scheme Marginalia -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .build test -only-testing:MarginaliaTests/RelativeTimeTests 2>&1 | tail -30
```

Expected: compile failure — `type 'RelativeTime' has no member 'gap'`.

- [ ] **Step 3: Implement it**

Add to `Marginalia/Model/RelativeTime.swift`, after `dayLabel` and before `elapsed`:

```swift
    /// `7 months apart` — the distance between the two notes on a crossing card,
    /// and the fact that makes the card land. *You thought this in August and
    /// again in March and never noticed.*
    ///
    /// **Symmetric**, because a crossing has no direction. `NoteEdge` stores one
    /// and the app has displayed both ways since phase 6; a line that read
    /// differently depending on which note came first would be the first place
    /// that stopped being true.
    static func gap(from a: Date, to b: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: min(a, b), to: max(a, b))
        if let years = parts.year, years > 0 { return apart(years, "year") }
        if let months = parts.month, months > 0 { return apart(months, "month") }
        if let days = parts.day, days > 0 { return apart(days, "day") }
        return "the same day"
    }

    private static func apart(_ n: Int, _ unit: String) -> String {
        "\(n) \(unit)\(n == 1 ? "" : "s") apart"
    }
```

- [ ] **Step 4: Run the tests and watch them pass**

```bash
xcodebuild -scheme Marginalia -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .build test -only-testing:MarginaliaTests/RelativeTimeTests 2>&1 | tail -20
```

Expected: all `RelativeTimeTests` pass, the six new ones included.

- [ ] **Step 5: Commit**

```bash
git add Marginalia/Model/RelativeTime.swift MarginaliaTests/RelativeTimeTests.swift
git commit -m "RelativeTime.gap — how far apart two notes on a crossing are"
```

---

### Task 2: `CrossingFinder`

The pure half, and where `MapView.crossingRows` goes before that file is deleted. Plain values in, plain values out, no `ModelContext` — the same shape as `ReviewSetBuilder`, which likewise takes models and a `Date`.

**Files:**
- Create: `Marginalia/Features/Review/CrossingFinder.swift`
- Modify: `Marginalia/Features/Review/ReviewSetBuilder.swift` — `daySeed` from `private` to internal
- Test: `MarginaliaTests/CrossingFinderTests.swift`

**Interfaces:**
- Consumes: `ReviewSetBuilder.daySeed(_ day: Date, _ calendar: Calendar) -> UInt64` (made internal here).
- Produces:
  - `CrossingFinder.Crossing` — `let edge: NoteEdge`, `let a: Note`, `let b: Note`, `var score: Double`
  - `CrossingFinder.all(from edges: [NoteEdge]) -> [Crossing]` — ranked, deduplicated
  - `CrossingFinder.pick(from edges: [NoteEdge], on day: Date, calendar: Calendar = .current, avoiding: Set<Int> = []) -> Crossing?`

- [ ] **Step 1: Make `daySeed` internal**

In `Marginalia/Features/Review/ReviewSetBuilder.swift`, change the declaration (leave the doc comment above it as it is) and add one line to it:

```swift
    /// The calendar day, as a number. Same day in, same set out — leaving review
    /// and coming back must not reshuffle it.
    ///
    /// **Internal rather than private**, because `CrossingFinder` rotates the
    /// day's crossing on the same number. Two definitions of "a day" in one
    /// screen would drift the way two write paths would.
    static func daySeed(_ day: Date, _ calendar: Calendar) -> UInt64 {
        let start = calendar.startOfDay(for: day).timeIntervalSince1970
        return UInt64(bitPattern: Int64((start / 86_400).rounded(.down)))
    }
```

- [ ] **Step 2: Write the failing tests**

Create `MarginaliaTests/CrossingFinderTests.swift`:

```swift
import Testing
import Foundation
@testable import Marginalia

/// The day's crossing: two notes from two different books that the app connected
/// by meaning. Pure — plain models and a date in, one crossing out — which is
/// what makes every rule in it assertable without a container, exactly as
/// `ReviewSetBuilderTests` does.
///
/// The rules come from `docs/specs/2026-08-18-crossings-design.md`.
@MainActor
struct CrossingFinderTests {

    // MARK: Fixtures

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func day(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: 1_760_000_000 + Double(offset) * 86_400)
    }

    private func book(_ title: String, _ status: BookStatus = .finished) -> Book {
        Book(title: title, status: status)
    }

    private func note(_ id: Int, in book: Book?) -> Note {
        Note(shortID: id, text: "note \(id)", book: book)
    }

    private func edge(_ a: Note, _ b: Note, _ score: Double,
                      suppressed: Bool = false) -> NoteEdge {
        NoteEdge(from: a, to: b, score: score, isSuppressed: suppressed)
    }

    // MARK: What counts as a crossing

    @Test func aPairFromTwoBooksCrosses() {
        let one = book("Norman"), two = book("Pirsig")
        let a = note(1, in: one), b = note(2, in: two)

        let found = CrossingFinder.all(from: [edge(a, b, 0.6)])

        #expect(found.count == 1)
        #expect(Set([found[0].a.shortID, found[0].b.shortID]) == [1, 2])
    }

    @Test func aPairFromOneBookDoesNot() {
        let one = book("Norman")
        let found = CrossingFinder.all(from: [edge(note(1, in: one), note(2, in: one), 0.9)])
        #expect(found.isEmpty)
    }

    /// A crossing prints `— Norman · p. 62`. An unfiled capture has nothing to
    /// put there, so the Inbox is not one of the two books.
    @Test func theInboxIsNotABook() {
        let inbox = book(Inbox.title, .inbox)
        let real = book("Norman")
        let found = CrossingFinder.all(from: [edge(note(1, in: inbox), note(2, in: real), 0.9)])
        #expect(found.isEmpty)
    }

    @Test func aNoteWithNoBookDoesNotCross() {
        let real = book("Norman")
        let found = CrossingFinder.all(from: [edge(note(1, in: nil), note(2, in: real), 0.9)])
        #expect(found.isEmpty)
    }

    /// What makes `[x] not related` stick: suppression is the memory of the
    /// deletion, and every recompute is a full one.
    @Test func aSuppressedEdgeIsNotACrossing() {
        let one = book("Norman"), two = book("Pirsig")
        let found = CrossingFinder.all(
            from: [edge(note(1, in: one), note(2, in: two), 0.9, suppressed: true)]
        )
        #expect(found.isEmpty)
    }

    @Test func aDanglingEdgeIsNotACrossing() {
        #expect(CrossingFinder.all(from: [NoteEdge(from: nil, to: nil, score: 0.9)]).isEmpty)
    }

    // MARK: Ranking

    @Test func strongestFirst() {
        let one = book("Norman"), two = book("Pirsig")
        let a = note(1, in: one), b = note(2, in: two)
        let c = note(3, in: one), d = note(4, in: two)

        let found = CrossingFinder.all(from: [edge(a, b, 0.5), edge(c, d, 0.8)])

        #expect(found.map(\.score) == [0.8, 0.5])
    }

    /// The tie-break `AffinityEngine` and `ReviewSetBuilder` both use. A screen
    /// that reshuffles on every launch reads as the app changing its mind.
    @Test func tiesBreakOnTheLowerIdFirst() {
        let one = book("Norman"), two = book("Pirsig")
        let found = CrossingFinder.all(from: [
            edge(note(7, in: one), note(8, in: two), 0.6),
            edge(note(3, in: one), note(4, in: two), 0.6)
        ])
        #expect(found.map(\.a.shortID) == [3, 7])
    }

    /// A display rule, not a claim about the data. The hub behaviour phase 6
    /// measured put `n.18` in three consecutive rows the first time this ran.
    @Test func aNoteAppearsInOnlyOneCrossing() {
        let one = book("Norman"), two = book("Pirsig"), three = book("Marcus")
        let hub = note(1, in: one)
        let found = CrossingFinder.all(from: [
            edge(hub, note(2, in: two), 0.9),
            edge(hub, note(3, in: three), 0.8),
            edge(hub, note(4, in: two), 0.7)
        ])
        #expect(found.count == 1)
        #expect(Set([found[0].a.shortID, found[0].b.shortID]) == [1, 2])
    }

    // MARK: Picking the day's one

    @Test func noCrossingsMeansNoCard() {
        #expect(CrossingFinder.pick(from: [], on: day(0), calendar: calendar) == nil)
    }

    @Test func theSameDayPicksTheSameCrossing() {
        let edges = threeCrossings()
        let first = CrossingFinder.pick(from: edges, on: day(3), calendar: calendar)
        let again = CrossingFinder.pick(from: edges, on: day(3), calendar: calendar)
        #expect(first?.edge === again?.edge)
    }

    /// It rotates rather than repeating one pair until it is suppressed, and it
    /// cycles rather than running out.
    @Test func consecutiveDaysWalkTheList() {
        let edges = threeCrossings()
        let walk = (0..<6).compactMap {
            CrossingFinder.pick(from: edges, on: day($0), calendar: calendar)?.a.shortID
        }
        #expect(walk.count == 6)
        #expect(Set(walk).count == 3)
        #expect(Array(walk.prefix(3)) == Array(walk.suffix(3)))
    }

    @Test func itAvoidsNotesAlreadyInTheDaysSet() {
        let edges = threeCrossings()
        let all = CrossingFinder.all(from: edges)
        let avoided = Set([all[0].a.shortID, all[0].b.shortID])

        for offset in 0..<6 {
            let picked = CrossingFinder.pick(from: edges, on: day(offset),
                                             calendar: calendar, avoiding: avoided)
            #expect(picked != nil)
            #expect(!avoided.contains(picked!.a.shortID))
            #expect(!avoided.contains(picked!.b.shortID))
        }
    }

    /// Showing nothing on a small library is worse than showing `n.03` twice.
    @Test func itShowsTheBestOneWhenEveryCandidateOverlaps() {
        let one = book("Norman"), two = book("Pirsig")
        let a = note(1, in: one), b = note(2, in: two)
        let picked = CrossingFinder.pick(from: [edge(a, b, 0.6)], on: day(0),
                                         calendar: calendar, avoiding: [1, 2])
        #expect(picked != nil)
    }

    /// Three crossings over six books, so every note is in exactly one.
    private func threeCrossings() -> [NoteEdge] {
        let books = (0..<6).map { book("b\($0)") }
        return (0..<3).map { index in
            edge(note(index * 2 + 1, in: books[index * 2]),
                 note(index * 2 + 2, in: books[index * 2 + 1]),
                 0.9 - Double(index) / 10)
        }
    }
}
```

- [ ] **Step 3: Run the tests and watch them fail**

```bash
xcodebuild -scheme Marginalia -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .build test -only-testing:MarginaliaTests/CrossingFinderTests 2>&1 | tail -30
```

Expected: compile failure — `cannot find 'CrossingFinder' in scope`.

- [ ] **Step 4: Implement it**

Create `Marginalia/Features/Review/CrossingFinder.swift`:

```swift
import Foundation

/// The day's crossing: two notes from two different books that the app connected
/// by meaning, months apart.
///
/// **Pure**, in the sense the rest of this app means it — plain models and a
/// date in, one crossing out, no `ModelContext` and no clock of its own. The
/// same shape as `ReviewSetBuilder`, and for the same reason.
///
/// This is what the map tab computed that was worth keeping. It lived in
/// `MapView.crossingRows` as a computed property on a screen nobody opened;
/// `docs/decisions.md` §21 is why it moved here and the drawing didn't.
nonisolated enum CrossingFinder {

    /// One connection that spans two books. Carries the edge because
    /// `[x] not related` suppresses it, and re-finding it by note ids
    /// afterwards would be a second way to identify the same thing.
    struct Crossing {
        let edge: NoteEdge
        let a: Note
        let b: Note

        var score: Double { edge.score }
    }

    /// Every crossing in the library, strongest first, each note appearing once.
    static func all(from edges: [NoteEdge]) -> [Crossing] {
        var found: [Crossing] = []

        for edge in edges {
            guard !edge.isSuppressed, let from = edge.from, let to = edge.to else { continue }
            guard let left = from.book, let right = to.book else { continue }
            // The Inbox is found by status and is not a source. `BookWriter`
            // refuses to restatus it and `Eraser` refuses to delete it; this is
            // the third place it is special, and for the same reason.
            guard left.status != .inbox, right.status != .inbox else { continue }
            guard left.persistentModelID != right.persistentModelID else { continue }
            found.append(Crossing(edge: edge, a: from, b: to))
        }

        found.sort(by: strongestFirst)

        // **One appearance per note, and this is a display rule rather than a
        // claim about the data.** The hub behaviour phase 6 measured — `n.02`
        // and `n.13` turn up in half the shortlists, and mutual k-NN does not
        // stop it at forty notes — put `n.18` in three consecutive rows the
        // first time this ran. Every one of those connections still exists,
        // under the note itself; this list just takes the strongest each note
        // has, so three crossings are three ideas.
        var used: Set<Int> = []
        var kept: [Crossing] = []
        for crossing in found {
            guard !used.contains(crossing.a.shortID), !used.contains(crossing.b.shortID)
            else { continue }
            used.insert(crossing.a.shortID)
            used.insert(crossing.b.shortID)
            kept.append(crossing)
        }
        return kept
    }

    /// The one crossing today's review carries, or `nil` on a library that has
    /// none — in which case review is exactly what it was before this existed.
    ///
    /// **Day-stable, and it rotates.** `daySeed` advances by one a day, so the
    /// reader walks the ranked list an entry at a time and it cycles rather than
    /// repeating one pair forever. The alternatives were a `lastShownAt` on
    /// `NoteEdge` — a schema change, bought for a rotation — or always showing
    /// the strongest, which shows one pair every day until it is suppressed.
    ///
    /// `avoiding` is the ids already in the day's set. A crossing that overlaps
    /// them is skipped where another is available, and shown anyway where none
    /// is: seeing `n.03` as card 2 and again as half of card 9 is a small
    /// oddity, and suppressing the whole feature on a small library is a bigger
    /// one.
    static func pick(
        from edges: [NoteEdge],
        on day: Date,
        calendar: Calendar = .current,
        avoiding: Set<Int> = []
    ) -> Crossing? {
        let ranked = all(from: edges)
        guard !ranked.isEmpty else { return nil }

        let clear = ranked.filter {
            !avoiding.contains($0.a.shortID) && !avoiding.contains($0.b.shortID)
        }
        let pool = clear.isEmpty ? ranked : clear

        let seed = ReviewSetBuilder.daySeed(day, calendar)
        return pool[Int(seed % UInt64(pool.count))]
    }

    /// Ties break on the pair, low id first — the same rule `AffinityEngine`,
    /// `MapGraph` and `ReviewSetBuilder` all use, so a recompute over unchanged
    /// notes returns the same order.
    private static func strongestFirst(_ x: Crossing, _ y: Crossing) -> Bool {
        guard x.score == y.score else { return x.score > y.score }
        return pairKey(x) < pairKey(y)
    }

    private static func pairKey(_ crossing: Crossing) -> [Int] {
        [min(crossing.a.shortID, crossing.b.shortID), max(crossing.a.shortID, crossing.b.shortID)]
    }
}
```

- [ ] **Step 5: Run the tests and watch them pass**

```bash
xcodebuild -scheme Marginalia -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .build test \
  -only-testing:MarginaliaTests/CrossingFinderTests \
  -only-testing:MarginaliaTests/ReviewSetBuilderTests 2>&1 | tail -20
```

Expected: all pass. `ReviewSetBuilderTests` is included because `daySeed`'s visibility changed.

- [ ] **Step 6: Commit**

```bash
git add Marginalia/Features/Review/CrossingFinder.swift \
        Marginalia/Features/Review/ReviewSetBuilder.swift \
        MarginaliaTests/CrossingFinderTests.swift
git commit -m "CrossingFinder — the day's crossing, ranked and rotated

Lifts MapView.crossingRows out of a view and into a pure type before
that file is deleted: cross-book only, the Inbox excluded, suppressed
edges excluded, one appearance per note."
```

---

### Task 3: The crossing card

Presentation only. Takes `CrossingCardData` and knows nothing about SwiftData, like every other view in the app.

**Files:**
- Create: `Marginalia/Features/Review/CrossingCard.swift`
- Modify: `Marginalia/Design/Glyphs.swift` — add `crossing`
- Modify: `Marginalia/Model/RowMapping.swift` — `CrossingCardData` from a `Crossing`
- Test: `MarginaliaTests/RowMappingTests.swift`

**Interfaces:**
- Consumes: `CrossingFinder.Crossing` (task 2), `RelativeTime.gap` (task 1), `NoteRowData` (`Design/Components/Rows.swift`).
- Produces:
  - `CrossingCardData` — `let a: NoteRowData`, `let b: NoteRowData`, `let gap: String`
  - `CrossingCardData.init(_ crossing: CrossingFinder.Crossing, now: Date = .now, calendar: Calendar = .current)` — orders the halves oldest first
  - `CrossingCard(crossing: CrossingCardData, rejected: Bool, onOpen: (Int) -> Void, onReject: () -> Void)`
  - `Glyphs.crossing` — `"[◇]"`

- [ ] **Step 1: Add the glyph**

In `Marginalia/Design/Glyphs.swift`, in the `// MARK: Actions` section, after `followUp`:

```swift
    /// Two notes from two books that say the same thing. The mark the map tab
    /// wore before it was deleted — the vocabulary doesn't grow, it moves.
    static let crossing = "[◇]"
```

Leave `tabMap` alone for now; task 5 removes it.

- [ ] **Step 2: Write the failing test**

Append to `MarginaliaTests/RowMappingTests.swift`, inside the existing test struct:

```swift
    // MARK: A crossing

    /// Oldest first, whichever end of the edge it happens to be. The card
    /// narrates a gap in time and a gap reads forward.
    @Test func aCrossingPutsTheOlderNoteFirst() {
        let calendar = Calendar(identifier: .gregorian)
        let older = Note(shortID: 3, text: "older", createdAt: Date(timeIntervalSince1970: 1_000_000),
                         book: Book(title: "Norman"))
        let newer = Note(shortID: 9, text: "newer", createdAt: Date(timeIntervalSince1970: 9_000_000),
                         book: Book(title: "Pirsig"))

        // `from` is the newer note, so the init has to reorder rather than copy.
        let edge = NoteEdge(from: newer, to: older, score: 0.6)
        let data = CrossingCardData(
            CrossingFinder.Crossing(edge: edge, a: newer, b: older),
            now: Date(timeIntervalSince1970: 9_000_000),
            calendar: calendar
        )

        #expect(data.a.id == 3)
        #expect(data.b.id == 9)
        #expect(data.gap == RelativeTime.gap(from: older.createdAt, to: newer.createdAt,
                                             calendar: calendar))
    }

    @Test func aCrossingCarriesEachNotesSourceLine() {
        let a = Note(shortID: 1, text: "a", book: Book(title: "Norman"))
        let b = Note(shortID: 2, text: "b", book: Book(title: "Pirsig"))
        let data = CrossingCardData(
            CrossingFinder.Crossing(edge: NoteEdge(from: a, to: b, score: 0.6), a: a, b: b)
        )

        #expect(data.a.source.contains("Norman"))
        #expect(data.b.source.contains("Pirsig"))
    }
```

- [ ] **Step 3: Run it and watch it fail**

```bash
xcodebuild -scheme Marginalia -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .build test -only-testing:MarginaliaTests/RowMappingTests 2>&1 | tail -30
```

Expected: compile failure — `cannot find 'CrossingCardData' in scope`.

- [ ] **Step 4: Write the view and the data it takes**

Create `Marginalia/Features/Review/CrossingCard.swift`:

```swift
import SwiftUI

/// What a crossing card needs to draw itself. Two notes and the distance
/// between them — no edge, no score, no model, like every other row type.
struct CrossingCardData {
    /// The older of the two. A gap reads forward.
    let a: NoteRowData
    let b: NoteRowData
    /// `7 months apart`.
    let gap: String
}

/// Two notes from two books that say the same thing, filling one screen of the
/// daily review.
///
/// **Centred and open like `ReviewCard`, and for the same reason** — the margin
/// belongs to the stream and book detail, where a row is one of many.
///
/// **A hairline between the halves, never an arrow.** `NoteEdge` stores a
/// direction and the app has displayed both ways since phase 6; a `→` here would
/// be the first place it contradicted that.
struct CrossingCard: View {
    let crossing: CrossingCardData
    /// True once the reader has said the pair isn't one. The card stays where it
    /// is and the action becomes a past tense — see `ReviewView.rejected`.
    let rejected: Bool
    let onOpen: (Int) -> Void
    let onReject: () -> Void

    /// How tall the card turned out. A vertical scroll view nested inside the
    /// vertical *paging* scroll view swallows the page gesture, so this one only
    /// scrolls when it has something to scroll to — `ReviewCard` carries the
    /// same guard and the note above it explains what it cost to learn.
    @State private var content: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                card
                    .frame(minHeight: proxy.size.height)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { content = $0 }
            }
            .scrollDisabled(content <= proxy.size.height + 0.5)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(crossing.a.idLabel) · \(crossing.b.idLabel) · \(Glyphs.crossing) crossing")
                .font(Typography.meta)
                .foregroundStyle(Theme.textAsh)

            half(crossing.a)
            Hairline()
            half(crossing.b)

            foot
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }

    /// **`noteBody`, not `reviewBody`.** Every other review card is one note
    /// filling the screen and gets 18pt; this one is two, and at 18pt each the
    /// second half is below the fold before the reader has a reason to look for
    /// it. The gap is the point of the card and both halves have to be on it.
    private func half(_ note: NoteRowData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(note.text)
                .font(Typography.noteBody)
                .lineSpacing(Typography.bodyLeading)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if !note.source.isEmpty {
                Text("— \(note.source)")
                    .font(Typography.source)
                    .foregroundStyle(Theme.textMute)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        // Everything a note can do — star, add a thought — is where the note
        // is. The card doesn't duplicate six actions for two notes; it opens
        // them. `ActionRow`'s own note records that four labels already
        // overflow a phone at 13pt mono.
        .onTapGesture { onOpen(note.id) }
    }

    private var foot: some View {
        HStack(spacing: 20) {
            Text(crossing.gap)
                .font(Typography.source)
                .foregroundStyle(Theme.textMute)

            if rejected {
                Text("disconnected")
                    .font(Typography.source)
                    .foregroundStyle(Theme.textAsh)
            } else {
                // The first feedback loop in the linking system: the app has
                // guessed at meaning since phase 6 and nothing anywhere could
                // tell it it was wrong. An affordance, never a question —
                // skipping it is free, and `docs/decisions.md` §10's promise
                // that nobody is asked to link anything is unbroken.
                MarkerButton(title: "\(Glyphs.close) not related", kind: .link, action: onReject)
            }

            Spacer(minLength: 0)
        }
    }
}
```

- [ ] **Step 5: Add the mapping**

At the end of `Marginalia/Model/RowMapping.swift`, add:

```swift
extension CrossingCardData {

    /// **Oldest first**, whichever end of the edge it came from. The card
    /// narrates a distance in time and a distance reads forward — `n.03` in
    /// august, then `n.19` in march, then `7 months apart` under both.
    init(
        _ crossing: CrossingFinder.Crossing,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        let ordered = crossing.a.createdAt <= crossing.b.createdAt
            ? (crossing.a, crossing.b)
            : (crossing.b, crossing.a)

        self.init(
            a: NoteRowData(ordered.0, now: now, calendar: calendar),
            b: NoteRowData(ordered.1, now: now, calendar: calendar),
            gap: RelativeTime.gap(from: ordered.0.createdAt, to: ordered.1.createdAt,
                                  calendar: calendar)
        )
    }
}
```

- [ ] **Step 6: Run the tests and watch them pass**

```bash
xcodebuild -scheme Marginalia -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .build test -only-testing:MarginaliaTests/RowMappingTests 2>&1 | tail -20
```

Expected: all `RowMappingTests` pass, the two new ones included.

- [ ] **Step 7: Commit**

```bash
git add Marginalia/Features/Review/CrossingCard.swift Marginalia/Design/Glyphs.swift \
        Marginalia/Model/RowMapping.swift MarginaliaTests/RowMappingTests.swift
git commit -m "The crossing card — two notes, two books, and the gap between them"
```

---

### Task 4: Wire it into review

The composition, the index arithmetic that a ninth card changes, and the confirmation.

**Files:**
- Modify: `Marginalia/Features/Review/ReviewView.swift`
- Modify: `Marginalia/MarginaliaApp.swift` — `ReviewView` gains `onOpenNote`

**Interfaces:**
- Consumes: `CrossingFinder.pick` (task 2), `CrossingCard` / `CrossingCardData` (task 3), `Erasure.connection` and `.confirming(_:in:after:)` (both already in `Model/Eraser.swift`), `LinkWriter.relink(in:)`.
- Produces: `ReviewView(card:onOpenBook:onOpenNote:)` — note that `onOpenWeb` is **still present** at the end of this task and is removed in task 5.

- [ ] **Step 1: Add the state and the parameter**

In `Marginalia/Features/Review/ReviewView.swift`, after `let onOpenWeb: (Int) -> Void`:

```swift
    /// Opening one half of a crossing. Everything a note can do lives where the
    /// note is, so the card routes there rather than growing six more actions.
    let onOpenNote: (Int) -> Void
```

And after `@State private var linking: Note?`:

```swift
    /// The day's crossing, or `nil` on a library that has none — in which case
    /// review is exactly what it was before this card existed. Built once beside
    /// `today` and held, for the same reason `today` is.
    @State private var crossing: CrossingFinder.Crossing?

    /// Whether the reader has disconnected it. **The card stays on screen.**
    /// Removing it would take a page out of the paging scroll view while the
    /// reader is standing on that page — the same class of feedback loop that
    /// made the end of the set stick in phase 11. The suppression is recorded
    /// either way and the card is gone tomorrow.
    @State private var rejected = false

    /// The disconnect confirmation. Every delete in the app goes through this
    /// one door, and `Erasure.connection` already writes the sentence.
    @State private var erasing: Erasure?
```

- [ ] **Step 2: Add the card to the pager and fix the arithmetic**

In `cards`, replace the `ClosingCard` block with the crossing card followed by it:

```swift
                if let crossing {
                    CrossingCard(
                        crossing: CrossingCardData(crossing),
                        rejected: rejected,
                        onOpen: onOpenNote,
                        onReject: { erasing = .connection(crossing.edge) }
                    )
                    .containerRelativeFrame(.vertical)
                    .id(today.count)
                }

                ClosingCard(remaining: more) { keepGoing() }
                    .containerRelativeFrame(.vertical)
                    .id(lastIndex)
```

Then replace `atEnd` and add `lastIndex` in the `// MARK: Where you are` section:

```swift
    /// The closing card's slot. `keepGoing()` grows `today`, so this is computed
    /// rather than stored — and the crossing card sits at `today.count`, one
    /// above the last note and one below the end.
    private var lastIndex: Int { today.count + (crossing == nil ? 0 : 1) }

    /// **Not `index >= today.count`.** With a crossing on screen there is still
    /// a card below it, and hiding the hint there would say the set had ended
    /// one page early.
    private var atEnd: Bool { index >= lastIndex }
```

- [ ] **Step 3: Build the crossing when the set is built, and confirm through the one door**

In `open()`, after `more = hasMore`:

```swift
            crossing = CrossingFinder.pick(from: edges, on: .now,
                                           avoiding: Set(today.map(\.shortID)))
```

Add `.confirming` to the `body`'s modifier chain, immediately after `.background(Theme.canvas)`:

```swift
        .confirming($erasing, in: context, after: disconnected)
```

And add the handler beside `keepGoing()`:

```swift
    /// The reader said the pair isn't one. `Eraser.suppress` has already run —
    /// this is what happens after.
    ///
    /// **The card is not removed and the crossing is not re-picked.** Both would
    /// change the paging scroll view's page count under a thumb resting on that
    /// exact page, which is the shape of defect phase 11 spent a stage on. The
    /// foot says `disconnected` instead, the suppression is permanent, and
    /// tomorrow's pick can't return the pair — `CrossingFinder.all` skips
    /// suppressed edges.
    private func disconnected() {
        rejected = true
        // A suppressed edge frees degree budget, and the next full recompute
        // hands it to somebody else. `LinkWriter` is the only path an edge takes
        // to exist, here as everywhere.
        Task { try? await LinkWriter.relink(in: context) }
    }
```

- [ ] **Step 4: Note why surfacing already does the right thing, and add the launch argument**

In the `.onChange(of: position)` block, extend the comment above the existing guard:

```swift
            // **Paging past a crossing surfaces nothing**, and this guard
            // already does it: the crossing card's index is `today.count`, so it
            // fails the bound. That is deliberate rather than lucky — marking
            // both its notes surfaced would quietly reshape tomorrow's eight,
            // because `lastSurfacedAt` is exactly what `ReviewSetBuilder` scores
            // on, and the crossing is extra rather than part of the set.
            guard let previous, previous < today.count else { return }
```

In `openAtLaunch()`, replace the `reviewEnd` line and add the new argument:

```swift
        // `-reviewCrossing 1` opens on the crossing, which is otherwise reachable
        // only by swiping past all eight — and the simulator can't be swiped.
        if defaults.bool(forKey: "reviewCrossing"), crossing != nil { position = today.count }
        if defaults.bool(forKey: "reviewEnd") { position = lastIndex }
```

- [ ] **Step 5: Pass `onOpenNote` from the root**

In `Marginalia/MarginaliaApp.swift`, change the review case:

```swift
                    case .review:
                        ReviewView(card: $card, onOpenBook: open, onOpenWeb: openWeb,
                                   onOpenNote: open)
```

- [ ] **Step 6: Build and run the whole suite**

```bash
xcodebuild -scheme Marginalia -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .build build test 2>&1 | tail -25
```

Expected: build succeeds and all tests pass — 402 plus the new ones, nothing deleted yet.

- [ ] **Step 7: Look at it**

```bash
xcrun simctl boot "iPhone 17" 2>/dev/null || true
xcrun simctl install booted .build/Build/Products/Debug-iphonesimulator/Marginalia.app
xcrun simctl ui booted appearance light
xcrun simctl launch booted com.passim.app -startTab review -reviewCrossing 1
sleep 3 && xcrun simctl io booted screenshot /tmp/crossing-light.png
```

Then `Read` `/tmp/crossing-light.png` and **actually look at it**. Confirm: two notes are on one screen, a hairline separates them, the head reads `n.xx · n.yy · [◇] crossing`, and the foot reads `<n> months apart · [x] not related`.

**If no crossing card appears**, the seed library has no unsuppressed cross-book edge on this launch. Check with:

```bash
TEST_RUNNER_MARGINALIA_DUMP=1 xcodebuild -scheme Marginalia \
  -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath .build \
  test -only-testing:MarginaliaTests/AffinityDumpTests 2>&1 | grep '^|' | head -30
```

Report it rather than working around it — a seed with no crossing is a finding about `SeedLibrary`, not a bug in this task.

- [ ] **Step 8: Commit**

```bash
git add Marginalia/Features/Review/ReviewView.swift Marginalia/MarginaliaApp.swift
git commit -m "The crossing card lands in the daily review

One a day, between the eight notes and the closing card. Surfacing
already skips it; the card stays put when disconnected rather than
taking a page out of the pager under the reader's thumb."
```

---

### Task 5: The map comes out

2,764 lines of app code, 1,230 lines of tests, 92 `@Test` cases, one tab and eight launch arguments.

**Files:**
- Delete: `Marginalia/Features/Map/` (all six files), `Marginalia/Services/ThemeEngine.swift`, `ThemeName.swift`, `NounPhrases.swift`, `GraphLayout.swift`
- Delete: `MarginaliaTests/MapGraphTests.swift`, `GraphLayoutTests.swift`, `ThemeEngineTests.swift`, `ThemeNameTests.swift`, `ThemeDumpTests.swift`, `ThemeIsolationTests.swift`
- Modify: `Marginalia/Design/Components/Chrome.swift`, `Rows.swift`, `Marginalia/Design/Glyphs.swift`, `Typography.swift`, `Marginalia/MarginaliaApp.swift`, `Marginalia/Features/Stream/StreamView.swift`, `Marginalia/Features/Review/ReviewView.swift`, `ReviewCard.swift`

**Interfaces:**
- Consumes: everything tasks 1–4 built.
- Produces: `Tab` with three cases; `ReviewView(card:onOpenBook:onOpenNote:)`; `StreamView(focus:capturing:onSearch:onSettings:)`; `NoteRow` without `onConnections`; `ReviewActions` without `openWeb`.

- [ ] **Step 1: Delete the files**

```bash
git rm -r Marginalia/Features/Map
git rm Marginalia/Services/ThemeEngine.swift Marginalia/Services/ThemeName.swift \
       Marginalia/Services/NounPhrases.swift Marginalia/Services/GraphLayout.swift
git rm MarginaliaTests/MapGraphTests.swift MarginaliaTests/GraphLayoutTests.swift \
       MarginaliaTests/ThemeEngineTests.swift MarginaliaTests/ThemeNameTests.swift \
       MarginaliaTests/ThemeDumpTests.swift MarginaliaTests/ThemeIsolationTests.swift
```

Do **not** touch `project.pbxproj` — the project uses synchronized file groups and removals are picked up automatically.

- [ ] **Step 2: Three tabs**

In `Marginalia/Design/Components/Chrome.swift`, remove `map` from the enum and both switches:

```swift
enum Tab: CaseIterable {
    case stream, books, review

    var label: String {
        switch self {
        case .stream: "stream"
        case .books: "books"
        case .review: "review"
        }
    }
```

and in `glyph`, delete the `case .map: Glyphs.tabMap` line.

- [ ] **Step 3: Drop the dead glyphs and fonts**

In `Marginalia/Design/Glyphs.swift`, delete `static let tabMap = "[◇]"` from the `// MARK: Tabs` block. `Glyphs.crossing` (task 3) is now the only `[◇]` in the app.

Also delete `Glyphs.bookHub(_:limit:)` entirely — it existed to label a graph node and nothing draws one any more.

In `Marginalia/Design/Typography.swift`, delete `mapNode`, `mapNodeStrong`, `mapNodeHeavy` and `mapHub`.

- [ ] **Step 4: Unwire the cross-tab route**

In `Marginalia/MarginaliaApp.swift`:
- Delete the `@State private var web: Int?` declaration and its doc comment.
- Delete the whole `private func openWeb(_ shortID: Int)` function.
- Delete `case .map: MapView(note: $web, onOpenNote: open, onOpenBook: open)`.
- Change the stream case to `StreamView(focus: $focus, capturing: $capturing, onSearch: { screen = .search }, onSettings: { screen = .settings })`.
- Change the review case to `ReviewView(card: $card, onOpenBook: open, onOpenNote: open)`.

- [ ] **Step 5: Remove `[◇] connections` from both places it is offered**

In `Marginalia/Design/Components/Rows.swift`, delete the `onConnections` property from `NoteRow` (with its doc comment) and the `if let onConnections { … }` block from the `.contextMenu`.

In `Marginalia/Features/Stream/StreamView.swift`, delete `let onOpenWeb: (Int) -> Void` and the `onConnections: { onOpenWeb(note.shortID) },` argument at the `NoteRow` call site.

In `Marginalia/Features/Review/ReviewCard.swift`, delete `let openWeb: () -> Void` from `ReviewActions` (with its doc comment) and the third `HStack` in `ActionRow` that carries `[◇] connections`, moving `→ link` up into the second row beside `share`. Update `ActionRow`'s doc comment — it says "six actions is three rows"; it is now five in two, and `→ open book` · `share` · `→ link` is three labels in the second row, which the same arithmetic forbids. Put `→ link` in its own row:

```swift
            HStack(spacing: 20) {
                MarkerButton(title: "\(Glyphs.forward) link", kind: .link, action: actions.link)
                Spacer(minLength: 0)
            }
```

In `Marginalia/Features/Review/ReviewView.swift`, delete `let onOpenWeb: (Int) -> Void` and the `openWeb: { onOpenWeb(note.shortID) },` line from `actions(for:connections:)`.

- [ ] **Step 6: Build and run the whole suite on both runtimes**

```bash
xcodebuild -scheme Marginalia -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .build build test 2>&1 | tail -25
xcodebuild -scheme Marginalia -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' \
  -derivedDataPath .build-ios18 build test 2>&1 | tail -25
```

Expected: both build and pass. The count drops from ~410 to ~318. If the compiler names a symbol from a deleted file that this plan did not list, fix it and **say so in the commit** — the plan's grep missed it.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "The map comes out

2,764 lines of app code and 92 tests. The tab, the themes, the graph,
GraphLayout, ThemeEngine, ThemeName, NounPhrases — and the cross-tab
route and both [◇] connections entry points that fed them.

Three tabs: stream, books, review. Closes issues §24 and §17."
```

---

### Task 6: The documentation

The repo's docs are load-bearing — `CLAUDE.md` tells the next session what the app is, and it currently describes a tab that no longer exists.

**Files:**
- Modify: `CLAUDE.md`, `docs/decisions.md`, `docs/issues.md`, `docs/planning.md`, `docs/design-system.md`, `docs/phase-11.md`
- Create: `docs/phase-12.md`

- [ ] **Step 1: `docs/decisions.md` §21**

Append a new section. It supersedes §11, §19 and §20, and it must say the thing that is actually true rather than the flattering version: §20 answered "the map isn't legible" by rebuilding it, and legibility was never the problem. Condense `docs/specs/2026-08-18-crossings-design.md` — the premise (a device read said *no reason to open it*, not *the themes are wrong*), why a better embedder could not have fixed that, the crossing card, `[x] not related` as the system's first feedback loop, and the recorded argument against (§20 was one day old).

- [ ] **Step 2: `CLAUDE.md`**

- The four-tab list at the top becomes three; delete the `map` bullet and add the crossing card to the `review` bullet.
- Delete the whole `## The map — a summary first, a graph second` section.
- In `## Linking — automatic`, add a line: automatic linking now has exactly one place a reader can contradict it, `[x] not related` on a crossing card, and it writes `isSuppressed` through `Eraser` like every other delete.
- In `## Keep these pure`, delete `ThemeEngine`, `ThemeName` and `GraphLayout`; add `CrossingFinder` — *edges + a date → the day's crossing. Ranked, rotated, never thresholded*.
- In the file map, delete `Features/Map/`, the four deleted services and the map lines under `Design/`; add `CrossingFinder` and `CrossingCard` under `Review/`.
- In the launch-argument table, delete the eight `-map*` rows and `-startTab map`; add `-reviewCrossing 1`; change `-confirmDelete connection` to say it opens over the crossing card in review rather than with `-startTab map`.
- In `## Working notes`, keep the `Task.isCancelled` note (it is a general rule and the map was only its example) but reword it so it does not claim the map still exists.

- [ ] **Step 3: `docs/issues.md`**

- Mark **§24** and **§17** closed, each with one line saying the screen was deleted rather than the bug fixed.
- **Leave §14 and §6 open**, and add a sentence to §14: the device read still matters because backlinks and crossings ride on the same scores, but it is no longer a gate on a whole tab.
- In `## What I'd change, in order`, strike row 13 (hit-test the map by nearest node).

- [ ] **Step 4: `docs/planning.md` and `docs/design-system.md`**

In `docs/planning.md`, replace the map section with the crossing card and mark what phase 12 did. In `docs/design-system.md`, delete the graph, node and hub entries; add the crossing card beside the review card, describing the two halves at `noteBody`, the hairline between them and the foot.

- [ ] **Step 5: `docs/phase-11.md` and `docs/phase-12.md`**

In `docs/phase-11.md`, mark stage 3's two remaining items closed by deletion. Create `docs/phase-12.md` in the same shape: what was found, what was built, what was deleted, and what still can't be checked here (whether a crossing is *true* — the device, unchanged).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "Phase 12 docs: decisions §21, and the map out of every file that described it"
```

---

### Task 7: Verification

The app has five defects on record that were invisible in code review and obvious in a picture. This task is the picture.

**Files:** none — this task changes nothing unless it finds something.

- [ ] **Step 1: Both runtimes, clean**

```bash
xcodebuild -scheme Marginalia -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .build build test 2>&1 | tail -15
xcodebuild -scheme Marginalia -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' \
  -derivedDataPath .build-ios18 build test 2>&1 | tail -15
```

Record the exact test count in the final report. Do not round it and do not say "all tests pass" without the number beside it.

- [ ] **Step 2: The crossing card in both appearances**

```bash
xcrun simctl install booted .build/Build/Products/Debug-iphonesimulator/Marginalia.app
for mode in light dark; do
  xcrun simctl ui booted appearance $mode
  xcrun simctl launch booted com.passim.app -startTab review -reviewCrossing 1
  sleep 3 && xcrun simctl io booted screenshot /tmp/crossing-$mode.png
done
```

`Read` both. Look at the **whole image**, not the part that changed.

- [ ] **Step 3: `accessibility-extra-extra-extra-large` — where this is expected to break**

```bash
xcrun simctl ui booted content_size accessibility-extra-extra-extra-large
xcrun simctl ui booted appearance light
xcrun simctl launch booted com.passim.app -startTab review -reviewCrossing 1
sleep 3 && xcrun simctl io booted screenshot /tmp/crossing-ax5.png
xcrun simctl ui booted content_size large
```

Note the underscore — `content-size` is not the option name and prints the usage.

`Read` `/tmp/crossing-ax5.png`. **Two full notes on one screen is the first card in this app designed to hold two.** Confirm the inner scroll engages rather than the content clipping, and that the foot (`7 months apart · [x] not related`) is reachable. If either half is cut off with no way to scroll to it, that is a real defect — report it rather than shipping it.

- [ ] **Step 4: The three-tab bar, and the review card without `[◇] connections`**

```bash
xcrun simctl launch booted com.passim.app -startTab review -reviewCard 1
sleep 3 && xcrun simctl io booted screenshot /tmp/review-card.png
xcrun simctl launch booted com.passim.app -confirmDelete connection -startTab review -reviewCrossing 1
sleep 3 && xcrun simctl io booted screenshot /tmp/disconnect.png
```

`Read` both: the tab bar has three items and they are evenly spaced; `ActionRow` is five actions in three rows with nothing overflowing; the confirmation reads **`disconnect n.03 and n.19?`** over "both notes stay where they are — only the line between them goes. the app won't suggest this pair again.", with `[x] disconnect` as the filled button. That is `Erasure.connection`'s existing wording verbatim — if it reads any other way, something re-authored a sentence that already existed.

- [ ] **Step 5: Report**

State plainly: the test count on both runtimes, which screenshots were looked at, what each one showed, and anything found. **If something is broken, say so with the output** — a defect found here is the task working.

- [ ] **Step 6: Commit anything the pass fixed**

```bash
git add -A && git commit -m "Phase 12: what the screenshots found"
```

Skip this step entirely if the pass found nothing — an empty commit says something happened that didn't.

---

## Self-Review

**Spec coverage.** Every section of `docs/specs/2026-08-18-crossings-design.md` maps to a task: the card → 3, its one action → 3 and 4, when it appears (one a day, appended, day-stable rotating, avoiding the day's ids, surfacing nothing) → 2 and 4, `CrossingFinder`'s five rules → 2, `RelativeTime.gap` → 1, what comes out → 5, what survives → untouched by construction, what closes → 6, verification → 7.

**Type consistency.** `CrossingFinder.Crossing` carries `edge`/`a`/`b` in tasks 2, 3 and 4 alike; `CrossingCardData` is `a`/`b`/`gap` in tasks 3 and 4; `RelativeTime.gap(from:to:calendar:)` has one signature in tasks 1 and 3; `ReviewView`'s parameter list is stated at the end of task 4 (with `onOpenWeb`) and again at the end of task 5 (without it), because that is when it changes.

**Known ordering constraint.** Task 3 adds `Glyphs.crossing` beside `Glyphs.tabMap` rather than renaming it, so the app builds between tasks 3 and 5. Task 5 removes `tabMap`. Do not collapse these.
