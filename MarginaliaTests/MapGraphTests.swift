import Foundation
import Testing
@testable import Marginalia

/// Which nodes belong in a view, and which lines join them.
///
/// Pure input and pure output, so every rule in the map — hubs, the two-hop
/// reach, the cap, the collapse — is assertable without a store, a screen or a
/// simulator.
struct MapGraphTests {

    /// `count` notes spread evenly over `books` shelves, which is what
    /// `-tinyLibrary` does and what a real library looks like.
    private func library(notes count: Int, books: Int) -> ([MapGraph.Subject], [MapGraph.Shelf]) {
        let subjects = (1...count).map { MapGraph.Subject(id: $0, book: ($0 - 1) % books) }
        let shelves = (0..<books).map { MapGraph.Shelf(index: $0, title: "Book \($0)") }
        return (subjects, shelves)
    }

    private func notes(_ web: MapGraph.Web) -> [Int] {
        web.nodes.compactMap { node in
            if case .note(let id) = node.id { return id }
            return nil
        }
    }

    private func hubs(_ web: MapGraph.Web) -> [Int] {
        web.nodes.compactMap { node in
            if case .book(let index) = node.id { return index }
            return nil
        }
    }

    // MARK: The library

    @Test func everyNoteIsANodeAndEveryBookIsAHub() {
        let (subjects, shelves) = library(notes: 9, books: 3)
        let web = MapGraph.web(.library, subjects: subjects, shelves: shelves, ties: [])

        #expect(notes(web) == Array(1...9))
        #expect(hubs(web) == [0, 1, 2])
    }

    /// The hub is what makes a new library a shape rather than a scatter of
    /// lonely dots — `docs/decisions.md` §11. Nine notes and no connections is
    /// still nine lines.
    @Test func everyNoteAttachesToItsBook() {
        let (subjects, shelves) = library(notes: 9, books: 3)
        let web = MapGraph.web(.library, subjects: subjects, shelves: shelves, ties: [])

        let attachments = web.edges.filter(\.isAttachment)
        #expect(web.edges.count == 9)
        #expect(attachments.count == 9)
    }

    @Test func aBookNothingWasWrittenFromIsNotDrawn() {
        let web = MapGraph.web(
            .library,
            subjects: [MapGraph.Subject(id: 1, book: 0)],
            shelves: [MapGraph.Shelf(index: 0, title: "Read"), MapGraph.Shelf(index: 1, title: "Queued")],
            ties: []
        )

        #expect(hubs(web) == [0])
    }

    /// A note whose book has gone is still a note. It just floats.
    @Test func aNoteWithNoBookIsStillANode() {
        let web = MapGraph.web(
            .library,
            subjects: [MapGraph.Subject(id: 1), MapGraph.Subject(id: 2, book: 0)],
            shelves: [MapGraph.Shelf(index: 0, title: "Read")],
            ties: []
        )

        #expect(notes(web) == [1, 2])
        #expect(web.edges.count == 1)
    }

    @Test func connectionsAreDrawnAsWellAsAttachments() {
        let (subjects, shelves) = library(notes: 4, books: 1)
        let web = MapGraph.web(
            .library,
            subjects: subjects,
            shelves: shelves,
            ties: [MapGraph.Tie(1, 3, score: 0.7)]
        )

        #expect(web.edges.filter { !$0.isAttachment }.count == 1)
        #expect(web.edges.filter(\.isAttachment).count == 4)
    }

    /// Weight is the connection count, and a note's line to its own book is not
    /// a connection — it's structure. Counting it would make every note in a
    /// well-stocked book look better connected than it is.
    @Test func attachmentsDoNotCountTowardWeight() {
        let (subjects, shelves) = library(notes: 3, books: 1)
        let web = MapGraph.web(
            .library,
            subjects: subjects,
            shelves: shelves,
            ties: [MapGraph.Tie(1, 2), MapGraph.Tie(1, 3)]
        )

        #expect(web.nodes.first { $0.id == .note(1) }?.degree == 2)
        #expect(web.nodes.first { $0.id == .note(2) }?.degree == 1)
    }

    @Test func aTieToANoteThatIsNotOnScreenIsDropped() {
        let (subjects, shelves) = library(notes: 3, books: 1)
        let web = MapGraph.web(
            .library,
            subjects: subjects,
            shelves: shelves,
            ties: [MapGraph.Tie(1, 99), MapGraph.Tie(2, 2)]
        )

        #expect(web.edges.filter(\.isAttachment).count == web.edges.count)
    }

    @Test func anEmptyLibraryDrawsNothing() {
        #expect(MapGraph.web(.library, subjects: [], shelves: [], ties: []).isEmpty)
    }

