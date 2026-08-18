import Testing
import Foundation
@testable import Marginalia

/// The seam between the models and the design system. Views stay ignorant of
/// SwiftData; this is the only place that knows about both.
struct RowMappingTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func note(
        _ kind: NoteKind = .thought,
        text: String = "a thought",
        page: Int? = nil,
        tags: [String] = [],
        minutesAgo: Int = 0,
        book: Book? = nil
    ) -> Note {
        Note(shortID: 11, kind: kind, text: text, page: page, tags: tags,
             createdAt: now.addingTimeInterval(-60 * Double(minutesAgo)), book: book)
    }

    private func row(_ note: Note, connections: [Int] = []) -> NoteRowData {
        NoteRowData(note, connections: connections, now: now)
    }

    // MARK: Identity

    @Test func theRowIsIdentifiedByTheNotesOwnID() {
        #expect(row(note()).id == 11)
        #expect(row(note()).idLabel == "n.11")
    }

    // MARK: Metadata

    @Test func metadataIsTheKindMarkerThenTheKindThenTheAge() {
        #expect(row(note(.voice, minutesAgo: 2)).meta == "[v] voice · 2 mins ago")
    }

    @Test func eachKindBringsItsOwnMarker() {
        #expect(row(note(.quote)).meta.hasPrefix("[q] quote") == true)
        #expect(row(note(.thought)).meta.hasPrefix("[t] thought") == true)
        #expect(row(note(.scan)).meta.hasPrefix("[s] scan") == true)
    }

    // MARK: Source line

    @Test func theSourceLineIsBookThenPageThenTags() {
        let row = row(note(page: 214, tags: ["systems"],
                           book: Book(title: "Thinking, Fast and Slow")))
        #expect(row.source == "Thinking, Fast and Slow · p.214 · #systems")
    }

    /// Tags share one segment, so the `·` separators keep meaning
    /// book / page / tags rather than turning into a list delimiter.
    @Test func severalTagsShareOneSegment() {
        let row = row(note(page: 72, tags: ["error", "quality"], book: Book(title: "X")))
        #expect(row.source == "X · p.72 · #error #quality")
    }

    /// A quick capture has no page — the source line closes up rather than
    /// showing `p.0`.
    @Test func aNoteWithoutAPageOmitsThePageSegment() {
        let row = row(note(tags: ["systems"], book: Book(title: "Inbox", status: .inbox)))
        #expect(row.source == "Inbox · #systems")
    }

    @Test func aNoteWithoutTagsOmitsTheTagSegment() {
        #expect(row(note(page: 12, book: Book(title: "Meditations"))).source == "Meditations · p.12")
    }

    /// Book detail already carries the title at the top of the screen; every
    /// row repeating it underneath would be noise.
    @Test func bookDetailDropsTheBookFromTheSourceLine() {
        let note = note(page: 214, tags: ["systems"], book: Book(title: "Thinking, Fast and Slow"))
        let row = NoteRowData(note, showingBook: false, now: now)
        #expect(row.source == "p.214 · #systems")
    }

    /// A note with nothing but a book leaves an empty source line rather than a
    /// stray separator.
    @Test func aBooklessSourceLineCanBeEmpty() {
        let note = note(book: Book(title: "Meditations"))
        #expect(NoteRowData(note, showingBook: false, now: now).source.isEmpty)
    }

    // MARK: Quotes

    @Test func onlyAQuoteGetsTheQuoteRule() {
        #expect(row(note(.quote)).isQuote)
        #expect(row(note(.thought)).isQuote == false)
        #expect(row(note(.voice)).isQuote == false)
    }

    /// A scan is a passage read off a printed page, so it wears the quote rule
    /// — while its metadata still says `[s] scan`, because how a note was
    /// captured is a fact about the note.
    @Test func aScanGetsTheQuoteRuleAndKeepsItsOwnMarker() {
        #expect(row(note(.scan)).isQuote)
        #expect(row(note(.scan)).meta.hasPrefix("\(Glyphs.scan) scan · "))
    }

    // MARK: Connections

    @Test func connectionsAreCarriedOntoTheRowInOrder() {
        #expect(row(note(), connections: [9, 3]).links == [9, 3])
    }

    @Test func aConnectionLinkRoundTripsThroughItsURL() throws {
        let url = try #require(NoteLink.url(for: 9))
        #expect(url.absoluteString == "marginalia://note/9")
        #expect(NoteLink.shortID(from: url) == 9)
    }

    @Test func anUnrelatedURLIsNotTreatedAsANoteLink() throws {
        #expect(NoteLink.shortID(from: try #require(URL(string: "https://example.com/note/9"))) == nil)
    }

    @Test func aNoteWithNoConnectionsHasNoLinks() {
        #expect(row(note()).links.isEmpty)
    }

    // MARK: Follow-ups

    private func threaded(_ note: Note, _ ages: [Int]) -> Note {
        note.followUps = ages.map {
            FollowUp(text: "thought \($0)",
                     createdAt: now.addingTimeInterval(-60 * Double($0)), note: note)
        }
        return note
    }

    /// A thread reads forward — it's a conversation with yourself, and the
    /// answer comes after the thing it answers.
    @Test func followUpsAreThreadedOldestFirst() {
        let row = row(threaded(note(), [2, 30, 9]))
        #expect(row.followUps.map(\.text) == ["thought 30", "thought 9", "thought 2"])
    }

    @Test func eachFollowUpCarriesItsOwnAge() {
        #expect(row(threaded(note(), [2])).followUps.first?.when == "2 mins ago")
    }

    @Test func aNoteWithNoFollowUpsHasNone() {
        #expect(row(note()).followUps.isEmpty)
    }

    // MARK: Stars

    /// The review card draws `[ ] star` or `[*] starred` off this, so the view
    /// still never sees the model.
    @Test func theRowKnowsWhetherTheNoteIsStarred() {
        #expect(row(note()).isStarred == false)
        let starred = note()
        starred.isStarred = true
        #expect(row(starred).isStarred)
    }

    // MARK: Books

    @Test func aBookRowCarriesItsStatusMarkerAndCount() {
        let book = Book(title: "Meditations", author: "Marcus Aurelius", status: .finished)
        book.notes = [note(), note()]
        let row = BookRowData(book)
        #expect(row.marker == "[x]")
        #expect(row.status == "finished")
        #expect(row.title == "Meditations")
        #expect(row.author == "Marcus Aurelius")
        #expect(row.count == 2)
    }

    @Test func aBookWithNoNotesCountsZeroRatherThanNothing() {
        #expect(BookRowData(Book(title: "The Beginning of Infinity", status: .queued)).count == 0)
    }

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
}
