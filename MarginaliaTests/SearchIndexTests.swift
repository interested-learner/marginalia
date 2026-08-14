import Testing
@testable import Marginalia

/// Which notes a query finds, and which book they read under.
struct SearchIndexTests {

    private let library: [SearchIndex.Record] = [
        .init(id: 1, text: "Attention is a finite budget.",
              tags: ["attention"], book: "Thinking, Fast and Slow", author: "Daniel Kahneman"),
        .init(id: 2, text: "Human error usually is a result of poor design.",
              tags: ["error", "design"], followUps: ["Held up for a month now."],
              book: "The Design of Everyday Things", author: "Don Norman"),
        .init(id: 3, text: "Good error messages assume the system is at fault.",
              tags: ["error"], book: "The Design of Everyday Things", author: "Don Norman"),
        .init(id: 4, text: "Confine thyself to the present.",
              tags: ["stoicism"], book: "Meditations", author: "Marcus Aurelius")
    ]

    private func find(_ raw: String) -> [SearchIndex.Group] {
        SearchIndex.results(for: SearchQuery(raw), in: library)
    }

    // MARK: What is searched

    @Test func aWordInTheNoteFindsIt() {
        #expect(find("thyself") == [.init(book: "Meditations", notes: [4])])
    }

    /// A hit in the thread returns the note it hangs under — a follow-up is
    /// never a row of its own.
    @Test func aWordInAFollowUpFindsTheNoteItHangsUnder() {
        #expect(find("month") == [.init(book: "The Design of Everyday Things", notes: [2])])
    }

    /// Being told nothing was found while four notes from that book sit in the
    /// library would read as a broken field.
    @Test func anAuthorFindsEveryNoteFromTheirBook() {
        #expect(find("kahneman") == [.init(book: "Thinking, Fast and Slow", notes: [1])])
    }

    @Test func aBookTitleFindsEveryNoteFromIt() {
        #expect(find("meditations") == [.init(book: "Meditations", notes: [4])])
    }

    @Test func aTagIsFoundWithoutTheHashToo() {
        #expect(find("stoicism") == [.init(book: "Meditations", notes: [4])])
    }

    // MARK: How it narrows

    @Test func aSecondWordNarrowsRatherThanWidens() {
        #expect(find("error").count == 1)
        #expect(find("error messages") == [.init(book: "The Design of Everyday Things", notes: [3])])
    }

    @Test func aHashedWordFiltersByTag() {
        #expect(find("#error") == [.init(book: "The Design of Everyday Things", notes: [2, 3])])
    }

    /// `#error` is a filter, not a word: a note whose *body* says "error" but
    /// which isn't tagged with it doesn't answer.
    @Test func aTagFilterIgnoresTheBody() {
        let notes: [SearchIndex.Record] = [
            .init(id: 1, text: "an error, spelled out", tags: ["design"], book: "A"),
            .init(id: 2, text: "nothing of the sort", tags: ["error"], book: "A")
        ]
        #expect(SearchIndex.results(for: SearchQuery("#error"), in: notes)
                == [.init(book: "A", notes: [2])])
    }

    @Test func aTagAndAWordApplyTogether() {
        #expect(find("#error messages") == [.init(book: "The Design of Everyday Things", notes: [3])])
    }

    @Test func nothingTypedFindsNothingRatherThanEverything() {
        #expect(find("").isEmpty)
        #expect(find("#").isEmpty)
    }

    @Test func aWordNobodyWroteFindsNothing() {
        #expect(find("motorcycle").isEmpty)
    }

    // MARK: Order

    /// A search for `error` is answered best by the book that answers it twice.
    @Test func theBookWithTheMostToSayComesFirst() {
        let groups = find("error")
        #expect(groups.map(\.book) == ["The Design of Everyday Things"])

        let wide = SearchIndex.results(for: SearchQuery("a"), in: library)
        #expect(wide.first?.book == "The Design of Everyday Things")
    }

    @Test func booksWithTheSameCountReadAlphabetically() {
        let notes: [SearchIndex.Record] = [
            .init(id: 1, text: "shared", book: "Zen"),
            .init(id: 2, text: "shared", book: "Meditations")
        ]
        #expect(SearchIndex.results(for: SearchQuery("shared"), in: notes).map(\.book)
                == ["Meditations", "Zen"])
    }

    /// Records arrive newest first, as the stream sorts them, and stay that way
    /// inside a group.
    @Test func notesKeepTheOrderTheyArrivedIn() {
        #expect(find("#error").first?.notes == [2, 3])
    }

    @Test func theCountIsEveryNoteAcrossEveryBook() {
        #expect(SearchIndex.count(of: find("error")) == 2)
        #expect(SearchIndex.count(of: find("nothing here")) == 0)
    }
}
