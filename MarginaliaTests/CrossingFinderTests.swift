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

    /// Showing nothing on a small library is worse than showing `n.03` twice. The fallback is the full ranked list, still rotating — not a pin to the strongest, which would repeat one pair daily.
    @Test func itStillShowsACrossingWhenEveryCandidateOverlaps() {
        let edges = threeCrossings()
        let avoided = Set(1...6)

        var picked = Set<Int>()
        for offset in 0..<6 {
            let crossing = CrossingFinder.pick(from: edges, on: day(offset),
                                               calendar: calendar, avoiding: avoided)
            #expect(crossing != nil)
            if let crossing {
                picked.insert(crossing.a.shortID)
                picked.insert(crossing.b.shortID)
            }
        }
        #expect(picked.count > 2)
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
