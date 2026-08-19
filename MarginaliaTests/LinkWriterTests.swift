import Foundation
import SwiftData
import Testing
@testable import Marginalia

/// The writing half of linking, against a real in-memory store.
///
/// `AffinityEngineTests` proves what the graph should be. This proves the store
/// ends up holding it: that a recompute adds, removes and rescores rather than
/// piling up a second copy of every edge, and that the two overrides survive it.
///
/// **Most of these plant their own vectors** rather than letting the OS produce
/// them. Two reasons: what the model thinks of a sentence is not this file's
/// subject, and the model isn't the same on every machine — it's whichever of
/// the two `NoteEmbedding` could load. The vectors below are two-dimensional and
/// chosen by hand, so the graph they should produce is arithmetic. The two tests
/// at the end embed for real, because the path from text to edge has to be
/// exercised somewhere.
@MainActor
struct LinkWriterTests {

    private func store() throws -> ModelContext {
        ModelContext(try ModelContainer.marginalia(inMemory: true))
    }

    /// Whichever model this machine has. A planted vector has to be stamped with
    /// it or `relink` would rightly throw the vector away and embed the text.
    private var source: EmbeddingSource? { NoteEmbedding()?.source }

    @discardableResult
    private func note(
        _ shortID: Int,
        angle: Double,
        tags: [String] = [],
        source: EmbeddingSource,
        in context: ModelContext
    ) -> Note {
        let note = Note(shortID: shortID, kind: .thought, text: "note \(shortID)", tags: tags)
        place(note, at: angle, source: source)
        context.insert(note)
        return note
    }

    /// A unit vector at `angle`, so the cosine between two notes is the cosine
    /// of the angle between them and nothing else.
    private func place(_ note: Note, at angle: Double, source: EmbeddingSource) {
        note.embedding = NoteEmbedding.pack([Float(cos(angle)), Float(sin(angle))])
        note.embeddedAt = .now
        note.embeddingSource = source
    }

    /// Three notes pointing the same way and two pointing somewhere else. Every
    /// pair inside a cluster scores 0.8; every pair across them scores ~0.06.
    private func library(_ source: EmbeddingSource) throws -> ModelContext {
        let context = try store()
        note(1, angle: 0, source: source, in: context)
        note(2, angle: 0.05, source: source, in: context)
        note(3, angle: 0.1, source: source, in: context)
        note(4, angle: 1.5, source: source, in: context)
        note(5, angle: 1.55, source: source, in: context)
        try context.save()
        return context
    }

    private func edges(_ context: ModelContext) throws -> [NoteEdge] {
        try context.fetch(FetchDescriptor<NoteEdge>())
    }

    private func pairs(_ context: ModelContext) throws -> Set<AffinityEngine.Pair> {
        Set(try edges(context).compactMap { edge in
            guard let from = edge.from?.shortID, let to = edge.to?.shortID else { return nil }
            return AffinityEngine.Pair(from, to)
        })
    }

    private func notes(_ context: ModelContext) throws -> [Note] {
        try context.fetch(FetchDescriptor<Note>(sortBy: [SortDescriptor(\.shortID)]))
    }

    // MARK: The graph

