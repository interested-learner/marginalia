import Foundation

/// A book being added or corrected, before anything reaches the store.
///
/// Everything arrives as a string — the page count — and this is the one place
/// those become the values a `Book` stores. Keeping it a
/// plain value with no SwiftData in it is what makes the rules below testable
/// without a container, the same bargain `CaptureDraft` makes.
struct BookDraft: Equatable {
    var title: String = ""
    var author: String = ""
    var pages: String = ""
    var status: BookStatus = .reading
    var isbn: String?

    /// A title is the whole requirement. Everything else stays optional on
    /// purpose: lookup failure is routine, and a book you can correct later
    /// beats a form that won't let you past it.
    var canSave: Bool { !bookTitle.isEmpty }

    var bookTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    var bookAuthor: String { author.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// 0 means unknown, which manual entry leaves it as often. Nothing depends
    /// on it being known — it is a fact about the book, not a chore.
    var pageCount: Int { TypedPage.parse(pages) ?? 0 }
}

extension BookDraft {

    /// The form, opened on a book that already exists.
    init(_ book: Book) {
        self.init(
            title: book.title,
            author: book.author,
            pages: book.pageCount > 0 ? String(book.pageCount) : "",
            status: book.status,
            isbn: book.isbn
        )
    }

    /// A search result **fills the form** rather than saving straight through.
    /// Open Library gets authors and page counts wrong often enough that the
    /// last word has to belong to the reader.
    ///
    /// A field the result doesn't know about is left alone rather than blanked
    /// — the reader may have typed it already.
    mutating func fill(from candidate: BookCandidate) {
        title = candidate.title
        if !candidate.author.isEmpty { author = candidate.author }
        if candidate.pageCount > 0 { pages = String(candidate.pageCount) }
        if let found = candidate.isbn { isbn = found }
    }
}
