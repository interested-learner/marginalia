import Testing
import Foundation
import SwiftData
@testable import Marginalia

/// The schema, first-launch bootstrap, and seed content.
///
/// These run against a real in-memory container rather than a stub, because
/// half of what's worth checking here — that the four `@Model` types actually
/// form a valid schema — only fails when SwiftData tries to build it.
struct LibraryStoreTests {

    private func store() throws -> ModelContext {
        ModelContext(try ModelContainer.marginalia(inMemory: true))
    }

    private func defaults() -> UserDefaults {
        let name = "marginalia.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func seeded(now: Date = .now) throws -> (ModelContext, ShortIDCounter) {
        let context = try store()
        let counter = ShortIDCounter(defaults: defaults())
        try Library.prepare(context, now: now, counter: counter)
        return (context, counter)
    }

    private func notes(_ context: ModelContext) throws -> [Note] {
        try context.fetch(FetchDescriptor<Note>(sortBy: [SortDescriptor(\.shortID)]))
    }

    private func books(_ context: ModelContext) throws -> [Book] {
        try context.fetch(FetchDescriptor<Book>())
    }

    // MARK: Schema

    @Test func theFourModelsFormAValidSchema() throws {
        _ = try store()
    }

    // MARK: Bootstrap

    @Test func firstLaunchCreatesExactlyOneInbox() throws {
        let (context, _) = try seeded()
        #expect(try books(context).filter { $0.status == .inbox }.count == 1)
    }

    /// The bootstrap runs on every launch and must be a no-op after the first.
    @Test func preparingASecondTimeSeedsNothingFurther() throws {
        let (context, counter) = try seeded()
        let before = try notes(context).count
        try Library.prepare(context, now: .now, counter: counter)
        #expect(try notes(context).count == before)
        #expect(try books(context).filter { $0.status == .inbox }.count == 1)
    }

    /// A store that outlives its `UserDefaults` must not hand out ids that
    /// already exist in it.
    @Test func preparingRaisesTheCounterPastTheHighestSeededID() throws {
        let (context, counter) = try seeded()
        let highest = try #require(try notes(context).map(\.shortID).max())
        #expect(counter.next() > highest)
    }

    @Test func aFreshCounterOverAnAlreadySeededStoreStillSkipsUsedIDs() throws {
        let (context, _) = try seeded()
        let highest = try #require(try notes(context).map(\.shortID).max())

        let replacement = ShortIDCounter(defaults: defaults())   // as if reinstalled
        try Library.prepare(context, now: .now, counter: replacement)
        #expect(replacement.next() > highest)
    }

    // MARK: Seed shape

    /// A twelve-note map proves nothing in phase 7, and backfilling good seed
    /// content later is far more work than writing it now.
    @Test func theSeedIsAboutFortyNotes() throws {
        let (context, _) = try seeded()
        #expect(try notes(context).count >= 40)
    }

    @Test func everySeededNoteHasAnID() throws {
        let (context, _) = try seeded()
        let ids = try notes(context).map(\.shortID)
        #expect(ids.allSatisfy { $0 > 0 })
        #expect(Set(ids).count == ids.count)
    }

    /// Ids run in the order the notes were written, so `n.01` is the oldest
    /// note in the library and the stream counts down from the top.
    @Test func idsAscendWithCreationDate() throws {
        let (context, _) = try seeded()
        let dates = try notes(context).map(\.createdAt)
        #expect(dates == dates.sorted())
    }

    @Test func everySeededNoteBelongsToABook() throws {
        let (context, _) = try seeded()
        #expect(try notes(context).allSatisfy { $0.book != nil })
    }

    /// The stream's three date headers only exist if the seed spans them.
    @Test func theSeedSpansTodayYesterdayAndEarlier() throws {
        let now = Date.now
        let (context, _) = try seeded(now: now)
        let labels = StreamGrouping.groups(try notes(context), date: \.createdAt, now: now).map(\.label)
        #expect(labels.count == 3)
    }

    @Test func quickCapturesLandInTheInbox() throws {
        let (context, _) = try seeded()
        let inbox = try #require(try books(context).first { $0.status == .inbox })
        #expect((inbox.notes ?? []).isEmpty == false)
    }

    /// Phase 5's review set needs a currently-reading book to draw from, and
    /// the books screen needs every status marker to appear at least once.
    @Test func everyBookStatusIsRepresented() throws {
        let (context, _) = try seeded()
        let statuses = Set(try books(context).map(\.status))
        #expect(statuses == Set(BookStatus.allCases))
    }

