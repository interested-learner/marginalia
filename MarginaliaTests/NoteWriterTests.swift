import Testing
import Foundation
import SwiftData
@testable import Marginalia

/// Writing a capture into the store — the first thing in this app that writes
/// anything at all.
///
/// Against a real in-memory container rather than a stub, for the same reason
/// `LibraryStoreTests` is: the interesting failures are SwiftData's.
@MainActor
struct NoteWriterTests {

    private func defaults() -> UserDefaults {
        let name = "marginalia.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func library() throws -> (ModelContext, ShortIDCounter) {
        let context = ModelContext(try ModelContainer.marginalia(inMemory: true))
        let counter = ShortIDCounter(defaults: defaults())
        try Library.prepare(context, counter: counter)
        return (context, counter)
    }

    private func notes(_ context: ModelContext) throws -> [Note] {
        try context.fetch(FetchDescriptor<Note>(sortBy: [SortDescriptor(\.shortID)]))
    }

    private func inbox(_ context: ModelContext) throws -> Book {
        try #require(try context.fetch(FetchDescriptor<Book>()).first { $0.status == .inbox })
    }

    // MARK: The fast path

    /// The stream bar files a thought with no book, and unfiled captures have
    /// to land somewhere visible rather than nowhere.
    @Test func aQuickCaptureLandsInTheInbox() throws {
        let (context, counter) = try library()
        let note = try #require(try NoteWriter.save(CaptureDraft(text: "a thought"),
                                                    in: context, counter: counter))
        #expect(note.book?.status == .inbox)
    }

    @Test func aQuickCaptureIsPersisted() throws {
        let (context, counter) = try library()
        let before = try notes(context).count
        _ = try NoteWriter.save(CaptureDraft(text: "a thought"), in: context, counter: counter)
        #expect(try notes(context).count == before + 1)
    }

    @Test func aQuickCaptureKeepsTheKindItWasGiven() throws {
        let (context, counter) = try library()
        let note = try #require(try NoteWriter.save(CaptureDraft(kind: .voice, text: "spoken"),
                                                    in: context, counter: counter))
        #expect(note.kind == .voice)
    }

    /// Ids come from the monotonic counter, never from `max(shortID) + 1`.
    @Test func aCaptureTakesTheNextUnusedID() throws {
        let (context, counter) = try library()
        let highest = try #require(try notes(context).map(\.shortID).max())
        let note = try #require(try NoteWriter.save(CaptureDraft(text: "a thought"),
                                                    in: context, counter: counter))
        #expect(note.shortID == highest + 1)
    }

    @Test func twoCapturesGetDifferentIDs() throws {
        let (context, counter) = try library()
        let first = try #require(try NoteWriter.save(CaptureDraft(text: "one"), in: context, counter: counter))
        let second = try #require(try NoteWriter.save(CaptureDraft(text: "two"), in: context, counter: counter))
        #expect(first.shortID != second.shortID)
    }

    @Test func aCaptureIsStampedWithTheMomentItWasWritten() throws {
        let (context, counter) = try library()
        let when = Date(timeIntervalSince1970: 1_760_000_000)
        let note = try #require(try NoteWriter.save(CaptureDraft(text: "a thought"),
                                                    in: context, counter: counter, now: when))
        #expect(note.createdAt == when)
    }

    // MARK: Nothing to save

    @Test func anEmptyDraftWritesNothing() throws {
        let (context, counter) = try library()
        let before = try notes(context).count
        #expect(try NoteWriter.save(CaptureDraft(text: "   "), in: context, counter: counter) == nil)
        #expect(try notes(context).count == before)
    }

    /// A refused save must not burn an id — the next real note would then open
    /// a gap that looks like a deleted note.
    @Test func anEmptyDraftDoesNotSpendAnID() throws {
        let (context, counter) = try library()
        let highest = try #require(try notes(context).map(\.shortID).max())
        _ = try NoteWriter.save(CaptureDraft(text: ""), in: context, counter: counter)
        let note = try #require(try NoteWriter.save(CaptureDraft(text: "real"),
                                                    in: context, counter: counter))
        #expect(note.shortID == highest + 1)
    }

    // MARK: The full sheet

    @Test func capturingToABookFilesItUnderThatBook() throws {
        let (context, counter) = try library()
        let book = try #require(try context.fetch(FetchDescriptor<Book>()).first { $0.status == .reading })
        let note = try #require(try NoteWriter.save(CaptureDraft(kind: .quote, text: "quoted"),
                                                    to: book, in: context, counter: counter))
        #expect(note.book?.title == book.title)
        #expect(book.notes?.contains { $0.shortID == note.shortID } == true)
    }

    @Test func thePageIsCarriedOver() throws {
        let (context, counter) = try library()
        let draft = CaptureDraft(kind: .quote, text: "quoted", page: "p.214")
        let note = try #require(try NoteWriter.save(draft, in: context, counter: counter))
        #expect(note.page == 214)
    }

    @Test func tagsReachTheStoreBare() throws {
        let (context, counter) = try library()
        let draft = CaptureDraft(text: "a thought", tags: "#Attention, memory")
        let note = try #require(try NoteWriter.save(draft, in: context, counter: counter))
        #expect(note.tags == ["attention", "memory"])
    }

    @Test func theStoredTextIsTrimmed() throws {
        let (context, counter) = try library()
        let note = try #require(try NoteWriter.save(CaptureDraft(text: "  spaced  "),
                                                    in: context, counter: counter))
        #expect(note.text == "spaced")
    }

    // MARK: The Inbox

    @Test func repeatedQuickCapturesShareOneInbox() throws {
        let (context, counter) = try library()
        _ = try NoteWriter.save(CaptureDraft(text: "one"), in: context, counter: counter)
        _ = try NoteWriter.save(CaptureDraft(text: "two"), in: context, counter: counter)
        #expect(try context.fetch(FetchDescriptor<Book>()).filter { $0.status == .inbox }.count == 1)
    }

    /// A store that lost its Inbox — deleted by hand, or arriving from a sync
    /// that never had one — must not swallow the capture.
    @Test func aMissingInboxIsRecreatedRatherThanLosingTheNote() throws {
        let (context, counter) = try library()
        context.delete(try inbox(context))
        try context.save()

        let note = try #require(try NoteWriter.save(CaptureDraft(text: "a thought"),
                                                    in: context, counter: counter))
        #expect(note.book?.status == .inbox)
        #expect(try context.fetch(FetchDescriptor<Book>()).filter { $0.status == .inbox }.count == 1)
    }

    /// A recreated Inbox has to be the same Inbox — a second one reading
    /// `Unfiled` beside the seeded one would be two drawers, not one.
    @Test func aRecreatedInboxIsIndistinguishableFromTheSeededOne() throws {
        let (context, counter) = try library()
        let seeded = try inbox(context)
        let title = seeded.title
        let author = seeded.author
        context.delete(seeded)
        try context.save()

        let note = try #require(try NoteWriter.save(CaptureDraft(text: "a thought"),
                                                    in: context, counter: counter))
        #expect(note.book?.title == title)
        #expect(note.book?.author == author)
    }

    // MARK: Filing later

    /// The Inbox is described in the spec as somewhere a note waits "to be
    /// filed later", and until phase 11 there was no later — nothing in the app
    /// could change a note's book after it was written.
    @Test func aNoteLeavesTheInbox() throws {
        let (context, counter) = try library()
        let note = try #require(try NoteWriter.save(CaptureDraft(text: "a thought"),
                                                    in: context, counter: counter))
        #expect(note.book?.status == .inbox)

        let book = Book(title: "Meditations", status: .reading)
        context.insert(book)
        try NoteWriter.refile(note, to: book, in: context)

        #expect(note.book?.title == "Meditations")
        #expect(book.notes?.contains { $0.shortID == note.shortID } == true)
    }

    /// And goes back in, because `nil` means the Inbox here exactly as it does
    /// in `save` — a note filed to the wrong book has to be recoverable by the
    /// same door it left through.
    @Test func aNoteGoesBackToTheInbox() throws {
        let (context, counter) = try library()
        let book = Book(title: "Meditations", status: .reading)
        context.insert(book)

        let note = try #require(try NoteWriter.save(CaptureDraft(text: "a thought"),
                                                    to: book, in: context, counter: counter))
        try NoteWriter.refile(note, to: nil, in: context)

        #expect(note.book?.status == .inbox)
    }

    /// Everything about the note except which shelf it sits on. The id above
    /// all: a note that changed books and changed id would break every
    /// `→ n.11` ever written about it.
    @Test func movingANoteChangesNothingElseAboutIt() throws {
        let (context, counter) = try library()
        var draft = CaptureDraft(kind: .quote, text: "a passage")
        draft.page = "214"
        draft.tags = "#attention, memory"

        let note = try #require(try NoteWriter.save(draft, in: context, counter: counter))
        let id = note.shortID
        try ReviewWriter.followUp("a later thought", on: note, in: context)

        let book = Book(title: "Meditations", status: .reading)
        context.insert(book)
        try NoteWriter.refile(note, to: book, in: context)

        #expect(note.shortID == id)
        #expect(note.kind == .quote)
        #expect(note.page == 214)
        #expect(note.tags == ["attention", "memory"])
        #expect(note.thread.count == 1)
    }

    /// Moving a note to the book it is already in writes nothing — a `save()`
    /// on every dismissal of the sheet would invalidate every `@Query` in the
    /// app for no reason.
    @Test func movingANoteNowhereIsNotAWrite() throws {
        let (context, counter) = try library()
        let book = Book(title: "Meditations", status: .reading)
        context.insert(book)

        let note = try #require(try NoteWriter.save(CaptureDraft(text: "a thought"),
                                                    to: book, in: context, counter: counter))
        try NoteWriter.refile(note, to: book, in: context)

        #expect(note.book?.title == "Meditations")
        #expect(try context.fetchCount(FetchDescriptor<Note>()) == 41)
    }
}
