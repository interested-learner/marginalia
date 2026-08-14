import Foundation

/// The order the library reads in.
///
/// What you're reading, then what's waiting, then what's done — and the Inbox
/// last, where a drawer belongs. Alphabetical inside a status, so saving a note
/// doesn't reshuffle the row under the reader's thumb.
///
/// Shared because the books screen and the capture sheet's picker both show the
/// library, and the same library reading two ways would be a bug in one of them.
nonisolated enum BookShelf {

    static func ordered(_ books: [Book]) -> [Book] {
        books.sorted {
            rank($0.status) == rank($1.status)
                ? $0.title.localizedCompare($1.title) == .orderedAscending
                : rank($0.status) < rank($1.status)
        }
    }

    static func rank(_ status: BookStatus) -> Int {
        switch status {
        case .reading: 0
        case .queued: 1
        case .finished: 2
        case .inbox: 3
        }
    }

    /// The filter chips the library offers, in reading order — only the
    /// statuses actually on the shelf, so a library of three queued books
    /// doesn't show two chips that lead nowhere.
    ///
    /// **The Inbox is never a chip.** It's a drawer rather than a reading
    /// state, and "show me only the Inbox" isn't a question anyone asks — it's
    /// always there under `all`, which is where it stays visible.
    static func filters(for books: [Book]) -> [BookStatus] {
        let present = Set(books.map(\.status)).subtracting([.inbox])
        return present.sorted { rank($0) < rank($1) }
    }

    /// `nil` is `all`, and `all` includes the Inbox.
    static func matching(_ status: BookStatus?, in books: [Book]) -> [Book] {
        guard let status else { return books }
        return books.filter { $0.status == status }
    }

    // MARK: Duplicates

    /// The book already on the shelf that this draft would be a second copy of.
    ///
    /// **Matched on the title, and on the author only when both sides have one.**
    /// Open Library returns "Meditations" with no author often enough that
    /// insisting on both would let the duplicate through in exactly the case the
    /// check exists for. Two genuinely different books with the same title and
    /// different authors still both get added.
    ///
    /// `excluding` is the book the form is editing — correcting a typo in a
    /// title must not report the book as a duplicate of itself.
    ///
    /// Takes the two strings rather than a `BookDraft` so it stays `nonisolated`
    /// with the rest of this file; the draft is a `MainActor` value like every
    /// other plain type in the project.
    static func duplicate(
        title rawTitle: String,
        author rawAuthor: String,
        in books: [Book],
        excluding: Book? = nil
    ) -> Book? {
        let title = key(rawTitle)
        guard !title.isEmpty else { return nil }
        let author = key(rawAuthor)

        return books.first { book in
            guard book !== excluding, key(book.title) == title else { return false }
            let theirs = key(book.author)
            return author.isEmpty || theirs.isEmpty || author == theirs
        }
    }

    /// Case, accents and stray spacing are not what makes two books different.
    private static func key(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
