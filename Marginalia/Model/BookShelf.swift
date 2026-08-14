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
}
