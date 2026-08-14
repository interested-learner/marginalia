import Foundation

/// The seam between the models and the design system.
///
/// Views take `NoteRowData` and `BookRowData` and know nothing about SwiftData;
/// this file is the only place that knows about both. Keeping it that way is
/// what let the whole design system be built and judged before the model
/// existed, and it's worth preserving for the same reason going forward.
extension NoteRowData {

    init(_ note: Note, connections: [Int] = [], now: Date = .now, calendar: Calendar = .current) {
        self.init(
            id: note.shortID,
            idLabel: note.idLabel,
            meta: "\(note.kind.marker) \(note.kind.label) · "
                + RelativeTime.label(for: note.createdAt, now: now, calendar: calendar),
            text: note.text,
            isQuote: note.kind == .quote,
            source: Self.source(for: note),
            links: connections
        )
    }

    /// `Thinking, Fast and Slow · p.214 · #error #quality`
    ///
    /// Three segments, and an absent one closes up rather than leaving `p.0` or
    /// a trailing separator. Tags share the last segment so the `·` keeps
    /// meaning book / page / tags instead of becoming a list delimiter.
    private static func source(for note: Note) -> String {
        var segments: [String] = []
        if let title = note.book?.title, !title.isEmpty { segments.append(title) }
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
