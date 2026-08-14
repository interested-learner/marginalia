import Foundation
import SwiftData

/// The store, and what has to be true about it before the first screen draws.
enum Library {

    static let schema = Schema([Book.self, Note.self, FollowUp.self, NoteEdge.self])

    /// Runs on every launch. Seeds an empty store, then makes sure the id
    /// counter is ahead of everything already in it.
    ///
    /// The second half matters even when nothing was seeded: the store can
    /// outlive its `UserDefaults` — a reinstall over an existing container, or
    /// a restore that carries the database but not the domain — and a counter
    /// that restarted at 1 would hand out ids that already exist.
    /// `noteLimit` is `-tinyLibrary 2`: seed that many notes instead of all
    /// forty, so review's empty state and an exhausted `[↻] keep going` — both
    /// of which need a library smaller than the seed — are reachable at all.
    /// The books are all seeded either way; it's the note count both states
    /// turn on.
    static func prepare(
        _ context: ModelContext,
        now: Date = .now,
        counter: ShortIDCounter = ShortIDCounter(),
        calendar: Calendar = .current,
        noteLimit: Int? = nil
    ) throws {
        if try context.fetchCount(FetchDescriptor<Book>()) == 0 {
            seed(into: context, now: now, calendar: calendar, noteLimit: noteLimit)
            try context.save()
        }

        let ids = try context.fetch(FetchDescriptor<Note>()).map(\.shortID)
        if let highest = ids.max() {
            counter.reserve(above: highest)
        }
    }

    /// The Inbox is seeded as a `Book` like any other — that's what keeps
    /// unfiled captures from being invisible.
    private static func seed(
        into context: ModelContext,
        now: Date,
        calendar: Calendar,
        noteLimit: Int? = nil
    ) {
        var books: [String: Book] = [:]
        for seed in SeedLibrary.books {
            let book = Book(title: seed.title, author: seed.author, status: seed.status,
                            pageCount: seed.pageCount, currentPage: seed.currentPage,
                            createdAt: now)
            books[seed.key] = book
            context.insert(book)
        }

        // Edges and follow-ups pointing at notes that didn't make the cut are
        // skipped below rather than being an error.
        var notes: [String: Note] = [:]
        for seed in SeedLibrary.sample(noteLimit) {
            let note = Note(kind: seed.kind, text: seed.text, page: seed.page, tags: seed.tags,
                            createdAt: SeedLibrary.date(for: seed.age, now: now, calendar: calendar),
                            isStarred: seed.starred, book: books[seed.book])
            notes[seed.key] = note
            context.insert(note)
        }

        // Ids are allocated in the order the notes were written, so `n.01` is
        // the oldest note in the library and the stream counts down from the
        // top. The sort is what guarantees it regardless of how the seed list
        // above happens to be ordered.
        for (offset, note) in notes.values.sorted(by: { $0.createdAt < $1.createdAt }).enumerated() {
            note.shortID = offset + 1
        }

        // Pinned, so phase 6's first recompute doesn't prune them.
        for seed in SeedLibrary.edges {
            guard let from = notes[seed.a], let to = notes[seed.b] else { continue }
            context.insert(NoteEdge(from: from, to: to, isPinned: true, createdAt: now))
        }

        // A few notes arrive already answered, so a fresh install shows what
        // `[+] add a thought` produces rather than only offering it.
        for seed in SeedLibrary.followUps {
            guard let note = notes[seed.note] else { continue }
            context.insert(FollowUp(
                text: seed.text,
                createdAt: SeedLibrary.date(for: seed.age, now: now, calendar: calendar),
                note: note
            ))
        }
    }
}

extension ModelContainer {
    static func marginalia(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer(
            for: Library.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
    }
}
