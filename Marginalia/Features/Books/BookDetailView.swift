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

    @Query private var edges: [NoteEdge]

    @State private var capturing = false
    @State private var editing = false

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
                        NoteRow(note: NoteRowData(
                            note,
                            connections: connections[note.shortID] ?? [],
                            showingBook: false
                        ))
                    }
                }
            }

            addBar
        }
        .background(Theme.canvas)
        .sheet(isPresented: $capturing) {
            CaptureSheet(book: book, kind: sheetAtLaunch ?? .thought)
                .presentationBackground(Theme.canvas)
                .presentationCornerRadius(0)
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $editing) {
            BookFormSheet(editing: book)
                .presentationBackground(Theme.canvas)
                .presentationCornerRadius(0)
                .presentationDragIndicator(.hidden)
        }
        .task { if sheetAtLaunch != nil { capturing = true } }
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
                    if let progress = book.progress {
                        ASCIIProgressBar(fraction: progress)
                        Text("p.\(book.currentPage) / \(book.pageCount)")
                            .font(Typography.meta)
                            .foregroundStyle(Theme.textAsh)
                            .monospacedDigit()
                    }

                    Spacer(minLength: 8)

                    // The Inbox is found by status and is where every unfiled
                    // capture falls back to. Editing it is the one way to end
                    // up with two of them, so it isn't offered.
                    if book.status != .inbox {
                        MarkerButton(title: "edit", kind: .link) { editing = true }
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    /// `Daniel Kahneman · reading`, closing up when the author is unknown —
    /// which manual entry and a failed lookup both leave behind.
    private var byline: String {
        book.author.isEmpty ? book.status.label : "\(book.author) · \(book.status.label)"
    }

    private var addBar: some View {
        VStack(spacing: 0) {
            Hairline()
            MarkerButton(title: "\(Glyphs.add) add note") { capturing = true }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .background(Theme.canvas)
    }

    // MARK: Notes

    private var notes: [Note] {
        (book.notes ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    private var connections: [Int: [Int]] { ConnectionIndex.build(edges: edges) }
}
