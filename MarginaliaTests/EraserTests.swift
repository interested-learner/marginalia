import Foundation
import SwiftData
import Testing
@testable import Marginalia

/// The one path anything takes to stop existing, against a real in-memory store.
///
/// The interesting half is what a delete takes *with* it. Follow-ups and a
/// book's notes are cascaded by the schema; edges are not, and an edge left
/// behind with one end nil is a connection that can never be drawn again and
/// never be swept up.
@MainActor
struct EraserTests {

    private func store() throws -> ModelContext {
        ModelContext(try ModelContainer.marginalia(inMemory: true))
    }

    private func note(_ shortID: Int, in context: ModelContext, book: Book? = nil) -> Note {
        let note = Note(shortID: shortID, kind: .thought, text: "note \(shortID)", book: book)
        context.insert(note)
        return note
    }

    // MARK: Notes

    @Test func deletingANoteRemovesEveryEdgeThatTouchedIt() throws {
        let context = try store()
        let a = note(1, in: context), b = note(2, in: context), c = note(3, in: context)
        context.insert(NoteEdge(from: a, to: b))
        context.insert(NoteEdge(from: c, to: a))   // the other direction too
        context.insert(NoteEdge(from: b, to: c))
        try context.save()

        try Eraser.delete(a, in: context)

        let left = try context.fetch(FetchDescriptor<NoteEdge>())
        #expect(left.count == 1)
        #expect(left.first?.from?.shortID == 2)
        #expect(left.first?.to?.shortID == 3)
    }

    @Test func deletingANoteTakesItsThreadWithIt() throws {
        let context = try store()
        let a = note(1, in: context)
        context.insert(FollowUp(text: "a later thought", note: a))
        try context.save()

        try Eraser.delete(a, in: context)

        #expect(try context.fetchCount(FetchDescriptor<Note>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<FollowUp>()) == 0)
    }

    /// Dangling edges — both ends already gone — can only have arrived from a
    /// delete that happened before this file existed. Nothing else will ever
    /// sweep them, so a delete that passes nearby does.
    @Test func aDanglingEdgeIsSweptUp() throws {
        let context = try store()
        let a = note(1, in: context)
        context.insert(NoteEdge(from: nil, to: nil))
        try context.save()

        try Eraser.delete(a, in: context)

        #expect(try context.fetchCount(FetchDescriptor<NoteEdge>()) == 0)
    }

    // MARK: Books

    @Test func deletingABookTakesItsNotesAndTheirEdges() throws {
        let context = try store()
        let book = Book(title: "Meditations", status: .finished)
        context.insert(book)
        let mine = note(1, in: context, book: book)
        let theirs = note(2, in: context)
        context.insert(FollowUp(text: "under a doomed note", note: mine))
        context.insert(NoteEdge(from: mine, to: theirs))
        try context.save()

        #expect(try Eraser.delete(book, in: context))

        #expect(try context.fetchCount(FetchDescriptor<Book>()) == 0)
        #expect(try context.fetch(FetchDescriptor<Note>()).map(\.shortID) == [2])
        #expect(try context.fetchCount(FetchDescriptor<FollowUp>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<NoteEdge>()) == 0)
    }

    /// The Inbox is found by status and is where every unfiled capture lands.
    /// Deleting it would take the quick captures with it and the next one would
    /// silently build a second drawer.
    @Test func theInboxIsRefused() throws {
        let context = try store()
        let inbox = Book(title: Inbox.title, author: Inbox.author, status: .inbox)
        context.insert(inbox)
        _ = note(1, in: context, book: inbox)
        try context.save()

        #expect(try Eraser.delete(inbox, in: context) == false)
        #expect(try context.fetchCount(FetchDescriptor<Book>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Note>()) == 1)
    }

    // MARK: Follow-ups

    @Test func deletingAThoughtLeavesTheNoteAlone() throws {
        let context = try store()
        let a = note(1, in: context)
        let first = FollowUp(text: "first", createdAt: .now.addingTimeInterval(-60), note: a)
        let second = FollowUp(text: "second", createdAt: .now, note: a)
        context.insert(first)
        context.insert(second)
        try context.save()

        try Eraser.delete(first, in: context)

        #expect(try context.fetchCount(FetchDescriptor<Note>()) == 1)
        #expect(try context.fetch(FetchDescriptor<FollowUp>()).map(\.text) == ["second"])
    }

