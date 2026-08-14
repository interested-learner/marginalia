import Foundation

/// The seam between the models and the design system.
///
/// Views take `NoteRowData` and `BookRowData` and know nothing about SwiftData;
/// this file is the only place that knows about both. Keeping it that way is
/// what let the whole design system be built and judged before the model
/// existed, and it's worth preserving for the same reason going forward.
extension NoteRowData {

    /// `showingBook` is false on book detail, where every row would otherwise
    /// repeat the title already at the top of the screen.
    init(
        _ note: Note,
        connections: [Int] = [],
        showingBook: Bool = true,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        self.init(
            id: note.shortID,
            idLabel: note.idLabel,
            meta: "\(note.kind.marker) \(note.kind.label) · "
                + RelativeTime.label(for: note.createdAt, now: now, calendar: calendar),
            text: note.text,
            isQuote: note.kind == .quote,
            source: Self.source(for: note, showingBook: showingBook),
            links: connections,
            followUps: Self.thread(for: note, now: now, calendar: calendar),
            isStarred: note.isStarred
        )
    }

    /// Oldest first. A thread reads forward — it's a conversation with yourself,
    /// and the answer comes after the thing it answers.
    private static func thread(
        for note: Note,
        now: Date,
        calendar: Calendar
    ) -> [FollowUpRowData] {
        (note.followUps ?? [])
            .sorted { $0.createdAt < $1.createdAt }
            .enumerated()
            .map { position, followUp in
                FollowUpRowData(
                    id: position,
                    when: RelativeTime.label(for: followUp.createdAt, now: now, calendar: calendar),
                    text: followUp.text
                )
            }
    }

    /// `Thinking, Fast and Slow · p.214 · #error #quality`
    ///
    /// Three segments, and an absent one closes up rather than leaving `p.0` or
    /// a trailing separator. Tags share the last segment so the `·` keeps
    /// meaning book / page / tags instead of becoming a list delimiter.
    private static func source(for note: Note, showingBook: Bool) -> String {
        var segments: [String] = []
        if showingBook, let title = note.book?.title, !title.isEmpty { segments.append(title) }
        if let page = note.page, page > 0 { segments.append("p.\(page)") }
        let tags = note.tags.map(TagIndex.normalized).filter { !$0.isEmpty }
        if !tags.isEmpty { segments.append(tags.map(Glyphs.tag).joined(separator: " ")) }
        return segments.joined(separator: " · ")
    }
}

extension BookRowData {
    init(_ book: Book) {
        self.init(
            marker: book.status.marker,
            title: book.title,
            author: book.author,
            status: book.status.label,
            count: book.noteCount
        )
    }
}

extension ConnectionIndex {

    /// Edges as stored → who connects to whom, both directions. The stream and
    /// book detail both draw connections, and reading the edges two ways would
    /// be a bug in one of them.
    static func build(edges: [NoteEdge]) -> [Int: [Int]] {
        build(from: edges.compactMap { edge in
            guard !edge.isSuppressed, let from = edge.from, let to = edge.to else { return nil }
            return (from: from.shortID, to: to.shortID)
        })
    }
}
