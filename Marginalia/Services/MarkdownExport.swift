import Foundation

/// The whole library as one Markdown document.
///
/// **Pure**, like `ReviewSetBuilder` and `SearchIndex`: plain records in, a
/// string out. The only thing in this file that touches the disk is `file(_:)`
/// at the bottom, which exists because `ShareLink` hands over a URL and a note
/// that arrives as a `.md` file can be filed, and one that arrives as a blob of
/// text can only be pasted.
///
/// The shape is the app's own, written down: one section per book, notes in the
/// order they were written, connections as `[[n.05]]` wiki-links so an Obsidian
/// vault understands them, and a thread as a blockquote nested one level under
/// whatever it answers.
nonisolated enum MarkdownExport {

    // MARK: What goes in

    struct Note: Equatable {
        let id: Int
        /// `quote`, `thought`, `voice`, `scan` — the word, not the marker. A
        /// bracketed glyph is a thing the app draws, not a thing a document
        /// says. As of phase 13 the app doesn't draw one here either: the rule
        /// this file wrote down turned out to be about redundancy rather than
        /// about documents. `docs/decisions.md` §22.
        let kind: String
        let text: String
        let isQuote: Bool
        let page: Int?
        let tags: [String]
        let createdAt: Date
        let isStarred: Bool
        let followUps: [FollowUp]
        /// Connected note ids, both directions, as `ConnectionIndex` reads them.
        let links: [Int]

        init(
            id: Int,
            kind: String = "thought",
            text: String = "",
            isQuote: Bool = false,
            page: Int? = nil,
            tags: [String] = [],
            createdAt: Date = .distantPast,
            isStarred: Bool = false,
            followUps: [FollowUp] = [],
            links: [Int] = []
        ) {
            self.id = id
            self.kind = kind
            self.text = text
            self.isQuote = isQuote
            self.page = page
            self.tags = tags
            self.createdAt = createdAt
            self.isStarred = isStarred
            self.followUps = followUps
            self.links = links
        }
    }

    struct FollowUp: Equatable {
        let text: String
        let createdAt: Date

        init(text: String, createdAt: Date = .distantPast) {
            self.text = text
            self.createdAt = createdAt
        }
    }

    struct Book: Equatable {
        let title: String
        let author: String
        let status: String
        /// Oldest first — a book reads forward, and so does an export of it.
        let notes: [Note]

        init(title: String, author: String = "", status: String = "", notes: [Note] = []) {
            self.title = title
            self.author = author
            self.status = status
            self.notes = notes
        }
    }

    // MARK: What comes out

    /// The document. Books arrive in the order they should read — the shelf's
    /// order, which is the library's — and books with nothing in them are left
    /// out, because an export is the notes.
    static func document(_ books: [Book], exported: Date, calendar: Calendar = .current) -> String {
        let written = books.filter { !$0.notes.isEmpty }
        let notes = written.reduce(0) { $0 + $1.notes.count }

        var lines = ["# marginalia", ""]
        lines.append(notes == 0
                     ? "no notes yet · exported \(day(exported, calendar))"
                     : "\(count(notes, "note")) from \(count(written.count, "book"))"
                        + " · exported \(day(exported, calendar))")

        for book in written {
            lines.append(contentsOf: section(book, calendar))
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private static func section(_ book: Book, _ calendar: Calendar) -> [String] {
        var lines = ["", "## \(book.title)"]

        // An unknown author closes up rather than leaving a stray separator —
        // the same rule the book row follows on screen.
        let byline = [book.author, book.status].filter { !$0.isEmpty }.joined(separator: " · ")
        if !byline.isEmpty { lines.append(byline) }

        for note in book.notes {
            lines.append(contentsOf: entry(note, calendar))
        }
        return lines
    }

    private static func entry(_ note: Note, _ calendar: Calendar) -> [String] {
        var lines = ["", "### \(Glyphs.noteID(note.id))", meta(note, calendar), ""]

        // A quote is quoted matter, so it's a blockquote. A thought is the
        // document's own voice and is a paragraph.
        lines.append(note.isQuote ? quoted(note.text, depth: 1) : note.text)

        // **Nested one level under whatever it answers**, which is why the depth
        // is computed rather than fixed: a thread under a quote sits inside the
        // quote it grew out of.
        for followUp in note.followUps {
            lines.append("")
            lines.append(quoted("\(day(followUp.createdAt, calendar)) · \(followUp.text)",
                                depth: note.isQuote ? 2 : 1))
        }

        if !note.links.isEmpty {
            lines.append("")
            lines.append(note.links.sorted()
                .map { "[[\(Glyphs.noteID($0))]]" }
                .joined(separator: " · "))
        }

        return lines
    }

    /// `thought · 2026-08-01 · p.214 · #attention #memory`, minus whatever this
    /// note hasn't got. **No marker** — this comment used to illustrate itself
    /// with `[t] thought`, which the code has never emitted.
    private static func meta(_ note: Note, _ calendar: Calendar) -> String {
        var parts = [note.kind, day(note.createdAt, calendar)]
        if let page = note.page, page > 0 { parts.append("p.\(page)") }

        let tags = note.tags.map(TagIndex.normalized).filter { !$0.isEmpty }
        if !tags.isEmpty { parts.append(tags.map(Glyphs.tag).joined(separator: " ")) }
        if note.isStarred { parts.append("starred") }

        return parts.joined(separator: " · ")
    }

    /// A blockquote at `depth`, every line of it. A body that wraps across
    /// paragraphs is still one quotation, and a bare `>` on the blank line
    /// between them is what keeps it that way.
    private static func quoted(_ text: String, depth: Int) -> String {
        let marker = String(repeating: ">", count: max(1, depth))
        return text
            .components(separatedBy: "\n")
            .map { $0.isEmpty ? marker : "\(marker) \($0)" }
            .joined(separator: "\n")
    }

    /// `2026-08-14`. Sortable, unambiguous, and the same in every locale — an
    /// export is a document somebody else's software will read, so `aug 14` and
    /// `2 mins ago` both belong to the screen rather than to this.
    private static func day(_ date: Date, _ calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private static func count(_ n: Int, _ noun: String) -> String {
        "\(n) \(noun)\(n == 1 ? "" : "s")"
    }

    // MARK: Leaving the app

    /// `marginalia-2026-08-14.md`, in a temporary directory, for `ShareLink`.
    ///
    /// The impure half, and deliberately the whole of it: everything above this
    /// line is testable without a disk.
    static func file(_ document: String, on date: Date, calendar: Calendar = .current) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "marginalia-\(day(date, calendar)).md")
        try document.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
