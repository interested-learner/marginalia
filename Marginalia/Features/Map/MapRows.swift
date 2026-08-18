import SwiftUI

// The three rows the map's overview is made of. Plain values in, like every
// other row in the app — `Model/RowMapping.swift` is the only file that knows
// about both a `Note` and a `NoteRowData`, and nothing here breaks that.

// MARK: A theme

struct ThemeRowData: Identifiable {
    /// The exemplar's short id. Themes partition the library, so it's unique.
    let id: Int
    /// Extracted from the notes themselves — never from a tag, and never
    /// invented. Empty where they share no phrase and the app has nothing
    /// honest to call the theme.
    let name: String
    let count: Int
    let books: Int
    let exemplar: NoteRowData
}

/// One theme: what it's called, how big it is, and the note at its centre.
///
/// **No marker, and no bar.** `[~]` is already both the Inbox status and the
/// stream tab, and a theme has no status to report. The weight bar came out
/// too: it was a third encoding of a fact the sort order and the count each
/// already carried, drawn in a form — `ASCIIProgressBar` — that means *how far
/// through something you are*. A theme is not in progress, and the largest one
/// always filled every cell, which reads as 100% of nothing.
struct ThemeRow: View {
    let theme: ThemeRowData

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                // **A theme can have no name, and then it has no heading.**
                // `ThemeName` returns nothing where the notes share no word,
                // because naming an incoherent group is the app asserting
                // something it doesn't know — the first run of the dump named
                // one `aspects · attention · automatically`, which is three
                // words beginning with `a` and the signature of that failure.
                // The exemplar below leads instead, and it was always the
                // evidence rather than the decoration.
                if !theme.name.isEmpty {
                    Text(theme.name)
                        .font(Typography.bookTitle)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Text(counts)
                    .font(Typography.meta)
                    .foregroundStyle(Theme.textAsh)
                    .layoutPriority(1)
            }
            // A name and a count are a signpost. The exemplar below is content.
            .chromeTypeSize()

            exemplar
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var counts: String {
        let notes = "\(theme.count) \(theme.count == 1 ? "note" : "notes")"
        let books = "\(theme.books) \(theme.books == 1 ? "book" : "books")"
        return "\(notes) · \(books)"
    }

    /// **The evidence.** The reader can judge a grouping the app got wrong only
    /// if the app shows its working, so the note at the centre of the theme is
    /// quoted here — and it wears the rule and no quote marks, exactly as it
    /// would anywhere else in the app.
    @ViewBuilder
    private var exemplar: some View {
        if theme.exemplar.isQuote {
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(Theme.ink)
                    .frame(width: 2)

                exemplarText(Theme.ink)
            }
            .fixedSize(horizontal: false, vertical: true)
        } else {
            exemplarText(Theme.textBody)
                .padding(.leading, 14)
        }
    }

    private func exemplarText(_ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(theme.exemplar.text)
                .font(Typography.noteBody)
                .lineSpacing(Typography.bodyLeading)
                .foregroundStyle(color)
                // **The evidence has to survive the reader's type size.** At two
                // lines and AX5 this truncated to `Slips and mistakes are…` —
                // four words, which is no evidence at all, and a theme nobody
                // can check is a theme the app is asserting. The name, the
                // counts and the bar are chrome and stop growing; this is
                // content and gets the room it needs. Same conditional the
                // margin uses, and for the same reason.
                .lineLimit(typeSize.isAccessibilitySize ? 5 : 2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(theme.exemplar.idLabel)
                .font(Typography.meta)
                .foregroundStyle(Theme.textAsh)
                .chromeTypeSize()
        }
    }
}

// MARK: A crossing

struct CrossingRowData: Identifiable {
    let a: NoteRowData
    let b: NoteRowData

    /// Ordered by the pair, so the same crossing is the same row twice.
    var id: String { "\(min(a.id, b.id))-\(max(a.id, b.id))" }
}

/// One connection that spans two books.
///
/// The most concrete form of what this app is for, and what the reader in
/// `docs/decisions.md` §19 assumed the map was showing all along. Two fragments
/// joined by `│` — box-drawing, one character, at `hairline`. Not a drawn edge
/// and not a second line weight: this screen adds no vocabulary.
struct CrossingRow: View {
    let crossing: CrossingRowData

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            half(crossing.a)

            Text("│")
                .font(Typography.meta)
                .foregroundStyle(Theme.hairline)
                .padding(.leading, 6)
                .accessibilityHidden(true)

            half(crossing.b)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func half(_ note: NoteRowData) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(note.idLabel)
                .font(Typography.meta)
                .foregroundStyle(Theme.textAsh)
                .chromeTypeSize()

            VStack(alignment: .leading, spacing: 4) {
                Text(note.text)
                    .font(Typography.noteBody)
                    .lineSpacing(Typography.bodyLeading)
                    .foregroundStyle(note.isQuote ? Theme.ink : Theme.textBody)
                    // Content, so it grows — see `ThemeRow`. A crossing whose
                    // two halves are four words each says nothing about why the
                    // app joined them.
                    .lineLimit(typeSize.isAccessibilitySize ? 4 : 2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !note.bookTitle.isEmpty {
                    Text("— \(note.bookTitle)")
                        .font(Typography.source)
                        .foregroundStyle(Theme.textMute)
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: A loose note

/// A note in no theme, connected to nothing.
///
/// **Not a scolding and not a to-do list.** It is here because a summary that
/// showed only the connections the app found, while hiding the notes it couldn't
/// place, would be dishonest — eight of the forty seed notes are isolated.
struct LooseRow: View {
    let note: NoteRowData

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(note.idLabel)
                .font(Typography.meta)
                .foregroundStyle(Theme.textAsh)
                .chromeTypeSize()

            Text(note.text)
                .font(Typography.noteBody)
                .lineSpacing(Typography.bodyLeading)
                .foregroundStyle(note.isQuote ? Theme.ink : Theme.textBody)
                .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
