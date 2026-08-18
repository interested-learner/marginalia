import SwiftUI
import SwiftData

/// Every note across every book, newest first. The capture bar is pinned at the
/// foot and present the whole time — that persistence is the point.
struct StreamView: View {
    /// A `→ n.11` tapped anywhere in the app lands here.
    @Binding var focus: Int?
    /// Whether the capture field has the keyboard. Owned by `RootView`, which
    /// takes the tab bar off the screen while it does.
    @Binding var capturing: Bool
    /// `[◇] connections` on a row: the map, two hops out from that note.
    let onOpenWeb: (Int) -> Void
    /// The two screens that aren't tabs, from the one header that carries them.
    let onSearch: () -> Void
    let onSettings: () -> Void

    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @Query private var edges: [NoteEdge]
    @Query private var books: [Book]

    @Environment(\.modelContext) private var context

    @State private var tag = TagIndex.all
    /// `-captureDraft "half a thought"` fills the bar at launch, which is the
    /// only way to screenshot it holding text — the simulator can't be typed
    /// into from the command line.
    @State private var draft = UserDefaults.standard.string(forKey: "captureDraft") ?? ""
    /// What a long press asked to delete, waiting on the confirmation.
    @State private var erasing: Erasure?
    /// One sheet, not two. Two `.sheet` modifiers on the same view is a
    /// coin-toss over which one presents.
    @State private var sheet: StreamSheet?

    var body: some View {
        VStack(spacing: 0) {
            feed
                // **Everything above the bar is the way out of the field.**
                // This used to be a tap on the `LazyVStack`'s background, which
                // is precisely the part a stream with notes in it covers: every
                // tap landed on a row, a row swallowed it, and the keyboard
                // stayed. A scrim takes the first tap instead — the row under
                // it doesn't fire, which is what a first tap should do while
                // something else has focus.
                .overlay {
                    if capturing {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { capturing = false }
                            // VoiceOver reaches the rows underneath: it moves
                            // through the tree rather than by hit test, and a
                            // scrim in the tree would strand it.
                            .accessibilityHidden(true)
                    }
                }

            CaptureBar(draft: $draft, focusedOut: $capturing, voice: demo,
                       focusAtLaunch: !draft.isEmpty, onSave: save, onEscalate: escalate)
        }
        .background(Theme.canvas)
        .confirming($erasing, in: context)
        .task { openAtLaunch() }
        .sheet(item: $sheet) { which in
            Group {
                switch which {
                case .move(let note):
                    MoveNoteSheet(note: note, books: shelf)
                case .fullNote(let kind):
                    // The draft is handed over, not moved — the bar keeps it
                    // until `onSaved` says a note actually exists, so cancelling
                    // puts the reader back in front of what they wrote.
                    CaptureSheet(kind: kind, text: draft) { draft = "" }
                }
            }
            .presentationBackground(Theme.canvas)
            .presentationCornerRadius(0)
            .presentationDragIndicator(.hidden)
        }
    }

