import SwiftUI
import SwiftData

/// Every note across every book, newest first. The capture bar is pinned at the
/// foot and present the whole time — that persistence is the point.
///
/// Phase 2: the feed is real. The capture bar still doesn't save — phase 3.
struct StreamView: View {
    /// A `→ n.11` tapped anywhere in the app lands here.
    @Binding var focus: Int?

    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @Query private var edges: [NoteEdge]

    @State private var tag = TagIndex.all
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(style: .wordmark(subtitle: "stream"))

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
                                NoteRow(note: NoteRowData(note, connections: connections[note.shortID] ?? []))
                                    .id(note.shortID)
                            }
                        }
                    }
                }
                .onChange(of: focus) { _, _ in reveal(with: scroll) }
                .onAppear { reveal(with: scroll) }
            }

            CaptureBar(draft: $draft)
        }
        .background(Theme.canvas)
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
    private var connections: [Int: [Int]] {
        ConnectionIndex.build(from: edges.compactMap { edge in
            guard !edge.isSuppressed, let from = edge.from, let to = edge.to else { return nil }
            return (from: from.shortID, to: to.shortID)
        })
    }

    private var emptyMessage: String {
        notes.isEmpty ? "no notes yet — capture the first one below"
                      : "nothing tagged \(Glyphs.tag(tag))"
    }
}

/// Text or voice, always within reach. Focus moves the input from `surfaceSoft`
/// to `canvas` and its border to `ink`.
struct CaptureBar: View {
    @Binding var draft: String
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Hairline()
            HStack(spacing: 8) {
                TextField("add a thought…", text: $draft, axis: .vertical)
                    .font(Typography.input)
                    .foregroundStyle(Theme.ink)
                    .tint(Theme.ink)
                    .lineLimit(1...4)
                    .focused($focused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(focused ? Theme.canvas : Theme.surfaceSoft)
                    .overlay(
                        RoundedRectangle(cornerRadius: interactiveRadius)
                            .stroke(focused ? Theme.ink : Theme.hairline, lineWidth: 1)
                    )
                    .clipShape(.rect(cornerRadius: interactiveRadius))

                Button {} label: {
                    Text(Glyphs.add)
                        .font(Typography.button)
                        .foregroundStyle(Theme.onInk)
                        .frame(width: 48, height: 48)
                        .background(draft.isEmpty ? Theme.disabled : Theme.ink)
                        .clipShape(.rect(cornerRadius: interactiveRadius))
                }
                .buttonStyle(.plain)
                .disabled(draft.isEmpty)

                Button {} label: {
                    RecordGlyph()
                        .frame(width: 48, height: 48)
                        .background(Theme.canvas)
                        .overlay(
                            RoundedRectangle(cornerRadius: interactiveRadius)
                                .stroke(Theme.hairline, lineWidth: 1)
                        )
                        .clipShape(.rect(cornerRadius: interactiveRadius))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Theme.canvas)
    }
}
