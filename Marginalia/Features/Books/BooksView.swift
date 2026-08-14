import SwiftUI
import SwiftData

/// The library. Status marker, title, note count — then author and status.
/// No cover art anywhere; see `docs/decisions.md` §7.
///
/// Tapping a book opens its detail screen. `[+] add book` sits pinned at the
/// foot, in the same place the stream's capture bar does — each tab's create
/// action lives at the bottom of the screen, one thumb away.
struct BooksView: View {
    @Query private var books: [Book]

    @State private var path = NavigationPath()
    @State private var filter: BookStatus?      // nil is `all`
    @State private var adding = false

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                ScreenHeader(style: .title("books"), trailing: Glyphs.count(shelf.count))

                if !filters.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            TagChip(label: allLabel, selected: filter == nil) { filter = nil }
                            ForEach(filters, id: \.self) { status in
                                TagChip(label: status.label, selected: filter == status) {
                                    filter = status
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    Hairline()
                }

                ScrollView {
                    LazyVStack(spacing: 0) {
                        if shelf.isEmpty {
                            EmptyState(message: emptyMessage)
                        }
                        ForEach(shelf) { book in
                            NavigationLink(value: book) { BookRow(book: BookRowData(book)) }
                                .buttonStyle(PressedRow())
                        }
                    }
                }

                addBar
            }
            .background(Theme.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Book.self) { book in
                BookDetailView(book: book) { path.removeLast() }
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
        .sheet(isPresented: $adding) {
            BookFormSheet()
                .presentationBackground(Theme.canvas)
                .presentationCornerRadius(0)
                .presentationDragIndicator(.hidden)
        }
        .task { openAtLaunch() }
    }

    private var addBar: some View {
        VStack(spacing: 0) {
            Hairline()
            MarkerButton(title: "\(Glyphs.add) add book") { adding = true }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .background(Theme.canvas)
    }

    // MARK: Shelf

    private var shelf: [Book] { BookShelf.ordered(BookShelf.matching(filter, in: books)) }

    private var filters: [BookStatus] { BookShelf.filters(for: books) }

    /// `all` reads as a chip label the same way it does in the stream.
    private var allLabel: String { TagIndex.all }

    private var emptyMessage: String {
        books.isEmpty
            ? "no books yet — add the first one below"
            : "nothing marked \(filter?.label ?? "")"
    }

    // MARK: Launch arguments
    //
    // The simulator can't be tapped from the command line, so a screen reached
    // by tapping can only be screenshot by being launched into. Same device as
    // `-startTab` and `-openNote`.

    /// `-openBook "Thinking"` opens that book's detail; `-addBook 1` opens the
    /// form. `-captureSheet quote` still opens the capture sheet, now over the
    /// first book's detail rather than the list — that's where it lives.
    private func openAtLaunch() {
        let defaults = UserDefaults.standard
        if let status = defaults.string(forKey: "bookFilter").flatMap(BookStatus.init(rawValue:)),
           status != .inbox {
            filter = status
        }

        if defaults.bool(forKey: "addBook") { adding = true }

        let wanted = defaults.string(forKey: "openBook")
        let sheet = defaults.string(forKey: "captureSheet")
        guard wanted != nil || sheet != nil else { return }

        let match = wanted.flatMap { prefix in
            shelf.first { $0.title.localizedCaseInsensitiveContains(prefix) }
        }
        if let book = match ?? (sheet != nil ? shelf.first : nil) {
            path.append(book)
        }
    }
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
