import Testing
import Foundation
import SwiftData
@testable import Marginalia

/// What a review card writes: a follow-up, a star, and the fact that a note was
/// seen. Against a real in-memory container, like `NoteWriterTests` — the
/// interesting failures here are SwiftData's.
@MainActor
struct ReviewWriterTests {

    private func library() throws -> (ModelContext, Note) {
        let context = ModelContext(try ModelContainer.marginalia(inMemory: true))
        let book = Book(title: "Meditations", status: .reading)
        let note = Note(shortID: 7, text: "Confine thyself to the present.", book: book)
        context.insert(book)
        context.insert(note)
        try context.save()
        return (context, note)
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private let noon = Date(timeIntervalSince1970: 1_760_000_000)

    // MARK: Follow-ups

    /// `[+] add a thought` replaces the prototype's keep/skip/later entirely —
    /// instead of judging a note you grow it. See `docs/decisions.md` §4.
    @Test func aThoughtIsThreadedUnderTheNoteItAnswers() throws {
        let (context, note) = try library()
        let followUp = try #require(try ReviewWriter.followUp("still true, ten years on",
                                                              on: note, in: context))
        #expect(followUp.note?.shortID == note.shortID)
        #expect(note.followUps?.count == 1)
    }

    @Test func aFollowUpIsPersisted() throws {
        let (context, note) = try library()
        _ = try ReviewWriter.followUp("a later thought", on: note, in: context)
        #expect(try context.fetch(FetchDescriptor<FollowUp>()).count == 1)
    }

    @Test func aFollowUpIsTrimmedLikeANoteIs() throws {
        let (context, note) = try library()
        let followUp = try #require(try ReviewWriter.followUp("  spaced  ", on: note, in: context))
        #expect(followUp.text == "spaced")
    }

    @Test func anEmptyThoughtWritesNothing() throws {
        let (context, note) = try library()
        #expect(try ReviewWriter.followUp("   ", on: note, in: context) == nil)
        #expect(try context.fetch(FetchDescriptor<FollowUp>()).isEmpty)
    }

    @Test func aFollowUpIsStampedWithTheMomentItWasWritten() throws {
        let (context, note) = try library()
        let followUp = try #require(try ReviewWriter.followUp("later", on: note,
                                                              in: context, now: noon))
        #expect(followUp.createdAt == noon)
    }

    /// A note accumulates a conversation with itself over time; the second
    /// thought doesn't replace the first.
    @Test func thoughtsAccumulateRatherThanReplace() throws {
        let (context, note) = try library()
        _ = try ReviewWriter.followUp("first", on: note, in: context)
        _ = try ReviewWriter.followUp("second", on: note, in: context)
        #expect(note.followUps?.count == 2)
    }

    // MARK: Stars

    /// One tap, unambiguous meaning, no scheduling vocabulary.
    @Test func starringTogglesBothWays() throws {
        let (context, note) = try library()
        #expect(try ReviewWriter.star(note, in: context) == true)
        #expect(note.isStarred)
        #expect(try ReviewWriter.star(note, in: context) == false)
        #expect(!note.isStarred)
    }

    // MARK: Surfacing

    /// The count is what future sets are scored against, so it's written when a
    /// card is actually paged past — never when the set is built.
    @Test func pagingPastACardRecordsThatItWasSeen() throws {
        let (context, note) = try library()
        try ReviewWriter.surface(note, in: context, at: noon, calendar: calendar)
        #expect(note.lastSurfacedAt == noon)
        #expect(note.surfaceCount == 1)
    }

    /// Swiping back and forth through the day's set is one reading of each card,
    /// not six. An inflated count would quietly bury the note for months.
    @Test func swipingBackAndForthCountsOnce() throws {
        let (context, note) = try library()
        try ReviewWriter.surface(note, in: context, at: noon, calendar: calendar)
        try ReviewWriter.surface(note, in: context, at: noon.addingTimeInterval(90),
                                 calendar: calendar)
        #expect(note.surfaceCount == 1)
        #expect(note.lastSurfacedAt == noon)
    }

    @Test func thesameNoteSeenOnALaterDayCountsAgain() throws {
        let (context, note) = try library()
        let tomorrow = noon.addingTimeInterval(86_400)
        try ReviewWriter.surface(note, in: context, at: noon, calendar: calendar)
        try ReviewWriter.surface(note, in: context, at: tomorrow, calendar: calendar)
        #expect(note.surfaceCount == 2)
        #expect(note.lastSurfacedAt == tomorrow)
    }

    /// Surfacing is what the next day's set reads, so it has to survive the app
    /// being closed on the last card.
    @Test func surfacingIsPersisted() throws {
        let (context, note) = try library()
        try ReviewWriter.surface(note, in: context, at: noon, calendar: calendar)
        #expect(!context.hasChanges)
    }
}
