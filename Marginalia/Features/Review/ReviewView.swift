import SwiftUI
import SwiftData

/// One note per screen, swiped vertically through a set chosen fresh each day.
/// No keep/skip/later — see `docs/decisions.md` §4.
///
/// **The set is built once, on arrival, and held.** Rebuilding it every redraw
/// would reshuffle the deck under the reader's thumb the moment they starred
/// something, because a star is one of the things the set is scored on.
struct ReviewView: View {
    /// A note handed over by a tapped reminder. The card opens on it when it's
    /// in the day's set, and on the first card when it isn't — a notification
    /// tapped a day late shouldn't land on somebody else's note. Cleared once
    /// it's been used.
    @Binding var card: Int?

    /// Cross-tab: `→ open book` hands the book up to `RootView`, which switches
    /// to the library and pushes its detail. The map will want the same route.
    let onOpenBook: (Book) -> Void
    /// `[◇] connections` — the map, two hops out from the card you're reading.
    let onOpenWeb: (Int) -> Void

    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @Query private var edges: [NoteEdge]

    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme

    @State private var today: [Note] = []
    @State private var position: Int? = 0
    @State private var composing: Note?
    /// Which card is picking a note to link to.
    @State private var linking: Note?

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(style: .title("daily review"), trailing: counter)

