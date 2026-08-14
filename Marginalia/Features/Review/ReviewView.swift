import SwiftUI
import SwiftData

/// One note per screen, swiped vertically through a set chosen fresh each day.
/// No keep/skip/later — see `docs/decisions.md` §4.
///
/// Phase 2 pages through real notes. `ReviewSetBuilder` picks the day's set and
/// the actions start working in phase 5; until then this is the newest eight.
struct ReviewView: View {
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]

    @State private var index = 0

    private var set: [Note] { Array(notes.prefix(8)) }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(style: .title("daily review"),
                         trailing: set.isEmpty ? nil : "\(index + 1) of \(set.count)")

            if set.count < 3 {
                Spacer()
                EmptyState(message: "not enough notes to review yet — capture a few first")
                Spacer()
            } else {
                TabView(selection: $index) {
                    ForEach(Array(set.enumerated()), id: \.offset) { i, note in
                        ReviewCard(note: NoteRowData(note)).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack(spacing: 12) {
                    ASCIIProgressBar(fraction: Double(index + 1) / Double(set.count))
                    Text("\(Glyphs.up) swipe up for next")
                        .font(Typography.meta)
                        .foregroundStyle(Theme.textAsh)
                }
                .padding(.bottom, 16)
            }
        }
        .background(Theme.canvas)
    }
}

/// Centered and open — deliberately not using the margin, which belongs to the
/// stream and book detail.
struct ReviewCard: View {
    let note: NoteRowData

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()

            Text("\(note.idLabel) · \(note.meta)")
                .font(Typography.meta)
                .foregroundStyle(Theme.textAsh)

            Text(note.isQuote ? "\u{201C}\(note.text)\u{201D}" : note.text)
                .font(Typography.reviewBody)
                .lineSpacing(Typography.reviewLeading)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("— \(note.source)")
                .font(Typography.source)
                .foregroundStyle(Theme.textMute)

            HStack(spacing: 20) {
                MarkerButton(title: "\(Glyphs.followUp) add a thought", kind: .link) {}
                MarkerButton(title: "\(Glyphs.star) star", kind: .link) {}
                MarkerButton(title: "\(Glyphs.forward) open book", kind: .link) {}
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }
}
