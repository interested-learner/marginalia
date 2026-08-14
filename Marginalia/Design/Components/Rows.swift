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
    /// Connected notes, by short id. Rendered `→ n.09`.
    var links: [Int] = []
    /// Threaded beneath the note, oldest first — shown everywhere the note is.
    var followUps: [FollowUpRowData] = []
    /// Only the review card acts on this, but the row is the only thing a view
    /// gets to see, so it lives here.
    var isStarred: Bool = false
}

/// A later thought, threaded under the note it answers.
struct FollowUpRowData: Identifiable {
    /// Position in the thread. Follow-ups carry no id of their own — they're
    /// only ever read as a list under one parent.
    let id: Int
    let when: String
    let text: String
}

/// A note in the stream: the margin, then metadata, body, and source.
///
/// **A row can be deleted where it is listed, not where it is being read.** The
/// stream and book detail pass these in; the review card doesn't, because review
/// is a reading surface and a long press that destroys the card you're reading
/// is not a thing worth being able to do by accident.
struct NoteRow: View {
    let note: NoteRowData
    /// Deletes the note, its thread, and its edges. `nil` hides the action.
    var onDelete: (() -> Void)?
    /// Deletes one thought from the thread, by its position in it.
    var onDeleteFollowUp: ((Int) -> Void)?

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

                    // Under the source, because the source belongs to the note
                    // rather than to the thread that grew out of it.
                    if !note.followUps.isEmpty {
                        ThreadRule(followUps: note.followUps, onDelete: onDeleteFollowUp)
                    }
                }
            }
            .padding(.horizontal, 20)
            // A long press, because there is nowhere on a row this dense to put
            // a permanent `delete` without it competing with the note. The
            // confirmation is the app's own; this is only the way in.
            .contentShape(Rectangle())
            .contextMenu {
                if let onDelete {
                    Button("delete \(note.idLabel)", role: .destructive, action: onDelete)
                }
            }

            Hairline()
        }
    }

    /// `Thinking, Fast and Slow · p.214 · #systems · → n.09`
    ///
    /// Connections carry a `marginalia://note/…` link so they stay tappable
    /// while still flowing inline; `RootView` intercepts the scheme.
    private var sourceLine: AttributedString {
        var line = AttributedString(note.source)
        for shortID in note.links {
            line += AttributedString(" · ")   // separator stays unadorned
            // Non-breaking, or a wrap drops the arrow on one line and the id it
            // points at on the next.
            var part = AttributedString("\(Glyphs.forward)\u{00A0}\(Glyphs.noteID(shortID))")
            part.underlineStyle = .single
            part.link = NoteLink.url(for: shortID)
            line += part
        }
        return line
    }
}

struct BookRowData {
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
