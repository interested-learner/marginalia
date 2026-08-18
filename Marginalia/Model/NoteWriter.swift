import Foundation
import SwiftData

/// Writes a capture into the store. The one path a note takes to exist.
///
/// Both entry points go through here — the stream bar's fast path and the full
/// sheet — so the id allocation, the trimming, and the Inbox fallback can't
/// drift apart between them.
enum NoteWriter {

    /// Saves the draft and returns the note, or `nil` when there was nothing to
    /// save. A refused save spends no id: a gap in the sequence reads as a
    /// deleted note, and this wasn't one.
    ///
    /// A `nil` book means the Inbox, which is a `Book` like any other — that's
    /// what keeps unfiled captures from being invisible.
    @discardableResult
    static func save(
        _ draft: CaptureDraft,
        to book: Book? = nil,
        in context: ModelContext,
        counter: ShortIDCounter = ShortIDCounter(),
        now: Date = .now
    ) throws -> Note? {
        guard draft.canSave else { return nil }

        let note = Note(
            shortID: counter.next(),
            kind: draft.kind,
            text: draft.body,
            page: draft.pageNumber,
            tags: draft.tagList,
            createdAt: now,
            book: try book ?? inbox(in: context, now: now)
        )
        context.insert(note)
        try context.save()
        return note
    }

    /// Moves a note that was already written to a different book.
    ///
    /// **The Inbox has never been a one-way drawer in the spec** — the stream
    /// bar's fast path is described as filing "to be filed later", and until now
    /// there was no later. This is it, and it is the one path a note takes to
    /// change hands, for the same reason `save` is the one path it takes to
    /// exist.
    ///
    /// The note's id, its thread, its tags and its page all stay. So does its
    /// embedding: moving a note doesn't change a word of it, and same-book is
    /// deliberately not a term in `AffinityEngine`, so nothing about the graph
    /// depends on which book a note is filed under.
    ///
    /// `nil` means the Inbox, exactly as it does in `save`.
    static func refile(
        _ note: Note,
        to book: Book?,
        in context: ModelContext,
        now: Date = .now
    ) throws {
        let destination = try book ?? inbox(in: context, now: now)
        guard note.book != destination else { return }

        note.book = destination
        try context.save()
    }

    /// The Inbox is seeded on first launch, but a store can lose it — deleted
    /// by hand, or arriving from a sync that never had one. Recreating it beats
    /// swallowing the note the user just wrote.
    private static func inbox(in context: ModelContext, now: Date) throws -> Book {
        let inbox = BookStatus.inbox.rawValue
        var descriptor = FetchDescriptor<Book>(predicate: #Predicate { $0.statusRaw == inbox })
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first { return existing }

        let book = Book(title: Inbox.title, author: Inbox.author,
                        status: .inbox, createdAt: now)
        context.insert(book)
        return book
    }
}
