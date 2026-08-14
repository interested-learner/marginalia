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
}