    /// The header, the chips and the notes — everything the scrim covers.
    private var feed: some View {
        VStack(spacing: 0) {
            // The only header in the app carrying actions. Search and settings
            // are screens without a tab, and the stream is home.
            ScreenHeader(
                style: .wordmark(subtitle: "stream"),
                actions: [
                    HeaderAction(label: "search", action: onSearch),
                    HeaderAction(label: "settings", action: onSettings)
                ]
            )

            if !chips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(chips, id: \.self) { chip in
                            TagChip(label: label(for: chip), selected: chip == tag) { tag = chip }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                Hairline()
            }

            ScrollViewReader { scroll in
                ScrollView {
                    // Built once per body pass and handed to every row. Read
                    // from inside the `ForEach` it rebuilt the whole edge index
                    // per row, per redraw.
                    let connections = self.connections

                    LazyVStack(spacing: 0) {
                        if groups.isEmpty {
                            EmptyState(message: emptyMessage)
                        }
                        ForEach(groups) { group in
                            GroupHeader(label: group.label)
                            ForEach(group.items) { note in
                                NoteRow(
                                    note: NoteRowData(note, connections: connections[note.shortID] ?? []),
                                    onDelete: { erasing = .note(note) },
                                    onDeleteFollowUp: { erasing = .thought($0, of: note) },
                                    onConnections: { onOpenWeb(note.shortID) },
                                    onMove: { sheet = .move(note) }
                                )
                                .id(note.shortID)
                            }
                        }
                    }
                }
                // Dragging the feed is the other way out, and the one the
                // scrim can't be. Interactively, so a half-drag comes back
                // rather than committing to an answer nobody gave.
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: focus) { _, _ in reveal(with: scroll) }
                .onAppear { reveal(with: scroll) }
            }
        }
    }

    private var shelf: [Book] { BookShelf.ordered(books) }

    /// `-moveNote 39` opens the re-file sheet, `-captureMore 1` the escalated
    /// one. Both are reached by a tap otherwise, and the simulator can't be
    /// tapped — same device as `-confirmDelete`.
    private func openAtLaunch() {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "captureMore") {
            sheet = .fullNote(.thought)
            return
        }
        let wanted = defaults.integer(forKey: "moveNote")
        guard wanted > 0 else { return }
        sheet = notes.first { $0.shortID == wanted }.map { .move($0) }
    }

    /// The fast path: no book, no page, no tag, straight into the Inbox. A
    /// filter hiding the note that was just written would read as a failed
    /// save, so saving clears it.
    private func save(as kind: NoteKind) -> Bool {
        let capture = CaptureDraft(kind: kind, text: draft)
        guard (try? NoteWriter.save(capture, to: nil, in: context)) != nil else { return false }
        Haptics.saved()
        tag = TagIndex.all
        return true
    }

    /// `→ full note`: the same words, the whole screen, and a book to put them
    /// in. Focus goes first — the sheet is about to cover the keyboard anyway,
    /// and leaving `capturing` true would keep the tab bar hidden underneath it.
    private func escalate(as kind: NoteKind) {
        capturing = false
        sheet = .fullNote(kind)
    }

    /// `-captureBar recording` — the simulator has no microphone, so this is
    /// the only way to see the recording rows. Same device as `-startTab`.
    private var demo: VoiceCapture? {
        VoiceCapture.launchArgument.map { VoiceCapture.demo($0) }
    }

    /// Follows a connection to its note.
    ///
    /// A note hidden by the current filter can't be scrolled to, so the filter
    /// is cleared first — arriving at an empty feed would read as a broken link.
    private func reveal(with scroll: ScrollViewProxy) {
        guard let shortID = focus else { return }
        tag = TagIndex.all
        withAnimation { scroll.scrollTo(shortID, anchor: .center) }
        focus = nil
    }

    // MARK: Feed

    private var chips: [String] {
        let tags = TagIndex.chips(for: notes.map(\.tags))
        return tags.isEmpty ? [] : [TagIndex.all] + tags
    }

    private func label(for chip: String) -> String {
        chip == TagIndex.all ? chip : Glyphs.tag(chip)
    }

    private var filtered: [Note] {
        guard tag != TagIndex.all else { return notes }
        return notes.filter { $0.tags.map(TagIndex.normalized).contains(tag) }
    }

    private var groups: [StreamGrouping.Group<Note>] {
        StreamGrouping.groups(filtered, date: \.createdAt)
    }

    /// Edges store a direction; both ends show the connection.
    private var connections: [Int: [Int]] { ConnectionIndex.build(edges: edges) }

    private var emptyMessage: String {
        notes.isEmpty ? "no notes yet — capture the first one below"
                      : "nothing tagged \(Glyphs.tag(tag))"
    }
}


/// The two sheets the stream can put up, as one value.
///
/// `.sheet` twice on the same view presents whichever SwiftUI feels like, so
/// re-filing a note and escalating a draft share a modifier and an identity.
private enum StreamSheet: Identifiable {
    case move(Note)
    case fullNote(NoteKind)

    var id: String {
        switch self {
        case .move(let note): "move.\(note.shortID)"
        case .fullNote(let kind): "full.\(kind.rawValue)"
        }
    }
}
