import SwiftUI
import SwiftData

/// Every note across every book, newest first. The capture bar is pinned at the
/// foot and present the whole time — that persistence is the point.
struct StreamView: View {
    /// A `→ n.11` tapped anywhere in the app lands here.
    @Binding var focus: Int?
    /// `[◇] connections` on a row: the map, two hops out from that note.
    let onOpenWeb: (Int) -> Void
    /// The two screens that aren't tabs, from the one header that carries them.
    let onSearch: () -> Void
    let onSettings: () -> Void

    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @Query private var edges: [NoteEdge]

    @Environment(\.modelContext) private var context

    @State private var tag = TagIndex.all
    /// `-captureDraft "half a thought"` fills the bar at launch, which is the
    /// only way to screenshot it holding text — the simulator can't be typed
    /// into from the command line.
    @State private var draft = UserDefaults.standard.string(forKey: "captureDraft") ?? ""
    /// What a long press asked to delete, waiting on the confirmation.
    @State private var erasing: Erasure?

    var body: some View {
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
                                    onConnections: { onOpenWeb(note.shortID) }
                                )
                                .id(note.shortID)
                            }
                        }
                    }
                }
                .onChange(of: focus) { _, _ in reveal(with: scroll) }
                .onAppear { reveal(with: scroll) }
            }

            CaptureBar(draft: $draft, voice: demo, focusAtLaunch: !draft.isEmpty, onSave: save)
        }
        .background(Theme.canvas)
        .confirming($erasing, in: context)
    }

    /// The fast path: no book, no page, no tag, straight into the Inbox. A
    /// filter hiding the note that was just written would read as a failed
    /// save, so saving clears it.
    private func save(as kind: NoteKind) -> Bool {
        let capture = CaptureDraft(kind: kind, text: draft)
        guard (try? NoteWriter.save(capture, in: context)) != nil else { return false }
        tag = TagIndex.all
        return true
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

