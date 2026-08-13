import SwiftUI

/// One note per screen, swiped vertically through a set chosen fresh each day.
/// No keep/skip/later — see `docs/decisions.md` §4.
///
/// Phase 1: static content, paging works, the actions don't do anything yet.
struct ReviewView: View {
    @State private var index = 0

    private let notes = SampleData.streamYesterday + SampleData.streamToday

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(style: .title("daily review"),
                         trailing: "\(index + 1) of \(notes.count)")

            TabView(selection: $index) {
                ForEach(Array(notes.enumerated()), id: \.offset) { i, note in
                    ReviewCard(note: note).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: 12) {
                ASCIIProgressBar(fraction: Double(index + 1) / Double(notes.count))
                Text("\(Glyphs.up) swipe up for next")
                    .font(Typography.meta)
                    .foregroundStyle(Theme.textAsh)
            }
            .padding(.bottom, 16)
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