            if today.count < ReviewSetBuilder.minimum {
                Spacer()
                EmptyState(message: "not enough notes to review yet — capture a few first")
                Spacer()
            } else {
                cards
                foot
            }
        }
        .background(Theme.canvas)
        .task { open() }
        // A reminder tapped while review is already on screen. The `.task`
        // covers arriving from another tab; this covers not moving at all.
        .onChange(of: card) { _, _ in arrive() }
        .sheet(item: $composing) { note in
            FollowUpSheet(note: note)
                .presentationBackground(Theme.canvas)
                .presentationCornerRadius(0)
                .presentationDragIndicator(.hidden)
        }
        .sheet(item: $linking) { note in
            NotePicker(subject: note)
                .presentationBackground(Theme.canvas)
                .presentationCornerRadius(0)
                .presentationDragIndicator(.hidden)
        }
    }

    // MARK: Paging

    /// Vertical, because that's the gesture the hint asks for. A `TabView` in
    /// page style scrolls horizontally and would have to be rotated twice to
    /// pretend otherwise.
    private var cards: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(Array(today.enumerated()), id: \.offset) { index, note in
                    ReviewCard(note: row(note), actions: actions(for: note))
                        .containerRelativeFrame(.vertical)
                        .id(index)
                }

                ClosingCard(remaining: !remaining.isEmpty) { keepGoing() }
                    .containerRelativeFrame(.vertical)
                    .id(today.count)
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $position)
        // A card is surfaced when it's actually paged past — never when the set
        // is built, or opening review would change tomorrow's set unread.
        .onChange(of: position) { previous, current in
            // The haptic marks the card change itself, so it fires on arriving
            // at the closing card and on `keep going` too — anywhere the deck
            // moves. Surfacing is the narrower event and keeps its own guard.
            if previous != current { Haptics.paged() }
            guard let previous, previous < today.count else { return }
            try? ReviewWriter.surface(today[previous], in: context)
        }
    }

    private var foot: some View {
        VStack(spacing: 12) {
            ASCIIProgressBar(fraction: fraction)
            // Nothing to swipe to from the closing card, so the hint goes rather
            // than pointing at the end of the scroll.
            if !atEnd {
                Text("\(Glyphs.up) swipe up for next")
                    .font(Typography.meta)
                    .foregroundStyle(Theme.textAsh)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 16)
        // Where you are in the set and how to get to the next one — a signpost,
        // like the tab bar under it. Unclamped it took a third of the screen at
        // the accessibility sizes, off the card that is the actual reading.
        // And `[▓░░░░░░░░░]` is ten cells of monospace: a progress bar that
        // wraps to two lines has stopped being a bar. See `chromeTypeSize()`.
        .chromeTypeSize()
    }

    // MARK: The set

    private func open() {
        if today.isEmpty {
            today = ReviewSetBuilder.set(from: notes, on: .now)
            openAtLaunch()
        }
        arrive()
    }

    /// A tapped reminder. Switching tabs rebuilds this view, so the handover
    /// happens on arrival — the same place `BooksView` pushes its book.
    private func arrive() {
        guard let wanted = card else { return }
        card = nil
        guard let landing = today.firstIndex(where: { $0.shortID == wanted }) else { return }
        position = landing
    }

    /// `[↻] keep going` extends past the day's eight rather than starting the
    /// same set over — for anyone who wants more, on a day they have the time.
    private func keepGoing() {
        let next = ReviewSetBuilder.set(from: notes, on: .now, excluding: Set(today.map(\.shortID)))
        guard !next.isEmpty else { return }

        let landing = today.count
        today += next
        withAnimation { position = landing }
    }

    /// What `keep going` would find. Read to decide whether to offer it at all.
    private var remaining: [Note] {
        ReviewSetBuilder.set(from: notes, on: .now,
                             limit: 1, excluding: Set(today.map(\.shortID)))
    }

    // MARK: A card

    private func row(_ note: Note) -> NoteRowData {
        NoteRowData(note, connections: connections[note.shortID] ?? [])
    }

    private func actions(for note: Note) -> ReviewActions {
        ReviewActions(
            addThought: { composing = note },
            toggleStar: {
                try? ReviewWriter.star(note, in: context)
                Haptics.starred()
            },
            openBook: note.book.map { book in { onOpenBook(book) } },
            shareCard: { ShareCard.rendered(row(note), in: scheme) },
            openWeb: { onOpenWeb(note.shortID) },
            link: { linking = note }
        )
    }

    private var connections: [Int: [Int]] { ConnectionIndex.build(edges: edges) }

    // MARK: Where you are

    private var index: Int { position ?? 0 }

    private var atEnd: Bool { index >= today.count }

    /// Clamped, so the closing card reads `8 of 8` rather than `9 of 8`.
    private var counter: String? {
        today.count < ReviewSetBuilder.minimum ? nil : "\(min(index + 1, today.count)) of \(today.count)"
    }

    private var fraction: Double {
        guard !today.isEmpty else { return 0 }
        return Double(min(index + 1, today.count)) / Double(today.count)
    }

    // MARK: Launch arguments
    //
    // The simulator can't be tapped or swiped from the command line, so a card
    // past the first can only be screenshot by being launched onto. Same device
    // as `-startTab` and `-openBook`.

    /// `-reviewCard 3` opens on the third card, `-reviewEnd 1` on the closing
    /// card, `-followUp 1` with the composer already open over it.
    private func openAtLaunch() {
        let defaults = UserDefaults.standard

        let card = defaults.integer(forKey: "reviewCard")
        if card > 0 { position = min(card - 1, today.count) }
        if defaults.bool(forKey: "reviewEnd") { position = today.count }
        if defaults.bool(forKey: "followUp") { composing = today[safe: index] }
        if defaults.bool(forKey: "link") { linking = today[safe: index] }
    }
}

/// The end of the day's set. A ritual with an end rather than another infinite
/// feed — and `[↻] keep going` for anyone who wants past it anyway.
private struct ClosingCard: View {
    let remaining: Bool
    let keepGoing: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()

            Text("that's the set")
                .font(Typography.screenTitle)
                .foregroundStyle(Theme.ink)

            Text(remaining
                 ? "come back tomorrow for a new one, or keep reading now."
                 : "come back tomorrow for a new one — that's everything you've written.")
                .font(Typography.noteBody)
                .lineSpacing(Typography.bodyLeading)
                .foregroundStyle(Theme.textBody)
                .fixedSize(horizontal: false, vertical: true)

            if remaining {
                MarkerButton(title: "\(Glyphs.refresh) keep going", kind: .secondary,
                             action: keepGoing)
                    .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }
}

private extension Array {
    /// The launch arguments index into the set by hand, and a number typed on
    /// the command line has no reason to be in range.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
