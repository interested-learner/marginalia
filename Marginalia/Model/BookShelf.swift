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
}
