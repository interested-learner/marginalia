import SwiftUI
import SwiftData

/// The library. Status marker, title, note count — then author and status.
/// No cover art anywhere; see `docs/decisions.md` §7.
///
/// Phase 2 reads the real library. Book detail and adding a book are phase 4.
struct BooksView: View {
    @Query private var books: [Book]

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(style: .title("books"), trailing: Glyphs.count(books.count))

            ScrollView {
                LazyVStack(spacing: 0) {
                    if books.isEmpty {
                        EmptyState(message: "no books yet")
                    }
                    ForEach(sorted) { book in
                        BookRow(book: BookRowData(book))
                    }
                }
            }
        }
        .background(Theme.canvas)
    }

    /// What you're reading, then what's waiting, then what's done — and the
    /// Inbox last, where a drawer belongs.
    private var sorted: [Book] {
        books.sorted {
            rank($0.status) == rank($1.status)
                ? $0.title.localizedCompare($1.title) == .orderedAscending
                : rank($0.status) < rank($1.status)
        }
    }

    private func rank(_ status: BookStatus) -> Int {
        switch status {
        case .reading: 0
        case .queued: 1
        case .finished: 2
        case .inbox: 3
        }
    }
}