    /// Phase 6 tunes the affinity weights against this content, so it needs
    /// real overlap to work with rather than forty unrelated sentences.
    @Test func theSeedCarriesTagsSharedAcrossBooks() throws {
        let (context, _) = try seeded()
        let byTag = Dictionary(grouping: try notes(context).flatMap { note in
            (note.tags).map { (tag: $0, book: note.book?.title ?? "") }
        }, by: \.tag)
        let crossBook = byTag.filter { Set($0.value.map(\.book)).count > 1 }
        #expect(crossBook.count >= 3)
    }

    @Test func tagsAreStoredBareSoTheHashIsNeverDoubled() throws {
        let (context, _) = try seeded()
        #expect(try notes(context).allSatisfy { $0.tags.allSatisfy { !$0.hasPrefix("#") } })
    }

    @Test func quotesCarryThePageTheyCameFrom() throws {
        let (context, _) = try seeded()
        let quotes = try notes(context).filter { $0.kind == .quote }
        #expect(quotes.isEmpty == false)
        #expect(quotes.allSatisfy { ($0.page ?? 0) > 0 })
    }

    // MARK: Seeded connections

    /// Phase 6 replaces these with what `AffinityEngine` finds. Until then they
    /// are pinned, which is exactly what keeps a recompute from pruning them.
    @Test func seededEdgesArePinnedAndJoinTwoRealNotes() throws {
        let (context, _) = try seeded()
        let edges = try context.fetch(FetchDescriptor<NoteEdge>())
        #expect(edges.isEmpty == false)
        #expect(edges.allSatisfy { $0.isPinned })
        #expect(edges.allSatisfy { $0.from != nil && $0.to != nil })
        #expect(edges.allSatisfy { $0.from?.shortID != $0.to?.shortID })
    }

    @Test func noSeededEdgeIsSuppressed() throws {
        let (context, _) = try seeded()
        #expect(try context.fetch(FetchDescriptor<NoteEdge>()).allSatisfy { !$0.isSuppressed })
    }

    // MARK: Seeded follow-ups

    /// A fresh install has to show what `[+] add a thought` produces, not just
    /// offer it — the thread under a note is otherwise unjudgeable until the
    /// reader has written one.
    @Test func someSeededNotesArriveAlreadyAnswered() throws {
        let (context, _) = try seeded()
        let followUps = try context.fetch(FetchDescriptor<FollowUp>())
        #expect(followUps.isEmpty == false)
        #expect(followUps.allSatisfy { $0.note != nil })
        #expect(followUps.allSatisfy { !$0.text.isEmpty })
    }

    /// Most notes have no thread. A library where every note had one would
    /// misread as the normal state of things.
    @Test func mostSeededNotesHaveNoThread() throws {
        let (context, _) = try seeded()
        let all = try notes(context)
        let answered = all.filter { !($0.followUps ?? []).isEmpty }
        #expect(answered.count < all.count / 4)
    }

    /// A thread reads forward, so an answer written before the note it answers
    /// would render above nothing.
    @Test func everyFollowUpIsYoungerThanTheNoteItAnswers() throws {
        let (context, _) = try seeded()
        let followUps = try context.fetch(FetchDescriptor<FollowUp>())
        #expect(followUps.allSatisfy { followUp in
            guard let parent = followUp.note else { return false }
            return followUp.createdAt > parent.createdAt
        })
    }

    // MARK: Typed accessors

    /// `statusRaw` and `kindRaw` are strings so the store stays readable and
    /// schema changes stay cheap; the typed accessor is what views use.
    @Test func statusRoundTripsThroughItsRawString() {
        let book = Book(title: "Meditations", author: "Marcus Aurelius", status: .finished)
        #expect(book.statusRaw == "finished")
        #expect(book.status == .finished)
    }

    @Test func anUnrecognizedStatusFallsBackRatherThanCrashing() {
        let book = Book()
        book.statusRaw = "abandoned"
        #expect(book.status == .queued)
    }

    @Test func kindRoundTripsThroughItsRawString() {
        let note = Note(kind: .voice, text: "spoken")
        #expect(note.kindRaw == "voice")
        #expect(note.kind == .voice)
    }

    @Test func anUnrecognizedKindFallsBackRatherThanCrashing() {
        let note = Note()
        note.kindRaw = "telepathy"
        #expect(note.kind == .thought)
    }
}
