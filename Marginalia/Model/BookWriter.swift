import Foundation
import SwiftData

/// The one path a book takes to exist, and the one path it changes by.
///
/// Books arrive three ways — search, barcode, and typed by hand — but all three
/// fill the same `BookDraft` and land here, so the trimming and the clamping
/// can't drift apart between them. The same bargain `NoteWriter` makes.
enum BookWriter {

    /// Adds the book and returns it, or `nil` when there was nothing to add.
    @discardableResult
    static func add(
        _ draft: BookDraft,
        in context: ModelContext,
        now: Date = .now
    ) throws -> Book? {
        guard draft.canSave else { return nil }

        let book = Book(
            title: draft.bookTitle,
            author: draft.bookAuthor,
            status: draft.status,
            pageCount: draft.pageCount,
            isbn: draft.isbn,
            createdAt: now
        )
        context.insert(book)
        try context.save()
        return book
    }

    /// Corrects a book in place. Returns `false` when the draft had nothing
    /// worth writing, leaving the book as it was.
    ///
    /// **The Inbox keeps its status whatever the form says.** It's the drawer
    /// every unfiled capture falls back to, found by status, and an Inbox
    /// marked `reading` would quietly stop being one — the next quick capture
    /// would build a second.
    @discardableResult
    static func apply(
        _ draft: BookDraft,
        to book: Book,
        in context: ModelContext
    ) throws -> Bool {
        guard draft.canSave else { return false }

        book.title = draft.bookTitle
        book.author = draft.bookAuthor
        book.pageCount = draft.pageCount
        if book.status != .inbox { book.status = draft.status }
        if let isbn = draft.isbn, !isbn.isEmpty { book.isbn = isbn }

        try context.save()
        return true
    }
}
