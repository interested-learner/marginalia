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

    /// The empty case above only proves `pick` handles no edges at all. This
    /// proves the narrower thing: edges can exist and still yield no card, when
    /// none of them crosses books.
    @Test func edgesWithNoCrossingMeansNoCard() {
        let one = book("Norman")
        let edges = [edge(note(1, in: one), note(2, in: one), 0.9)]
        #expect(CrossingFinder.pick(from: edges, on: day(0), calendar: calendar) == nil)
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

    // MARK: Finding one back by its pair

    /// How a stored session gets its ninth card back. `docs/decisions.md` §4:
    /// the day's set is fixed per calendar day, and the crossing is card nine
    /// of it.
    @Test func findReturnsTheCrossingForApair() {
        let one = book("Norman"), two = book("Pirsig")
        let a = note(1, in: one), b = note(2, in: two)

        let found = CrossingFinder.find(pair: (1, 2), in: [edge(a, b, 0.6)])

        #expect(found?.a.shortID == 1)
        #expect(found?.b.shortID == 2)
    }

    /// `NoteEdge` stores a direction and the app has never displayed one, so
    /// which end was stored first cannot decide whether the card comes back.
    @Test func findMatchesThePairInEitherOrder() {
        let one = book("Norman"), two = book("Pirsig")
        let edges = [edge(note(1, in: one), note(2, in: two), 0.6)]

        #expect(CrossingFinder.find(pair: (2, 1), in: edges) != nil)
    }

    /// **Unlike `all`, which skips suppressed edges.** A crossing the reader
    /// disconnected keeps its slot for the rest of the day — `ReviewView`
    /// refuses to remove the card or re-pick the pair within a session, and
    /// coming back from another tab must not put a fresh claim under a thumb
    /// that just answered the question.
    @Test func findStillReturnsAsuppressedCrossing() {
        let one = book("Norman"), two = book("Pirsig")
        let edges = [edge(note(1, in: one), note(2, in: two), 0.6, suppressed: true)]

        #expect(CrossingFinder.all(from: edges).isEmpty)
        #expect(CrossingFinder.find(pair: (1, 2), in: edges) != nil)
    }

    @Test func findReturnsNothingForApairThatIsNotConnected() {
        let one = book("Norman"), two = book("Pirsig")
        let edges = [edge(note(1, in: one), note(2, in: two), 0.6)]

        #expect(CrossingFinder.find(pair: (1, 3), in: edges) == nil)
    }

    /// `Eraser` exists because a deleted note leaves its edges with one end
    /// nil, and an edge with one end missing can never be drawn.
    @Test func findReturnsNothingForAdanglingEdge() {
        let dangling = NoteEdge(from: nil, to: nil, score: 0.6)

        #expect(CrossingFinder.find(pair: (1, 2), in: [dangling]) == nil)
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
