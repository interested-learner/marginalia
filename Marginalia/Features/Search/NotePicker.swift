import SwiftUI
import SwiftData

/// The one place in the app where a reader makes a connection.
///
/// Everything else on the graph is the app's own work — `LinkWriter` runs
/// because a note appeared, and nobody is asked to confirm anything. This is the
/// override the spec puts on the review card: a search sheet over the library,
/// and picking a note joins it to the one you were reading.
///
/// **A hand-made link is drawn exactly like an automatic one.** That was decided
/// in phase 6 and it holds here: nothing on this screen promises the line will
/// look different afterwards, because it won't.
struct NotePicker: View {
    /// The note being linked *from* — the card you were reading.
    let subject: Note

    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @Query private var edges: [NoteEdge]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// `-link 1` opens the sheet over the current review card; `-linkSearch "…"`
    /// fills the field. The simulator can't be tapped or typed into.
    @State private var typed = UserDefaults.standard.string(forKey: "linkSearch") ?? ""

    var body: some View {
        VStack(spacing: 0) {
            header

            InputField(placeholder: "which note?", text: $typed)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            Hairline()

            ScrollView {
                LazyVStack(spacing: 0) {
                    if candidates.isEmpty {
                        EmptyState(message: emptyMessage)
                    }
                    ForEach(candidates) { note in
                        Button { link(to: note) } label: { PickerRow(note: NoteRowData(note)) }
                            .buttonStyle(PressedRow())
                    }
                }
            }
        }
        .background(Theme.canvas)
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("link \(subject.idLabel)")
                    .font(Typography.screenTitle)
                    .foregroundStyle(Theme.ink)

                Spacer(minLength: 8)

                Button { dismiss() } label: {
                    Text(Glyphs.close)
                        .font(Typography.meta)
                        .foregroundStyle(Theme.textMute)
                        .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 8)

            Hairline()
        }
    }

    // MARK: What's on offer

    /// The library, newest first, minus the note itself and anything it's
    /// already joined to. **A suppressed pair stays on the list** — the reader
    /// disconnected it once and is allowed to change their mind, which is what
    /// `LinkWriter.pin` does with it.
    ///
    /// An empty field lists everything rather than nothing: this is a picker
    /// first and a search second.
    private var candidates: [Note] {
        let joined = Set(ConnectionIndex.build(edges: edges)[subject.shortID] ?? [])
        let offered = notes.filter { $0.shortID != subject.shortID && !joined.contains($0.shortID) }

        let query = SearchQuery(typed)
        guard !query.isEmpty else { return offered }

        let found = SearchIndex.results(for: query, in: offered.map(Self.record))
        let matched = Set(found.flatMap(\.notes))
        return offered.filter { matched.contains($0.shortID) }
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

    private var emptyMessage: String {
        SearchQuery(typed).isEmpty
            ? "nothing else to link to yet"
            : "nothing matches \(typed.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    private func link(to note: Note) {
        try? LinkWriter.pin(subject, to: note, in: context)
        // A pinned edge spends degree budget at both ends, so somebody's
        // weakest connection may now be one too many. The same recompute a
        // disconnect triggers, for the same reason.
        Task { try? await LinkWriter.relink(in: context) }
        dismiss()
    }
}

/// A note as something to choose rather than something to read: no margin, no
/// thread, and the body clipped to three lines. The same shape the map's panel
/// uses for the same job.
private struct PickerRow: View {
    let note: NoteRowData

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(note.idLabel) · \(note.meta)")
                    .font(Typography.meta)
                    .foregroundStyle(Theme.textAsh)

                Text(note.text)
                    .font(Typography.noteBody)
                    .lineSpacing(Typography.bodyLeading)
                    .foregroundStyle(note.isQuote ? Theme.ink : Theme.textBody)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                if !note.source.isEmpty {
                    Text(note.source)
                        .font(Typography.source)
                        .foregroundStyle(Theme.textMute)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Hairline()
        }
    }
}