    /// Built twice, the same both times — the layout hangs off this value, so a
    /// graph that compared unequal for no reason would relayout on every redraw.
    @Test func theSameLibraryBuildsTheSameGraph() {
        let (subjects, shelves) = library(notes: 12, books: 3)
        let ties = [MapGraph.Tie(3, 7, score: 0.6), MapGraph.Tie(1, 2, score: 0.9)]

        #expect(MapGraph.web(.library, subjects: subjects, shelves: shelves, ties: ties)
             == MapGraph.web(.library, subjects: subjects.reversed(), shelves: shelves, ties: ties.reversed()))
    }

    // MARK: The collapse

    @Test func aLibraryUnderTheThresholdIsNotCollapsed() {
        let (subjects, shelves) = library(notes: 100, books: 4)
        let web = MapGraph.web(.library, subjects: subjects, shelves: shelves, ties: [])

        #expect(notes(web).count == 100)
    }

    @Test func aLibraryOverTheThresholdCollapsesToHubs() {
        let (subjects, shelves) = library(notes: MapGraph.collapseAbove + 1, books: 4)
        let web = MapGraph.web(.library, subjects: subjects, shelves: shelves, ties: [])

        #expect(notes(web).isEmpty)
        #expect(hubs(web) == [0, 1, 2, 3])
    }

    /// Hubs are joined where a connection crosses between two books, and
    /// **once** however many cross. Same-book connections leave no line at all,
    /// which is the point of the view: it shows what reaches across.
    @Test func hubsAreJoinedWhereAConnectionCrossesBooks() {
        let (subjects, shelves) = library(notes: 8, books: 2)   // odd ids in book 0
        let web = MapGraph.web(
            .library,
            subjects: subjects,
            shelves: shelves,
            ties: [MapGraph.Tie(1, 2), MapGraph.Tie(3, 4), MapGraph.Tie(1, 3)],
            collapsing: true
        )

        #expect(web.edges.count == 1)
        #expect(web.edges.first == MapGraph.Edge(a: .book(0), b: .book(1), isAttachment: false))
    }

    @Test func aCollapsedHubCarriesItsCrossingsAsWeight() {
        let (subjects, shelves) = library(notes: 9, books: 3)
        let web = MapGraph.web(
            .library,
            subjects: subjects,
            shelves: shelves,
            ties: [MapGraph.Tie(1, 2), MapGraph.Tie(1, 3)],
            collapsing: true
        )

        #expect(web.nodes.first { $0.id == .book(0) }?.degree == 2)
        #expect(web.nodes.first { $0.id == .book(1) }?.degree == 1)
    }

    // MARK: Two hops out

    @Test func aLocalViewReachesTwoHopsAndStops() {
        let (subjects, shelves) = library(notes: 6, books: 1)
        let web = MapGraph.web(
            .note(1),
            subjects: subjects,
            shelves: shelves,
            ties: [MapGraph.Tie(1, 2), MapGraph.Tie(2, 3), MapGraph.Tie(3, 4), MapGraph.Tie(4, 5)]
        )

        #expect(notes(web) == [1, 2, 3])
    }

    /// A hop through a book would pull in everything written from it and the
    /// view would stop being local. Hubs come back at the end, attached to
    /// whatever was actually reached.
    @Test func aLocalViewDoesNotWalkThroughABook() {
        let (subjects, shelves) = library(notes: 8, books: 1)
        let web = MapGraph.web(.note(1), subjects: subjects, shelves: shelves, ties: [])

        #expect(notes(web) == [1])
        #expect(hubs(web) == [0])
    }

    @Test func aLocalViewIsCappedAndTakesTheStrongestFirst() {
        let (subjects, shelves) = library(notes: 60, books: 1)
        // Everything hangs off n.01, weakest connection first in the input.
        let ties = (2...60).map { MapGraph.Tie(1, $0, score: Double($0) / 100) }
        let web = MapGraph.web(.note(1), subjects: subjects, shelves: shelves, ties: ties)

        #expect(notes(web).count == MapGraph.localLimit)
        #expect(notes(web).contains(60))
        #expect(!notes(web).contains(2))
    }

    @Test func aLocalViewOfANoteThatIsGoneIsEmpty() {
        let (subjects, shelves) = library(notes: 4, books: 1)

        #expect(MapGraph.web(.note(99), subjects: subjects, shelves: shelves, ties: []).isEmpty)
    }

    // MARK: One book

    @Test func aBookViewIsThatBookAndWhatWasWrittenFromIt() {
        let (subjects, shelves) = library(notes: 9, books: 3)   // 1, 4, 7 in book 0
        let web = MapGraph.web(.book(0), subjects: subjects, shelves: shelves, ties: [])

        #expect(notes(web) == [1, 4, 7])
        #expect(hubs(web) == [0])
    }

    /// A connection out of the book has nothing to join to here, so it isn't
    /// drawn — the same rule that drops a tie to a note two hops away.
    @Test func aBookViewDropsConnectionsThatLeaveIt() {
        let (subjects, shelves) = library(notes: 9, books: 3)
        let web = MapGraph.web(
            .book(0),
            subjects: subjects,
            shelves: shelves,
            ties: [MapGraph.Tie(1, 4), MapGraph.Tie(1, 2)]
        )

        #expect(web.edges.filter { !$0.isAttachment }.count == 1)
    }
}

/// `[Meditations]`, and what happens to the ones that don't fit.
struct BookHubLabelTests {

    @Test func aShortTitleIsTheWholeTitle() {
        #expect(Glyphs.bookHub("Meditations") == "[Meditations]")
    }

    @Test func aLongTitleIsItsFirstWord() {
        #expect(Glyphs.bookHub("Zen and the Art of Motorcycle Maintenance") == "[Zen]")
        #expect(Glyphs.bookHub("Thinking, Fast and Slow") == "[Thinking]")
    }

    /// `[The]` names nothing.
    @Test func aLeadingArticleIsDropped() {
        #expect(Glyphs.bookHub("The Design of Everyday Things") == "[Design]")
        #expect(Glyphs.bookHub("The Beginning of Infinity") == "[Beginning]")
        #expect(Glyphs.bookHub("An Introduction") == "[Introduction]")
    }

    /// A book actually called "The" keeps it, rather than becoming `[]`.
    @Test func anArticleOnItsOwnSurvives() {
        #expect(Glyphs.bookHub("The") == "[The]")
    }

    @Test func oneVeryLongWordIsCut() {
        #expect(Glyphs.bookHub("Antidisestablishmentarianism") == "[Antidisestab…]")
    }

    @Test func anUntitledBookIsAnEmptyBracket() {
        #expect(Glyphs.bookHub("") == "[]")
    }
}
