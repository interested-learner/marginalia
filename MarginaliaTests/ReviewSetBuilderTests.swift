import Testing
import Foundation
@testable import Marginalia

/// The day's review set. Pure — plain notes and a date in, notes out — which is
/// what makes every rule in it assertable without a container.
///
/// The rules come from `docs/specs/2026-08-13-marginalia-design.md` §Review set
/// algorithm: day-stable, at most 8, at most 2 per book, starred weighted up,
/// and at least one from a book currently being read.
@MainActor
struct ReviewSetBuilderTests {

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

    /// A library of `count` notes spread over `books`, none ever surfaced.
    private func library(_ count: Int, across books: [Book]) -> [Note] {
        (0..<count).map { index in
            Note(shortID: index + 1, text: "note \(index + 1)",
                 book: books[index % books.count])
        }
    }

    private func ids(_ notes: [Note]) -> [Int] { notes.map(\.shortID) }

    private func set(_ notes: [Note], on offset: Int, limit: Int = ReviewSetBuilder.dailyLimit,
                     excluding shown: Set<Int> = []) -> [Note] {
        ReviewSetBuilder.set(from: notes, on: day(offset), calendar: calendar,
                             limit: limit, excluding: shown)
    }

    // MARK: Day stability

    /// Leaving review and coming back must not reshuffle the set — that's what
    /// makes it a ritual with an end rather than another infinite feed.
    @Test func theSameDayAlwaysYieldsTheSameSet() {
        let notes = library(20, across: [book("a"), book("b"), book("c"), book("d")])
        let morning = ReviewSetBuilder.set(from: notes, on: day(0), calendar: calendar)
        let evening = ReviewSetBuilder.set(from: notes,
                                           on: day(0).addingTimeInterval(6 * 3_600),
                                           calendar: calendar)
        #expect(ids(morning) == ids(evening))
    }

    /// …and the next day has to be worth opening.
    @Test func adifferentDayYieldsADifferentSet() {
        let notes = library(30, across: [book("a"), book("b"), book("c"), book("d")])
        let week = (0..<7).map { Set(ids(set(notes, on: $0))) }
        #expect(Set(week).count > 1)
    }

    /// The order a set reads in is fixed too, not just its membership.
    @Test func theOrderIsStableWithinADay() {
        let notes = library(20, across: [book("a"), book("b"), book("c"), book("d")])
        #expect(ids(set(notes, on: 3)) == ids(set(notes, on: 3)))
    }

    // MARK: Caps

    @Test func theSetIsCappedAtEight() {
        let notes = library(40, across: (1...10).map { book("book \($0)") })
        #expect(set(notes, on: 0).count == 8)
    }

    /// Otherwise a day's review is four notes from whatever you read last week.
    @Test func atMostTwoNotesComeFromOneBook() {
        let notes = library(40, across: [book("a"), book("b"), book("c"), book("d")])
        let counts = Dictionary(grouping: set(notes, on: 0)) { $0.book?.title ?? "" }
        #expect(counts.values.allSatisfy { $0.count <= 2 })
    }

    @Test func aLibrarySmallerThanTheCapReturnsWhatItHas() {
        let notes = library(4, across: [book("a"), book("b")])
        #expect(set(notes, on: 0).count == 4)
    }

    @Test func anEmptyLibraryReturnsNothing() {
        #expect(ReviewSetBuilder.set(from: [], on: day(0), calendar: calendar).isEmpty)
    }

    /// A note with no book is an Inbox note in practice, but the builder is pure
    /// and takes whatever it's given. Two of them must not become unlimited.
    @Test func notesWithNoBookShareOneBudget() {
        let notes = (1...6).map { Note(shortID: $0, text: "unfiled \($0)") }
        #expect(set(notes, on: 0).count == 2)
    }

    // MARK: Scoring

    /// Never surfaced ranks highest — the whole point is running into thinking
    /// you haven't seen in a while.
    @Test func aNeverSurfacedNoteOutranksOneSurfacedYesterday() {
        let shelf = book("a")
        let fresh = Note(shortID: 1, text: "never seen", book: shelf)
        let recent = Note(shortID: 2, text: "seen yesterday", book: shelf)
        recent.lastSurfacedAt = day(0).addingTimeInterval(-86_400)

        #expect(ids(set([fresh, recent], on: 0, limit: 1)) == [1])
    }

