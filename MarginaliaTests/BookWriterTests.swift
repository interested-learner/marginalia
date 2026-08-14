import Foundation
import SwiftData
import Testing
@testable import Marginalia

/// The one path a book takes to exist, against a real in-memory store.
@MainActor
struct BookWriterTests {

    private func store() throws -> ModelContext {
        ModelContext(try ModelContainer.marginalia(inMemory: true))
    }

    @Test func addingABookWritesTheTypedValues() throws {
        let context = try store()
        let draft = BookDraft(title: "  Meditations ", author: " Marcus Aurelius ",
                              pages: "254", current: "p.47", status: .reading)

        let book = try #require(try BookWriter.add(draft, in: context))

        #expect(book.title == "Meditations")
        #expect(book.author == "Marcus Aurelius")
        #expect(book.pageCount == 254)
        #expect(book.currentPage == 47)
        #expect(book.status == .reading)
        #expect(try context.fetchCount(FetchDescriptor<Book>()) == 1)
    }

    /// A refused save leaves nothing behind.
    @Test func aBookWithNoTitleIsNotWritten() throws {
        let context = try store()

        #expect(try BookWriter.add(BookDraft(author: "nobody"), in: context) == nil)
        #expect(try context.fetchCount(FetchDescriptor<Book>()) == 0)
    }

    @Test func editingCorrectsTheBookInPlace() throws {
        let context = try store()
        let book = Book(title: "Meditation", author: "", status: .queued)
        context.insert(book)

        var draft = BookDraft(book)
        draft.title = "Meditations"
        draft.author = "Marcus Aurelius"
        draft.pages = "254"
        draft.current = "47"
        draft.status = .reading

        #expect(try BookWriter.apply(draft, to: book, in: context))
        #expect(book.title == "Meditations")
        #expect(book.status == .reading)
        #expect(book.progress == 47.0 / 254.0)
        #expect(try context.fetchCount(FetchDescriptor<Book>()) == 1)
    }

    /// The notes stay attached to the book they were filed against — correcting
    /// a title is not refiling anything.
    @Test func editingKeepsTheNotes() throws {
        let context = try store()
        let book = Book(title: "Meditation")
        context.insert(book)
        context.insert(Note(shortID: 1, text: "a thought", book: book))

        var draft = BookDraft(book)
        draft.title = "Meditations"
        try BookWriter.apply(draft, to: book, in: context)

        #expect(book.noteCount == 1)
    }

    /// **The Inbox keeps its status whatever the form says.** It's found by
    /// status and it's where every unfiled capture falls back to — an Inbox
    /// marked `reading` would quietly stop being one, and the next quick
    /// capture would build a second.
    @Test func theInboxCannotBeMarkedAsReading() throws {
        let context = try store()
        let inbox = Book(title: Inbox.title, author: Inbox.author, status: .inbox)
        context.insert(inbox)

        var draft = BookDraft(inbox)
        draft.status = .reading
        try BookWriter.apply(draft, to: inbox, in: context)

        #expect(inbox.status == .inbox)
    }

    @Test func anEmptyTitleLeavesTheBookAsItWas() throws {
        let context = try store()
        let book = Book(title: "Meditations")
        context.insert(book)

        var draft = BookDraft(book)
        draft.title = "  "

        #expect(try BookWriter.apply(draft, to: book, in: context) == false)
        #expect(book.title == "Meditations")
    }
}
