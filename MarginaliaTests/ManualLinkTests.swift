import Foundation
import SwiftData
import Testing
@testable import Marginalia

/// `LinkWriter.pin` — the one thing in the app that makes a connection because
/// the reader said so.
///
/// `isPinned` has been in the model since phase 6 and nothing wrote it; this is
/// what closes that. The engine's side of pinning — never pruned, never
/// re-suggested, still spends degree budget — is `AffinityEngineTests`; this is
/// the store's side.
@MainActor
struct ManualLinkTests {

    private func store() throws -> ModelContext {
        ModelContext(try ModelContainer.marginalia(inMemory: true))
    }

    @discardableResult
    private func note(_ shortID: Int, in context: ModelContext) -> Note {
        let note = Note(shortID: shortID, text: "note \(shortID)")
        context.insert(note)
        return note
    }

    private func edges(in context: ModelContext) throws -> [NoteEdge] {
        try context.fetch(FetchDescriptor<NoteEdge>())
    }

    // MARK: Making one

    @Test func pinningTwoNotesWritesAnEdge() throws {
        let context = try store()
        let a = note(1, in: context)
        let b = note(2, in: context)

        #expect(try LinkWriter.pin(a, to: b, in: context))

        let written = try edges(in: context)
        #expect(written.count == 1)
        #expect(written[0].isPinned)
        #expect(written[0].isSuppressed == false)
        #expect(written[0].score == 0)
    }

    /// Direction is stored and never displayed, so it's written low → high
    /// whichever end the reader started from — the same way a recompute writes
    /// one, so the two can't produce two edges for one pair.
    @Test func theEdgeIsWrittenLowToHighWhicheverEndYouStartedFrom() throws {
        let context = try store()
        let a = note(3, in: context)
        let b = note(1, in: context)

        try LinkWriter.pin(a, to: b, in: context)

        let written = try #require(try edges(in: context).first)
        #expect(written.from?.shortID == 1)
        #expect(written.to?.shortID == 3)
    }

    // MARK: Refusing one

    @Test func aNoteCannotBeLinkedToItself() throws {
        let context = try store()
        let a = note(1, in: context)

        #expect(try LinkWriter.pin(a, to: a, in: context) == false)
        #expect(try edges(in: context).isEmpty)
    }

    @Test func pinningTheSamePairTwiceDoesNotWriteASecondEdge() throws {
        let context = try store()
        let a = note(1, in: context)
        let b = note(2, in: context)

        try LinkWriter.pin(a, to: b, in: context)
        #expect(try LinkWriter.pin(a, to: b, in: context) == false)
        #expect(try edges(in: context).count == 1)
    }

    // MARK: Over what's already there

    /// A pair the app found on its own is adopted rather than duplicated — and
    /// it keeps its score, because the score is still true.
    @Test func pinningAPairTheAppFoundAdoptsThatEdge() throws {
        let context = try store()
        let a = note(1, in: context)
        let b = note(2, in: context)
        context.insert(NoteEdge(from: a, to: b, score: 0.61))

        #expect(try LinkWriter.pin(a, to: b, in: context))

        let written = try #require(try edges(in: context).first)
        #expect(try edges(in: context).count == 1)
        #expect(written.isPinned)
        #expect(written.score == 0.61)
    }

    /// **Suppression is a decision and so is this, and this one is newer.** The
    /// reader disconnected the pair once and has now asked for it back; the same
    /// resolution `Eraser.suppress` makes in the other direction.
    @Test func pinningAPairYouOnceDisconnectedBringsItBack() throws {
        let context = try store()
        let a = note(1, in: context)
        let b = note(2, in: context)
        let edge = NoteEdge(from: a, to: b, score: 0.6)
        context.insert(edge)
        try Eraser.suppress(edge, in: context)

        #expect(try LinkWriter.pin(a, to: b, in: context))
        #expect(edge.isSuppressed == false)
        #expect(edge.isPinned)
    }

    // MARK: What a recompute does with it

    /// The whole point of the flag: a hand-made link outlives the pass that
    /// would never have suggested it.
    @Test func aHandMadeLinkSurvivesARecompute() async throws {
        let context = try store()

        let a = Note(shortID: 1, text: "a note about attention and memory")
        let b = Note(shortID: 2, text: "a completely unrelated note about kitchen taps")
        for note in [a, b] { context.insert(note) }

        try LinkWriter.pin(a, to: b, in: context)
        try await LinkWriter.relink(in: context)

        let written = try edges(in: context)
        #expect(written.count == 1)
        #expect(written[0].isPinned)

        // **The embedder is allowed not to exist**, and this assertion is
        // conditional because of a real difference between two runtimes rather
        // than to make a red test green. On the iOS 18.5 simulator
        // `NLEmbedding.sentenceEmbedding(for: .english)` returns nil, so
        // `NoteEmbedding.init?` returns nil and nothing is embedded at all —
        // see `docs/issues.md` §21. `NoteEmbedding` documents that as a
        // supported outcome ("a library with no connections rather than a
        // crash"), so a test that *required* an embedder was asserting
        // something the app never promised.
        //
        // What the test is actually for is the pinned edge above, and that
        // holds either way: a hand-made link outlives a recompute that had no
        // vectors to score with, which is if anything the harder case.
        if let source = NoteEmbedding()?.source {
            #expect(a.embeddingSource == source)
        } else {
            #expect(a.embeddedAt == nil)
        }
    }
}