    /// `[*] star` is the honest version of "keep" — a starred note comes back
    /// sooner than an identical unstarred one.
    @Test func aStarredNoteOutranksAnIdenticalUnstarredOne() {
        let shelf = book("a")
        let plain = Note(shortID: 1, text: "plain", book: shelf)
        let starred = Note(shortID: 2, text: "starred", isStarred: true, book: shelf)
        plain.lastSurfacedAt = day(0).addingTimeInterval(-30 * 86_400)
        starred.lastSurfacedAt = day(0).addingTimeInterval(-30 * 86_400)

        #expect(ids(set([plain, starred], on: 0, limit: 1)) == [2])
    }

    /// A star weights a note up; it doesn't pin it to the top forever. A note
    /// unseen for a year still beats a starred one read this morning.
    @Test func aStarDoesNotOutweighAYearOfNotBeingSeen() {
        let shelf = book("a")
        let forgotten = Note(shortID: 1, text: "forgotten", book: shelf)
        let starred = Note(shortID: 2, text: "starred", isStarred: true, book: shelf)
        forgotten.lastSurfacedAt = day(0).addingTimeInterval(-365 * 86_400)
        starred.lastSurfacedAt = day(0)

        #expect(ids(set([forgotten, starred], on: 0, limit: 1)) == [1])
    }

    // MARK: Currently reading

    /// Review is worth opening because it talks about the book in your hand.
    @Test func aBookBeingReadIsAlwaysRepresented() {
        let notes = library(20, across: (1...10).map { book("finished \($0)") })
        let current = Note(shortID: 99, text: "from the book in your hand",
                           book: book("in progress", .reading))
        current.lastSurfacedAt = day(0)      // the worst possible score

        let today = set(notes + [current], on: 0)
        #expect(today.contains { $0.shortID == 99 })
        #expect(today.count == 8)
    }

    /// Making room for it must not break the other two rules.
    @Test func makingRoomForTheCurrentBookKeepsThePerBookCap() {
        let notes = library(20, across: [book("a"), book("b")])
        let current = Note(shortID: 99, text: "current", book: book("in progress", .reading))
        current.lastSurfacedAt = day(0)

        let today = set(notes + [current], on: 0)
        let counts = Dictionary(grouping: today) { $0.book?.title ?? "" }
        #expect(counts.values.allSatisfy { $0.count <= 2 })
    }

    /// When nothing is being read the rule simply doesn't apply — it must not
    /// cost the set a card looking for something that isn't there.
    @Test func aLibraryWithNothingBeingReadStillBuildsASet() {
        let shelf = (1...5).map { book("finished \($0)", .finished) }
                 + (1...5).map { book("queued \($0)", .queued) }
        #expect(set(library(20, across: shelf), on: 0).count == 8)
    }

    /// The per-book cap binds before the total does in a small library, and the
    /// set is however many that leaves rather than eight padded out.
    @Test func twoBooksCanOnlyEverFillFourCards() {
        #expect(set(library(20, across: [book("a"), book("b")]), on: 0).count == 4)
    }

    // MARK: Building a set changes nothing

    /// `lastSurfacedAt` is written only when a card is actually paged past.
    /// Building a set must not change what future sets look like.
    @Test func buildingASetSurfacesNothing() {
        let notes = library(20, across: [book("a"), book("b"), book("c"), book("d")])
        _ = set(notes, on: 0)
        #expect(notes.allSatisfy { $0.lastSurfacedAt == nil && $0.surfaceCount == 0 })
    }

    // MARK: Keep going

    /// `[↻] keep going` extends past the day's eight rather than starting over.
    @Test func keepGoingReturnsNotesTheDaysSetDidNotShow() {
        let notes = library(40, across: (1...10).map { book("book \($0)") })
        let today = set(notes, on: 0)
        let more = set(notes, on: 0, excluding: Set(ids(today)))

        #expect(more.count == 8)
        #expect(Set(ids(more)).isDisjoint(with: Set(ids(today))))
    }

    /// A library with nothing left to show ends rather than repeating itself.
    @Test func keepGoingRunsOutRatherThanRepeating() {
        let notes = library(10, across: [book("a"), book("b"), book("c"), book("d"), book("e")])
        let today = set(notes, on: 0)
        let more = set(notes, on: 0, excluding: Set(ids(today)))
        let evenMore = set(notes, on: 0, excluding: Set(ids(today) + ids(more)))

        #expect(more.count == 2)
        #expect(evenMore.isEmpty)
    }
}
