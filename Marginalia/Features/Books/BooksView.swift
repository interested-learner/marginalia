import SwiftUI

/// The library. Status marker, title, note count — then author and status.
/// No cover art anywhere; see `docs/decisions.md` §7.
struct BooksView: View {
    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(style: .title("books"),
                         trailing: Glyphs.count(SampleData.books.count))

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(SampleData.books) { BookRow(book: $0) }
                }
            }
        }
        .background(Theme.canvas)
    }
}
