import SwiftUI
import SwiftData

/// One field, over every note in the library.
///
/// **The stream's other half.** The stream is everything in the order it was
/// written; this is everything in the order it was asked for. Reached from
/// `search` in the stream's header, and it keeps the tab bar — it's a screen,
/// not a question, so it doesn't arrive as a sheet.
///
/// `SearchIndex` decides what matches and this reads the store, the same split
/// `CrossingFinder` and `ReviewView` have.
struct SearchView: View {
    /// `← stream`.
    let close: () -> Void
    /// Tapping a result opens it where it lives, which is the stream.
    let onOpenNote: (Int) -> Void

    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]

    /// `-search "attention"` fills the field at launch — the simulator can't be
    /// typed into from the command line, and results are the whole screen.
    @State private var typed = UserDefaults.standard.string(forKey: "search") ?? ""

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(
                style: .title("search"),
                trailing: query.isEmpty ? nil : Glyphs.count(SearchIndex.count(of: groups)),
                back: BackLink(label: "stream", action: close)
            )

            field

            ScrollView {
                LazyVStack(spacing: 0) {
                    if groups.isEmpty {
                        EmptyState(message: emptyMessage)
                    }
                    ForEach(groups) { group in
                        GroupHeader(label: group.book.isEmpty ? Inbox.title : group.book)
                        ForEach(rows(in: group)) { note in
                            Button { onOpenNote(note.shortID) } label: {
                                // The book is named by the group header above,
                                // so the source line drops it — the same rule
                                // book detail follows.
                                NoteRow(note: NoteRowData(note, showingBook: false))
                            }
                            .buttonStyle(PressedRow())
                        }
                    }
                }
            }
        }
        .background(Theme.canvas)
    }

    private var field: some View {
        VStack(spacing: 0) {
            InputField(
                placeholder: "notes, books, authors, #tags…",
                text: $typed,
                focusAtLaunch: true
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Hairline()
        }
    }

    // MARK: Results

    private var query: SearchQuery { SearchQuery(typed) }

    /// Rebuilt as the field changes rather than on submit. At the sizes this app
    /// holds it's a pass over the notes and a `contains` per note — cheaper than
    /// the redraw that's happening anyway.
    private var groups: [SearchIndex.Group] {
        SearchIndex.results(for: query, in: notes.map(Self.record))
    }

    private static func record(_ note: Note) -> SearchIndex.Record {
        SearchIndex.Record(
            id: note.shortID,
            text: note.text,
            tags: note.tags,
            followUps: note.thread.map(\.text),
            book: note.book?.title ?? "",
            author: note.book?.author ?? ""
        )
    }

    /// The ids a group came back with, as the notes they name. Ordered by the
    /// group, not by this lookup — `SearchIndex` decided the order and re-sorting
    /// here would quietly overrule it.
    private func rows(in group: SearchIndex.Group) -> [Note] {
        let index = Dictionary(notes.map { ($0.shortID, $0) }, uniquingKeysWith: { first, _ in first })
        return group.notes.compactMap { index[$0] }
    }


    private var emptyMessage: String {
        query.isEmpty
            ? "type to search every note, thread, book and tag"
            : "nothing matches \(typed.trimmingCharacters(in: .whitespacesAndNewlines))"
    }
}
