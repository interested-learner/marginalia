import SwiftUI
import SwiftData

/// The library. Status marker, title, note count — then author and status.
/// No cover art anywhere; see `docs/decisions.md` §7.
///
/// Tapping a book opens the full capture sheet against it. **That is phase 3's
/// entry point, not the final one** — phase 4 gives each book a detail screen
/// and moves `[+] add note` there, where it belongs.
struct BooksView: View {
    @Query private var books: [Book]

    @State private var capturing: Book?

    /// `-captureSheet quote|thought|voice` opens the sheet at launch, on that
    /// type. The simulator can't be tapped from the command line, so this is
    /// how the sheet gets screenshot — the same device as `-startTab`.
    @State private var sheetAtLaunch = NoteKind(
        rawValue: UserDefaults.standard.string(forKey: "captureSheet") ?? ""
    )

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(style: .title("books"), trailing: Glyphs.count(books.count))

            ScrollView {
                LazyVStack(spacing: 0) {
                    if books.isEmpty {
                        EmptyState(message: "no books yet")
                    }
                    ForEach(sorted) { book in
                        Button { capturing = book } label: {
                            BookRow(book: BookRowData(book))
                        }
                        .buttonStyle(PressedRow())
                    }
                }
            }
        }
        .background(Theme.canvas)
        .sheet(item: $capturing) { book in
            CaptureSheet(book: book, kind: sheetAtLaunch ?? .thought)
                .presentationBackground(Theme.canvas)
                .presentationCornerRadius(0)
                .presentationDragIndicator(.hidden)
        }
        .task {
            guard sheetAtLaunch != nil else { return }
            capturing = sorted.first
        }
    }

    private var sorted: [Book] { BookShelf.ordered(books) }
}

/// A row that fills `surfaceSoft` while it's held. The only press treatment in
/// the app — there is no scale, no fade, and no shadow.
struct PressedRow: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Theme.surfaceSoft : Theme.canvas)
            .contentShape(Rectangle())
    }
}