    @Test func notesThatScoreAboveTheFloorConnectAndTheOthersDoNot() async throws {
        guard let source else { return }
        let context = try library(source)

        try await LinkWriter.relink(in: context)

        let found = try pairs(context)
        #expect(found == [
            AffinityEngine.Pair(1, 2), AffinityEngine.Pair(1, 3), AffinityEngine.Pair(2, 3),
            AffinityEngine.Pair(4, 5)
        ])
    }

    /// Every edge is written one way round, so the same connection can never be
    /// stored twice under its two directions.
    @Test func recomputingTwiceDoesNotDoubleTheEdges() async throws {
        guard let source else { return }
        let context = try library(source)
        try await LinkWriter.relink(in: context)
        let first = try edges(context).count

        try await LinkWriter.relink(in: context)

        #expect(first == 4)
        #expect(try edges(context).count == first)
    }

    @Test func anEdgeKeptAcrossARecomputeIsTheSameEdge() async throws {
        guard let source else { return }
        let context = try library(source)
        try await LinkWriter.relink(in: context)
        let identities = Set(try edges(context).map(\.persistentModelID))

        try await LinkWriter.relink(in: context)

        #expect(Set(try edges(context).map(\.persistentModelID)) == identities)
    }

    /// The reason this is a full recompute rather than a delta: a connection
    /// that stops holding has to go, not only a new one appear.
    @Test func anEdgeThatNoLongerHoldsIsRemoved() async throws {
        guard let source else { return }
        let context = try library(source)
        try await LinkWriter.relink(in: context)
        #expect(try pairs(context).contains(AffinityEngine.Pair(1, 2)))

        // n.02 now points where n.04 and n.05 point.
        place(try notes(context)[1], at: 1.52, source: source)
        try context.save()

        try await LinkWriter.relink(in: context)

        let found = try pairs(context)
        #expect(!found.contains(AffinityEngine.Pair(1, 2)))
        #expect(found.contains(AffinityEngine.Pair(2, 4)))
    }

    /// Tags are a fifth of the score, and they're read off the note rather than
    /// out of the vector — so a pair the vectors can't carry can still connect.
    @Test func tagsReachTheStoreAsWellAsVectors() async throws {
        guard let source else { return }
        let context = try store()
        // 60° apart: 0.4 on vectors alone, which is under the floor.
        note(1, angle: 0, tags: ["memory", "attention"], source: source, in: context)
        note(2, angle: .pi / 3, tags: ["memory", "attention"], source: source, in: context)
        try context.save()

        try await LinkWriter.relink(in: context)

        #expect(try pairs(context) == [AffinityEngine.Pair(1, 2)])
    }

    @Test func aLibraryOfOneGetsNoEdges() async throws {
        guard let source else { return }
        let context = try store()
        note(1, angle: 0, source: source, in: context)
        try context.save()

        try await LinkWriter.relink(in: context)

        #expect(try edges(context).isEmpty)
    }

    // MARK: The overrides

    /// The seeded connections are pinned for exactly this reason: the first
    /// recompute on a fresh install must not prune the hand-picked ones.
    @Test func aPinnedEdgeSurvivesARecompute() async throws {
        guard let source else { return }
        let context = try library(source)
        let all = try notes(context)
        context.insert(NoteEdge(from: all[0], to: all[4], isPinned: true))   // n.01–n.05, nowhere near
        try context.save()

        try await LinkWriter.relink(in: context)

        #expect(try pairs(context).contains(AffinityEngine.Pair(1, 5)))
        #expect(try edges(context).filter(\.isPinned).count == 1)
    }

    @Test func aSuppressedEdgeIsNeverRebuilt() async throws {
        guard let source else { return }
        let context = try library(source)
        let all = try notes(context)
        context.insert(NoteEdge(from: all[0], to: all[1], isSuppressed: true))
        try context.save()

        try await LinkWriter.relink(in: context)

        let between = try edges(context).filter { edge in
            [edge.from?.shortID, edge.to?.shortID].compactMap { $0 }.sorted() == [1, 2]
        }
        #expect(between.count == 1)
        #expect(between.first?.isSuppressed == true)
    }

    // MARK: Sweeping

    @Test func anEdgeWithAMissingEndIsSweptUp() async throws {
        guard let source else { return }
        let context = try library(source)
        context.insert(NoteEdge(from: nil, to: nil))
        try context.save()

        try await LinkWriter.relink(in: context)

        #expect(try edges(context).allSatisfy { $0.from != nil && $0.to != nil })
    }

    @Test func aNoteJoinedToItselfIsSweptUp() async throws {
        guard let source else { return }
        let context = try library(source)
        let all = try notes(context)
        context.insert(NoteEdge(from: all[0], to: all[0]))
        try context.save()

        try await LinkWriter.relink(in: context)

        #expect(try edges(context).allSatisfy { $0.from?.shortID != $0.to?.shortID })
    }

    /// Both directions of one pair are one connection, and a recompute keeps
    /// exactly one of them.
    @Test func aDuplicateEdgeIsSweptUp() async throws {
        guard let source else { return }
        let context = try library(source)
        let all = try notes(context)
        context.insert(NoteEdge(from: all[0], to: all[1]))
        context.insert(NoteEdge(from: all[1], to: all[0]))
        try context.save()

        try await LinkWriter.relink(in: context)

        let between = try edges(context).filter { edge in
            [edge.from?.shortID, edge.to?.shortID].compactMap { $0 }.sorted() == [1, 2]
        }
        #expect(between.count == 1)
    }

    // MARK: Embedding, for real

    @Test func everyNoteComesBackEmbedded() async throws {
        guard source != nil else { return }
        let context = try store()
        for (offset, text) in [
            "Attention is the scarce resource, and everything else is downstream of where it goes.",
            "Where attention goes is what the day was actually spent on, whatever the calendar says.",
            "Sourdough wants a wetter dough than the book says, and a hotter oven than feels safe."
        ].enumerated() {
            context.insert(Note(shortID: offset + 1, kind: .thought, text: text))
        }
        try context.save()

        try await LinkWriter.relink(in: context)

        let all = try notes(context)
        #expect(all.allSatisfy { $0.embeddedAt != nil })
        #expect(all.allSatisfy { $0.embedding != nil })
        #expect(all.allSatisfy { $0.embeddingSource != nil })
        #expect(all.allSatisfy { ($0.embedding?.count ?? 0) > 8 })
    }

    /// The queue is `embeddedAt == nil`, so a second pass over an unchanged
    /// library must not re-embed anything.
    @Test func alreadyEmbeddedNotesAreLeftAlone() async throws {
        guard let source else { return }
        let context = try library(source)
        try await LinkWriter.relink(in: context)
        let stamps = try notes(context).map(\.embeddedAt)

        try await LinkWriter.relink(in: context)

        #expect(try notes(context).map(\.embeddedAt) == stamps)
    }

    /// The second way into the queue. A vector from a model the app is no longer
    /// using can't be compared with one from the model it is using, so the note
    /// is embedded again rather than scored against a different space.
    @Test func aNoteFromTheOtherModelIsEmbeddedAgain() async throws {
        guard let source else { return }
        let context = try library(source)
        let stale = try notes(context)[0]
        stale.embeddingSource = source == .contextual ? .sentence : .contextual

        try await LinkWriter.relink(in: context)

        #expect(stale.embeddingSource == source)
        // Two dimensions went in; a real vector came back.
        #expect(NoteEmbedding.unpack(try #require(stale.embedding)).count > 2)
    }

    /// The whole first-launch path in one test: prepare the store, run what the
    /// app runs on appear, and check the library came out connected with its
    /// hand-picked edges intact. This one **does** depend on the model having an
    /// opinion — if it ever fails, read `AffinityDumpTests` before touching it.
    @Test func aFreshLibraryComesOutConnected() async throws {
        guard source != nil else { return }
        let context = try store()
        let defaults = UserDefaults(suiteName: "marginalia.tests.\(UUID().uuidString)")!
        try Library.prepare(context, counter: ShortIDCounter(defaults: defaults), bootstrap: .sample(notes: nil))

        try await LinkWriter.relink(in: context)

        let all = try edges(context)
        #expect(all.filter(\.isPinned).count == SeedLibrary.edges.count)
        #expect(all.contains { !$0.isPinned })
        #expect(all.allSatisfy { $0.from != nil && $0.to != nil })

        // Nothing over the degree cap, counting the pinned edges too.
        var degree: [Int: Int] = [:]
        for edge in all {
            degree[edge.from?.shortID ?? 0, default: 0] += 1
            degree[edge.to?.shortID ?? 0, default: 0] += 1
        }
        #expect(degree.values.allSatisfy { $0 <= AffinityEngine.degreeCap })
    }
}
