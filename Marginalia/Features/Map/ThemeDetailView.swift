import SwiftUI

/// One theme, as its notes.
///
/// **The notes are the point, and the graph is one tap further.** That ordering
/// is the whole of `docs/decisions.md` §20 in miniature: a reader who taps
/// `#attention` wants to read the eleven notes, not to look at eleven labelled
/// dots. `[◇] graph` is there for when the shape is the question, and at a
/// theme's size a graph finally answers one.
///
/// Ordinary `NoteRow`s, so a note reads here exactly as it does on the stream —
/// margin, quote rule, thread and all.
struct ThemeDetailView: View {
    let name: String
    let notes: [NoteRowData]
    let books: Int

    let onBack: () -> Void
    let onGraph: () -> Void
    let onOpenNote: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(
                style: .title("theme"),
                trailing: Glyphs.count(notes.count),
                back: BackLink(label: "map", action: onBack)
            ) {
                Text(caption)
                    .font(Typography.source)
                    .foregroundStyle(Theme.textMute)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(notes) { note in
                        NoteRow(note: note, onConnections: { onOpenNote(note.id) })
                        Hairline()
                    }
                }
            }

            graphBar
        }
        .background(Theme.canvas)
    }

    /// The theme's name, and what it spans. A theme whose notes share no
    /// phrase has no name, and then this is just the span.
    private var caption: String {
        let spans = "\(books) \(books == 1 ? "book" : "books")"
        guard !name.isEmpty else { return spans }
        return "\(name) · \(spans)"
    }

    /// The same pinned action bar the library uses for `[+] add a book`, so the
    /// one way out of this screen sits where a reader has already found one.
    private var graphBar: some View {
        VStack(spacing: 0) {
            Hairline()

            HStack(spacing: 20) {
                MarkerButton(title: "\(Glyphs.tabMap) graph", kind: .link, action: onGraph)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .background(Theme.canvas)
        .chromeTypeSize()
    }
}
