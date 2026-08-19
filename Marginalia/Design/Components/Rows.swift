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
    /// The book's title as it appears at the head of `source`, so the row can
    /// make that much of the line open the book. Empty on book detail, where the
    /// title is already at the top of the screen and isn't in the line at all.
    var bookTitle: String = ""
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
    /// Files the note under a different book. `nil` hides the action — book
    /// detail doesn't offer it, because the answer there is already on screen.
    var onMove: (() -> Void)?
    /// Rewrites the note's own words, page and tags. `nil` hides the action.
    var onEdit: (() -> Void)?

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

                    Text(sourceLine)
                        .font(Typography.source)
                        .foregroundStyle(Theme.textMute)
                        .tint(Theme.textMute)   // the title link stays in-palette, never iOS blue
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
                // `edit` first: it is the only one of the three that is neither
                // destructive nor a move, and it is the one a reader who spots
                // a typo is reaching for.
                if let onEdit {
                    Button("edit \(note.idLabel)", action: onEdit)
                }
                if let onMove {
                    Button("\(Glyphs.forward) move to book…", action: onMove)
                }
                if let onDelete {
                    Button("delete \(note.idLabel)", role: .destructive, action: onDelete)
                }
            }

            Hairline()
        }
    }

    /// `Thinking, Fast and Slow · p.214 · #systems`
    ///
    /// The book's title carries a `passim://book/…` link so it stays
    /// tappable while still flowing inline; `RootView` intercepts the scheme.
    /// The line has to stay one wrapping paragraph, so what is tappable in it is
    /// a link rather than a button.
    ///
    /// **The title isn't underlined**, and now nothing on the row is. It used to
    /// carry no rule so as not to compete with the connections beside it
    /// (`· → n.09`, underlined); those came out in phase 13 and the reasoning
    /// survives them — an underline under every book title on every row is a
    /// rule through most of the stream. `docs/decisions.md` §22.
    private var sourceLine: AttributedString {
        var line = AttributedString(note.source)

        if !note.bookTitle.isEmpty, let title = line.range(of: note.bookTitle) {
            line[title].link = NoteLink.url(forBookOf: note.id)
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
    @Environment(\.dynamicTypeSize) private var typeSize

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

                // `Daniel Kahneman · reading` side by side until it stops
                // fitting, then one above the other. At the accessibility
                // sizes the two used to wrap through each other — `Kahnem/an`
                // interleaved with `readi/ng` — which is unreadable in a way
                // that a stack simply isn't. The interpunct goes with the
                // stack: it separates things on a line, and there's no line.
                Group {
                    if typeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 3) {
                            author
                            status(separated: false)
                        }
                    } else {
                        HStack(spacing: 8) {
                            author
                            status(separated: true)
                        }
                    }
                }
                .padding(.leading, indent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Hairline()
        }
    }

    private var author: some View {
        Text(book.author)
            .font(Typography.source)
            .foregroundStyle(Theme.textMute)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func status(separated: Bool) -> some View {
        Text(separated ? "· \(book.status)" : book.status)
            .font(Typography.source)
            .foregroundStyle(Theme.textAsh)
            .fixedSize(horizontal: false, vertical: true)
    }
}
