import Foundation

/// Which notes a query finds, and which book they sit under.
///
/// **Pure**, like `ReviewSetBuilder` and `CrossingFinder`: plain records in, plain
/// results out, no `ModelContext` anywhere near it. `SearchView` is the half
/// that reads the store.
///
/// A note is searched by everything that is *about* it — its own text, the
/// thread under it, its tags, and the book it came from. Searching `Kahneman`
/// and being told nothing was found, while four notes from *Thinking, Fast and
/// Slow* sit in the library, would read as a broken field.
nonisolated enum SearchIndex {

    /// One note, flattened. The book's title and author are carried per note
    /// rather than looked up, so this stays a value type and the matching stays
    /// a single pass.
    struct Record: Equatable {
        let id: Int
        let text: String
        let tags: [String]
        /// The thread under the note. Searched, but never the thing shown — a
        /// hit in a follow-up returns the note it hangs under.
        let followUps: [String]
        let book: String
        let author: String

        init(
            id: Int,
            text: String,
            tags: [String] = [],
            followUps: [String] = [],
            book: String = "",
            author: String = ""
        ) {
            self.id = id
            self.text = text
            self.tags = tags
            self.followUps = followUps
            self.book = book
            self.author = author
        }
    }

    /// Note ids under one book title. The view turns the ids back into rows.
    struct Group: Equatable, Identifiable {
        let book: String
        let notes: [Int]

        var id: String { book }
    }

    /// The matches, grouped.
    ///
    /// Records arrive in the order they should read within a group — newest
    /// first, as the stream sorts them — and that order is preserved. **Groups
    /// are ordered by how much each book had to say**, most first, ties on
    /// title: a search for `attention` is answered best by the book that
    /// answers it four times.
    static func results(for query: SearchQuery, in records: [Record]) -> [Group] {
        guard !query.isEmpty else { return [] }

        var order: [String] = []
        var found: [String: [Int]] = [:]

        for record in records where matches(query, record) {
            if found[record.book] == nil { order.append(record.book) }
            found[record.book, default: []].append(record.id)
        }

        return order
            .map { Group(book: $0, notes: found[$0] ?? []) }
            .sorted { a, b in
                a.notes.count == b.notes.count
                    ? a.book.localizedCaseInsensitiveCompare(b.book) == .orderedAscending
                    : a.notes.count > b.notes.count
            }
    }

    /// How many notes a query found, across every book. The header's count.
    static func count(of groups: [Group]) -> Int {
        groups.reduce(0) { $0 + $1.notes.count }
    }

    // MARK: Matching

    /// **Every** term and **every** tag, not any — a second word narrows.
    private static func matches(_ query: SearchQuery, _ record: Record) -> Bool {
        let tags = Set(record.tags.map(TagIndex.normalized))
        guard query.tags.allSatisfy(tags.contains) else { return false }

        guard !query.terms.isEmpty else { return true }
        let haystack = self.haystack(record, tags: tags)
        return query.terms.allSatisfy { haystack.contains($0) }
    }

    /// Everything about a note that is worth searching, lowercased once.
    ///
    /// Tags are in here as well as in the tag filter, so `attention` typed
    /// without a hash still finds a note tagged with it — the hash narrows a
    /// search, it isn't the only way to make one.
    private static func haystack(_ record: Record, tags: Set<String>) -> String {
        var parts = [record.text, record.book, record.author]
        parts.append(contentsOf: record.followUps)
        parts.append(contentsOf: tags)
        return parts.joined(separator: "\n").lowercased()
    }
}
