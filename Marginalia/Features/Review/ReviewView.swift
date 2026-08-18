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
    /// Opening one half of a crossing. Everything a note can do lives where the
    /// note is, so the card routes there rather than growing six more actions.
    let onOpenNote: (Int) -> Void

    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @Query private var edges: [NoteEdge]

    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme

    @State private var today: [Note] = []
    /// Whether `[↻] keep going` would find anything. Held rather than computed:
    /// as a computed property it ran a whole `ReviewSetBuilder` pass over every
    /// note in the library on **every body evaluation**, to decide whether to
    /// draw one button — and the body is evaluated constantly while a paging
    /// scroll is in flight.
    @State private var more = false
    @State private var position: Int? = 0
    @State private var composing: Note?
    /// Which card is picking a note to link to.
    @State private var linking: Note?

    /// The day's crossing, or `nil` on a library that has none — in which case
    /// review is exactly what it was before this card existed. Built once beside
    /// `today` and held, for the same reason `today` is.
    @State private var crossing: CrossingFinder.Crossing?

    /// Whether the reader has disconnected it. **The card stays on screen.**
    /// Removing it would take a page out of the paging scroll view while the
    /// reader is standing on that page — the same class of feedback loop that
    /// made the end of the set stick in phase 11. The suppression is recorded
    /// either way and the card is gone tomorrow.
    @State private var rejected = false

    /// The disconnect confirmation. Every delete in the app goes through this
    /// one door, and `Erasure.connection` already writes the sentence.
    @State private var erasing: Erasure?

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
        .confirming($erasing, in: context, after: disconnected)
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
                let connections = self.connections
                ForEach(Array(today.enumerated()), id: \.offset) { index, note in
                    ReviewCard(note: row(note, connections: connections),
                               actions: actions(for: note, connections: connections))
                        .containerRelativeFrame(.vertical)
                        .id(index)
                }

                if let crossing {
                    CrossingCard(
                        crossing: CrossingCardData(crossing),
                        rejected: rejected,
                        onOpen: onOpenNote,
                        onReject: { erasing = .connection(crossing.edge) }
                    )
                    .containerRelativeFrame(.vertical)
                    .id(today.count)
                }

                ClosingCard(remaining: more) { keepGoing() }
                    .containerRelativeFrame(.vertical)
                    .id(lastIndex)
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
            // **Paging past a crossing surfaces nothing**, and this guard
            // already does it: the crossing card's index is `today.count`, so it
            // fails the bound. That is deliberate rather than lucky — marking
            // both its notes surfaced would quietly reshape tomorrow's eight,
            // because `lastSurfacedAt` is exactly what `ReviewSetBuilder` scores
            // on, and the crossing is extra rather than part of the set.
            guard let previous, previous < today.count else { return }
            let seen = today[previous]

            // **Not on this turn of the run loop.** Surfacing writes, and a
            // `context.save()` invalidates both `@Query`s on this view, which
            // re-evaluates the whole body — while the paging scroll is still
            // decelerating. Handing it to the next turn lets the scroll land
            // first; the note is the same note either way.
            Task { @MainActor in try? ReviewWriter.surface(seen, in: context) }
        }
    }

    private var foot: some View {
        VStack(spacing: 12) {
            ASCIIProgressBar(fraction: fraction)
            // Nothing to swipe to from the closing card, so the hint goes rather
            // than pointing at the end of the scroll.
            //
            // **Hidden, never removed.** `foot` and the paging scroll view are
            // siblings in one `VStack`, so taking this line out of the layout
            // gives the scroll view 27 more points — which changes every
            // `containerRelativeFrame(.vertical)` page height, mid-flight, at
            // exactly the moment the reader reaches the last page. The scroll
            // then re-targets, un-hides the hint, shrinks again, and the deck
            // sticks. It reads as the app fighting your thumb, and it was only
            // ever reachable at the end of the set.
            Text("\(Glyphs.up) swipe up for next")
                .font(Typography.meta)
                .foregroundStyle(Theme.textAsh)
                .opacity(atEnd ? 0 : 1)
                .accessibilityHidden(atEnd)
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
            more = hasMore
            crossing = CrossingFinder.pick(from: edges, on: .now,
                                           avoiding: Set(today.map(\.shortID)))
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
    ///
    /// **There is deliberately no scroll here.** The closing card is the last
    /// element and carries the id `today.count`, so appending puts the first new
    /// note at exactly the slot the reader is already looking at: the geometry
    /// doesn't move and the card's content becomes the next note under the
    /// thumb. Scrolling would mean animating *backwards* past the eight cards
    /// that were just inserted above the closing card, which is a long fling to
    /// arrive where you already were. The haptic is fired by hand because
    /// `position` genuinely doesn't change and `onChange` will not see this.
    private func keepGoing() {
        let next = ReviewSetBuilder.set(from: notes, on: .now, excluding: Set(today.map(\.shortID)))
        guard !next.isEmpty else { return }

        today += next
        more = hasMore
        Haptics.paged()
    }

    /// The reader said the pair isn't one. `Eraser.suppress` has already run —
    /// this is what happens after.
    ///
    /// **The card is not removed and the crossing is not re-picked.** Both would
    /// change the paging scroll view's page count under a thumb resting on that
    /// exact page, which is the shape of defect phase 11 spent a stage on. The
    /// foot says `disconnected` instead, the suppression is permanent, and
    /// tomorrow's pick can't return the pair — `CrossingFinder.all` skips
    /// suppressed edges.
    private func disconnected() {
        rejected = true
        // A suppressed edge frees degree budget, and the next full recompute
        // hands it to somebody else. `LinkWriter` is the only path an edge takes
        // to exist, here as everywhere.
        Task { try? await LinkWriter.relink(in: context) }
    }

    /// Whether `keep going` would find anything. One card's worth is enough to
    /// answer the question, and the question is only asked when the deck changes.
    private var hasMore: Bool {
        !ReviewSetBuilder.set(from: notes, on: .now,
                              limit: 1, excluding: Set(today.map(\.shortID))).isEmpty
    }

    // MARK: A card

    private func row(_ note: Note, connections: [Int: [Int]]) -> NoteRowData {
        NoteRowData(note, connections: connections[note.shortID] ?? [])
    }

    private func actions(for note: Note, connections: [Int: [Int]]) -> ReviewActions {
        ReviewActions(
            addThought: { composing = note },
            toggleStar: {
                try? ReviewWriter.star(note, in: context)
                Haptics.starred()
            },
            openBook: note.book.map { book in { onOpenBook(book) } },
            shareCard: { ShareableCard(note: row(note, connections: connections), scheme: scheme) },
            link: { linking = note }
        )
    }

    /// Built **once per body pass and handed down**, never read from inside the
    /// `ForEach`. As a computed property reached per row it rebuilt the whole
    /// edge index for every card on screen, every redraw.
    private var connections: [Int: [Int]] { ConnectionIndex.build(edges: edges) }

    // MARK: Where you are

    private var index: Int { position ?? 0 }

    /// The closing card's slot. `keepGoing()` grows `today`, so this is computed
    /// rather than stored — and the crossing card sits at `today.count`, one
    /// above the last note and one below the end.
    private var lastIndex: Int { today.count + (crossing == nil ? 0 : 1) }

    /// **Not `index >= today.count`.** With a crossing on screen there is still
    /// a card below it, and hiding the hint there would say the set had ended
    /// one page early.
    private var atEnd: Bool { index >= lastIndex }

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
        // `-reviewCrossing 1` opens on the crossing, which is otherwise reachable
        // only by swiping past all eight — and the simulator can't be swiped.
        if defaults.bool(forKey: "reviewCrossing"), crossing != nil { position = today.count }
        if defaults.bool(forKey: "reviewEnd") { position = lastIndex }
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
