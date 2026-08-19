import Foundation
import SwiftData

/// The store, and what has to be true about it before the first screen draws.
enum Library {

    static let schema = Schema(versionedSchema: LibrarySchemaV1.self)

    /// The one place the app decides whether it has a library, and the whole of
    /// what has to be true before the first screen draws.
    ///
    /// **There is no in-memory fallback here, deliberately.** Opening a
    /// temporary store when the real one won't open gives the reader an app
    /// that looks fine, takes every note they write, and drops all of them on
    /// quit. `docs/issues.md` §7. A throw from here reaches `StoreFailureView`,
    /// which says the notes are still on the disk and prints what went wrong.
    ///
    /// `makeContainer` is an injection point for the tests, and nothing else
    /// passes it — a store that refuses to open is otherwise reachable only by
    /// corrupting one.
    static func open(
        bootstrap: Bootstrap = .empty,
        makeContainer: () throws -> ModelContainer = { try .marginalia() }
    ) throws -> ModelContainer {
        let store = try makeContainer()
        // A library that won't prepare is a library that would hand out `n.11`
        // twice, so it fails exactly the way one that won't open does.
        try prepare(store.mainContext, bootstrap: bootstrap)
        return store
    }

    /// What a store that has never been opened before is given.
    ///
    /// **There is no default, on purpose.** A reader's first launch and a
    /// screenshot pass want opposite things, and the expensive mistake — which
    /// is the one the app shipped with until phase 15 — is the sample library
    /// arriving somewhere nobody asked for it. Every caller says which.
    enum Bootstrap: Equatable {
        /// The Inbox, and nothing else. What a real first launch gets.
        case empty
        /// The Inbox, the sample books, and `notes` of the sample notes —
        /// `nil` for all forty. **Tests and screenshots only; this does not
        /// ship.** `docs/decisions.md` §25.
        case sample(notes: Int?)
    }

    /// Runs on every launch. Bootstraps a store that has nothing in it, then
    /// makes sure the id counter is ahead of everything already in it.
    ///
    /// The second half matters even when nothing was written: the store can
    /// outlive its `UserDefaults` — a reinstall over an existing container, or
    /// a restore that carries the database but not the domain — and a counter
    /// that restarted at 1 would hand out ids that already exist.
    ///
    /// **`.empty` still writes one book.** The Inbox is a `Book` found by
    /// status, and the whole app leans on it existing: `NoteWriter` falls back
    /// to it, `BookWriter.apply` and `Eraser.delete(book:)` both refuse to
    /// touch it, and `CrossingFinder` excludes it as a source. Bootstrapping it
    /// is the actual work here — "no seed" was never the same thing as "no
    /// books".
    ///
    /// `.sample(notes:)` is `-tinyLibrary 2`: that many notes instead of all
    /// forty, so review's empty state and an exhausted `[↻] keep going` — both
    /// of which need a library smaller than the seed — are reachable at all.
    /// The books are all seeded either way; it's the note count both states
    /// turn on.
    static func prepare(
        _ context: ModelContext,
        now: Date = .now,
        counter: ShortIDCounter = ShortIDCounter(),
        calendar: Calendar = .current,
        bootstrap: Bootstrap
    ) throws {
        if try context.fetchCount(FetchDescriptor<Book>()) == 0 {
            switch bootstrap {
            case .empty:
                context.insert(Book(title: Inbox.title, author: Inbox.author,
                                    status: .inbox, createdAt: now))
            case .sample(let notes):
                seed(into: context, now: now, calendar: calendar, noteLimit: notes)
            }
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
                            pageCount: seed.pageCount,
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
            migrationPlan: LibraryMigration.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
    }
}

// MARK: Versions

/// The schema as it shipped first.
///
/// **Why this exists before there is anything to migrate.** An unversioned
/// `Schema` stamps no version into the store, so the day a model changes in a
/// way SwiftData can't infer, the store simply won't open — and with no
/// in-memory fallback (see `MarginaliaApp`) that is every existing reader
/// looking at `StoreFailureView` after an update they didn't ask for. Naming
/// version 1 costs nothing today and is the only thing a version 2 can migrate
/// *from*.
enum LibrarySchemaV1: VersionedSchema {
    nonisolated(unsafe) static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Book.self, Note.self, FollowUp.self, NoteEdge.self]
    }
}

/// How the store gets from one version to the next. One version so far, so
/// there are no stages yet.
///
/// **Adding a version 2 is a specific piece of work, not an edit to this list.**
/// SwiftData migrates between *snapshots* of the model types, so a `V2` has to
/// carry its own copies of whatever changed rather than pointing at the live
/// ones — otherwise both versions describe the same current types and the
/// migration is a no-op that silently does nothing. The additive cases
/// (a new property with a default, a new model) are `.lightweight`; anything
/// that renames, retypes or moves data is `.custom` and needs the `willMigrate`
/// / `didMigrate` pair to carry it across.
///
/// Whatever the change, it wants a test that opens a store written by the
/// previous version and reads it back — `docs/issues.md` §7 is the reminder of
/// what the failure looks like when nobody checks.
enum LibraryMigration: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [LibrarySchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
