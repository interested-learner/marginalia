import Testing
@testable import Marginalia

/// The order the library reads in — on the books screen and in the capture
/// sheet's book picker, which have to agree or the same library reads two ways.
struct BookShelfTests {

    private func shelf(_ books: [(String, BookStatus)]) -> [String] {
        BookShelf.ordered(books.map { Book(title: $0.0, status: $0.1) }).map(\.title)
    }

    /// What you're reading, then what's waiting, then what's done.
    @Test func whatYouAreReadingComesFirst() {
        #expect(shelf([("done", .finished), ("later", .queued), ("now", .reading)])
                == ["now", "later", "done"])
    }

    /// The Inbox is a book like any other, but it's a drawer — it sits last.
    @Test func theInboxSitsLastEvenAheadOfFinishedBooks() {
        #expect(shelf([("Inbox", .inbox), ("done", .finished)]) == ["done", "Inbox"])
    }

    /// Alphabetical inside a status, so saving a note doesn't reshuffle the row
    /// under the reader's thumb.
    @Test func booksOfOneStatusAreAlphabetical() {
        #expect(shelf([("Zen", .reading), ("Meditations", .reading)])
                == ["Meditations", "Zen"])
    }

    @Test func anEmptyLibraryOrdersToNothing() {
        #expect(BookShelf.ordered([]).isEmpty)
    }

    // MARK: Filters

    private func library(_ statuses: [BookStatus]) -> [Book] {
        statuses.enumerated().map { Book(title: "book \($0.offset)", status: $0.element) }
    }

    /// Only the statuses actually on the shelf, so a library of three queued
    /// books doesn't offer two chips that lead nowhere.
    @Test func onlyTheStatusesPresentBecomeChips() {
        #expect(BookShelf.filters(for: library([.queued, .queued])) == [.queued])
        #expect(BookShelf.filters(for: library([.finished, .reading, .queued]))
                == [.reading, .queued, .finished])
        #expect(BookShelf.filters(for: []).isEmpty)
    }

    /// The Inbox is a drawer rather than a reading state — "show me only the
    /// Inbox" isn't a question anyone asks, and it stays visible under `all`.
    @Test func theInboxIsNeverAChip() {
        #expect(BookShelf.filters(for: library([.inbox])).isEmpty)
        #expect(BookShelf.filters(for: library([.inbox, .reading])) == [.reading])
    }

    @Test func noFilterIsEverything() {
        let books = library([.reading, .inbox, .finished])
        #expect(BookShelf.matching(nil, in: books).count == 3)
        #expect(BookShelf.matching(.reading, in: books).count == 1)
        #expect(BookShelf.matching(.queued, in: books).isEmpty)
    }
}
