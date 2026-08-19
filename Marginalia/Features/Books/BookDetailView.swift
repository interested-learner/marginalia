import SwiftUI
import SwiftData

/// One book: what it is, how far in you are, and everything you wrote from it.
///
/// The notes use the same margin the stream does, minus the book title on every
/// source line — it's already at the top of the screen. `[+] add note` sits
/// pinned at the foot, where the stream's capture bar sits.
struct BookDetailView: View {
    let book: Book
    let onBack: () -> Void

    @Environment(\.modelContext) private var context

    /// One sheet, not three. Two `.sheet` modifiers on the same view is a
    /// coin-toss over which one presents — `StreamView` says so and this screen
    /// had two of them before `edit` on a note would have made it three.
    @State private var sheet: BookDetailSheet?
    /// What a long press — or `delete` in the header — asked to remove.
    @State private var erasing: Erasure?

    /// `-captureSheet quote|thought|voice` opens the sheet at launch, on that
    /// type — the only way to screenshot it, since the simulator can't be
    /// tapped from the command line.
    private let sheetAtLaunch = NoteKind(
        rawValue: UserDefaults.standard.string(forKey: "captureSheet") ?? ""
    )

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                LazyVStack(spacing: 0) {
                    if notes.isEmpty {
                        EmptyState(message: "no notes yet — add the first one below")
                    }
                    ForEach(notes) { note in
                        NoteRow(
                            note: NoteRowData(note, showingBook: false),
                            onDelete: { erasing = .note(note) },
                            onDeleteFollowUp: { erasing = .thought($0, of: note) },
                            onEdit: { sheet = .note(note) }
                        )
                    }
                }
            }

            addBar
        }
        .background(Theme.canvas)
        .sheet(item: $sheet) { which in
            Group {
                switch which {
                case .capture:
                    CaptureSheet(book: book, kind: sheetAtLaunch ?? .thought)
                case .book:
                    BookFormSheet(editing: book)
                case .note(let note):
                    EditNoteSheet(note: note)
                }
            }
            .presentationBackground(Theme.canvas)
            .presentationCornerRadius(0)
            .presentationDragIndicator(.hidden)
        }
        // Deleting the book deletes the screen you're standing on, so the
        // confirmation hands back to the library rather than leaving detail
        // drawing a book that no longer exists.
        .confirming($erasing, in: context, after: dismissIfBookIsGone)
        .task { openAtLaunch() }
    }

    // MARK: Chrome

    private var header: some View {
        ScreenHeader(
            style: .title(book.title),
            trailing: Glyphs.count(notes.count),
            back: BackLink(label: "books", action: onBack)
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(byline)
                    .font(Typography.source)
                    .foregroundStyle(Theme.textMute)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Spacer(minLength: 8)

                    // The Inbox is found by status and is where every unfiled
                    // capture falls back to. Editing it is one way to end up
                    // with two of them and deleting it is the other, so neither
                    // is offered — its notes are still deletable one at a time.
                    if book.status != .inbox {
                        MarkerButton(title: "edit", kind: .link) { sheet = .book }
                        // A link, not a red button. `danger` belongs to the
                        // confirmation, never to the thing that opens one.
                        MarkerButton(title: "delete", kind: .link) { erasing = .book(book) }
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: Launch arguments
    //
    // The simulator can't be long-pressed any more than it can be tapped, so a
    // confirmation is unreachable from the command line without this. Same
    // device as `-startTab` and `-openBook`; see `CLAUDE.md`.

    /// `-confirmDelete book` opens the book's confirmation, `-confirmDelete note`
    /// the first note's. `-captureSheet quote` still opens the capture sheet.
    private func openAtLaunch() {
        if sheetAtLaunch != nil { sheet = .capture }

        switch UserDefaults.standard.string(forKey: "confirmDelete") {
        case "book": erasing = .book(book)
        case "note": erasing = notes.first.map(Erasure.note)
        default: break
        }
    }

    /// A note deleted from here leaves the screen standing; the book itself
    /// doesn't, and SwiftData will happily keep drawing a row for a model that
    /// has been removed until the navigation stack catches up.
    private func dismissIfBookIsGone() {
        if book.isDeleted { onBack() }
    }

    /// `Daniel Kahneman · reading`, closing up when the author is unknown —
    /// which manual entry and a failed lookup both leave behind.
    /// `Daniel Kahneman · reading · 499pp`
    ///
    /// The length is a fact about the book and it costs nothing to keep — Open
    /// Library fills it and the form takes it. What went with `currentPage` is
    /// the *progress*, which nobody was ever going to keep current by hand.
    /// See `docs/decisions.md` §17.
    private var byline: String {
        var parts: [String] = []
        if !book.author.isEmpty { parts.append(book.author) }
        parts.append(book.status.label)
        if book.pageCount > 0 { parts.append("\(book.pageCount)pp") }
        return parts.joined(separator: " · ")
    }

    private var addBar: some View {
        VStack(spacing: 0) {
            Hairline()
            MarkerButton(title: "\(Glyphs.add) add note") { sheet = .capture }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .background(Theme.canvas)
    }

    // MARK: Notes

    private var notes: [Note] {
        (book.notes ?? []).sorted { $0.createdAt > $1.createdAt }
    }

}

/// The three sheets book detail can put up, as one value — for the reason
/// `StreamSheet` exists, which this screen was already one short of needing.
///
/// `.note` is an edit of a note on this screen; `.book` is an edit of the book
/// itself. There is no `move to book…` here: the answer is the screen you are
/// standing on.
private enum BookDetailSheet: Identifiable {
    case capture
    case book
    case note(Note)

    var id: String {
        switch self {
        case .capture: "capture"
        case .book: "book"
        case .note(let note): "note.\(note.shortID)"
        }
    }
}
