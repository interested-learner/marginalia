import SwiftUI

/// What a row needs to draw itself. Phase 1 renders these from static sample
/// data; phase 2 maps them from SwiftData models. Keeping the view ignorant of
/// the model is what lets the design system be judged before the model exists.
struct NoteRowData: Identifiable {
    let id: Int
    let idLabel: String
    let meta: String
    let text: String
    let isQuote: Bool
    let source: String
    var links: [String] = []
}

/// A note in the stream: the margin, then metadata, body, and source.
struct NoteRow: View {
    let note: NoteRowData

    var body: some View {
        VStack(spacing: 0) {
            MarginColumn(label: note.idLabel) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(note.meta)
                        .font(Typography.meta)
                        .foregroundStyle(Theme.textAsh)

                    if note.isQuote {
                        QuoteRule(text: note.text)
                    } else {
                        Text(note.text)
                            .font(Typography.noteBody)
                            .lineSpacing(Typography.bodyLeading)
                            .foregroundStyle(Theme.textBody)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Source and connections are one paragraph so they wrap
                    // together. An HStack pushes the links onto the wrong line
                    // whenever the source is long enough to break.
                    Text(sourceLine)
                        .font(Typography.source)
                        .foregroundStyle(Theme.textMute)
                        .tint(Theme.textMute)   // links stay in-palette, never iOS blue
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 20)

            Hairline()
        }
    }

    /// `Thinking, Fast and Slow · p.214 · #systems · → n.09`
    ///
    /// Connections carry a `marginalia://note/…` link so they stay tappable
    /// while still flowing inline. Phase 2 registers the handler.
    private var sourceLine: AttributedString {
        var line = AttributedString(note.source)
        for link in note.links {
            line += AttributedString(" · ")   // separator stays unadorned
            var part = AttributedString("\(Glyphs.forward) \(link)")
            part.underlineStyle = .single
            if let id = link.split(separator: ".").last,
               let url = URL(string: "marginalia://note/\(id)") {
                part.link = url
            }
            line += part
        }
        return line
    }
}

struct BookRowData: Identifiable {
    let id: Int
    let marker: String
    let title: String
    let author: String
    let status: String
    let count: Int
}

/// A book: status marker, title, count — then author and status indented to
/// align under the title. No cover art; the absence of imagery is the identity.
struct BookRow: View {
    let book: BookRowData

    @ScaledMetric(relativeTo: .footnote) private var indent: CGFloat = 34

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(book.marker)
                        .font(Typography.source)
                        .foregroundStyle(Theme.textMute)
                    Text(book.title)
                        .font(Typography.bookTitle)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(Glyphs.count(book.count))
                        .font(Typography.source)
                        .foregroundStyle(Theme.textAsh)
                }

                HStack(spacing: 8) {
                    Text(book.author)
                        .font(Typography.source)
                        .foregroundStyle(Theme.textMute)
                    Text("· \(book.status)")
                        .font(Typography.source)
                        .foregroundStyle(Theme.textAsh)
                }
                .padding(.leading, indent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Hairline()
        }
    }
}