    // MARK: Connections

    /// The one delete that doesn't remove the row, and the reason it doesn't:
    /// the next recompute would score the same pair, find it just as strong,
    /// and draw the line straight back.
    @Test func disconnectingKeepsTheEdgeAndMarksIt() throws {
        let context = try store()
        let a = note(1, in: context), b = note(2, in: context)
        let edge = NoteEdge(from: a, to: b, score: 0.7)
        context.insert(edge)
        try context.save()

        try Eraser.suppress(edge, in: context)

        #expect(try context.fetch(FetchDescriptor<NoteEdge>()).count == 1)
        #expect(edge.isSuppressed)
    }

    /// Suppression beats pinning, the same resolution `LinkWriter` makes: it's
    /// the more recent deliberate act.
    @Test func disconnectingAPinnedConnectionUnpinsIt() throws {
        let context = try store()
        let edge = NoteEdge(from: note(1, in: context), to: note(2, in: context), isPinned: true)
        context.insert(edge)
        try context.save()

        try Eraser.suppress(edge, in: context)

        #expect(edge.isSuppressed)
        #expect(!edge.isPinned)
    }

    /// And every surface stops drawing it at once — the stream and book detail
    /// read edges through `ConnectionIndex`, the map through its own pass, and
    /// a line that survived in one of them would be a bug in that one.
    @Test func aDisconnectedPairIsDrawnNowhere() throws {
        let context = try store()
        let edge = NoteEdge(from: note(1, in: context), to: note(2, in: context))
        context.insert(edge)
        try context.save()

        #expect(ConnectionIndex.build(edges: [edge]) == [1: [2], 2: [1]])

        try Eraser.suppress(edge, in: context)

        #expect(ConnectionIndex.build(edges: [edge]).isEmpty)
    }

    /// **The question doesn't name the two ids**, because the crossing card it
    /// is asked from no longer draws them — `docs/decisions.md` §22. It would be
    /// precise about something the reader has never seen on that screen. What
    /// goes is in the consequence, which is what the question is for.
    @Test func aConnectionAsksAboutTheTwoNotesWithoutNamingThem() throws {
        let context = try store()
        let edge = NoteEdge(from: note(11, in: context), to: note(7, in: context))
        context.insert(edge)

        #expect(Erasure.connection(edge).title == "disconnect these two notes?")
        #expect(Erasure.connection(edge).title.contains("n.07") == false)
        #expect(Erasure.connection(edge).confirmTitle.contains("disconnect"))
        #expect(Erasure.connection(edge).consequence.contains("only the line between them goes"))
    }

    // MARK: What the confirmation is about to do

    /// A thread row knows its position, not its identity — `Erasure.thought`
    /// is what turns one back into the other, and it has to index into the same
    /// order the rows were built from.
    @Test func aThoughtIsFoundByItsPositionInTheThread() throws {
        let context = try store()
        let a = note(1, in: context)
        context.insert(FollowUp(text: "second", createdAt: .now, note: a))
        context.insert(FollowUp(text: "first", createdAt: .now.addingTimeInterval(-60), note: a))
        try context.save()

        guard case .followUp(let found)? = Erasure.thought(0, of: a) else {
            Issue.record("expected the oldest thought")
            return
        }
        #expect(found.text == "first")
        #expect(Erasure.thought(2, of: a) == nil)
    }

    @Test func aBookSaysWhatItWillTakeWithIt() throws {
        let context = try store()
        let book = Book(title: "Meditations", status: .finished)
        context.insert(book)
        _ = note(1, in: context, book: book)
        try context.save()

        #expect(Erasure.book(book).title == "delete Meditations?")
        #expect(Erasure.book(book).consequence.contains("1 note"))

        let empty = Book(title: "The Beginning of Infinity", status: .queued)
        context.insert(empty)
        #expect(Erasure.book(empty).consequence.contains("no notes"))
    }
}
