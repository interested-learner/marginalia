import SwiftUI
import SwiftData

/// The one path a connection takes to exist.
///
/// The other side of `AffinityEngine`: everything here fetches, writes and
/// saves, and everything there is pure. `NoteWriter` has the same shape and for
/// the same reason — a second place that inserted a `NoteEdge` would drift from
/// this one within a phase.
///
/// Nothing in the app asks for a link. This runs because a note appeared, and
/// the reader never sees it happen.
@MainActor
enum LinkWriter {

    /// Embed whatever needs it, rescore the library, and make the stored edges
    /// match what the engine now says they should be.
    ///
    /// **A full recompute, not a delta.** The spec's incremental path — embed
    /// the new note, compare it against every stored vector — computes the new
    /// note's edges correctly but can't notice that it displaced somebody else's
    /// eighth-best neighbour or filled a sixth slot. At the sizes this app
    /// actually holds the whole pass is cheap enough that being right is free;
    /// above a few thousand notes it wants the incremental path and a proper
    /// background context, which is a phase 8 job and written down in
    /// `docs/planning.md` rather than pretended away here.
    ///
    /// The scoring and the `NL` inference both happen off the main actor. Only
    /// plain values cross in either direction — a `ModelContext` isn't
    /// `Sendable`, and neither are the models it hands out.
    static func relink(in context: ModelContext) async throws {
        // Queued behind whatever is already running rather than skipped. Two
        // overlapping passes would each diff against the same stored edges and
        // both insert the ones neither had written yet — but *dropping* the
        // second pass is worse than it sounds: the note that triggered it would
        // stay unembedded until something else in the library changed.
        //
        // The task is unstructured on purpose. `.task(id:)` cancels the caller
        // the moment the queue count changes, and a relink that stopped halfway
        // through would leave the library half-connected.
        let queued = pass
        let task = Task { @MainActor in
            _ = await queued?.result
            try await run(in: context)
        }
        pass = task
        try await task.value
    }

    /// The one in flight, if any. See `relink`.
    private static var pass: Task<Void, Error>?

    private static func run(in context: ModelContext) async throws {
        var notes: [Int: Note] = [:]
        for note in try context.fetch(FetchDescriptor<Note>()) where notes[note.shortID] == nil {
            notes[note.shortID] = note
        }
        guard notes.count > 1 else { return }

        let queue = notes.values.map {
            Candidate(id: $0.shortID, text: $0.text, source: $0.embeddingSource, hasVector: $0.embedding != nil)
        }
        guard let embedded = await Task.detached(priority: .utility) { embed(queue) }.value else { return }

        let now = Date.now
        for (id, vector) in embedded.vectors {
            guard let note = notes[id] else { continue }
            note.embedding = NoteEmbedding.pack(vector)
            note.embeddedAt = now
            note.embeddingSource = embedded.source
        }

        let subjects = notes.keys.sorted().compactMap { id -> AffinityEngine.Subject? in
            guard let note = notes[id], let vector = note.vector(from: embedded.source) else { return nil }
            return AffinityEngine.Subject(id: id, vector: vector, tags: note.tags)
        }

        let existing = try sort(try context.fetch(FetchDescriptor<NoteEdge>()), in: context)
        // Lifted out before the closure so nothing model-shaped can be captured
        // by it — a `NoteEdge` that crossed to another thread would be a far
        // quieter bug than the one it looks like.
        let pinned = existing.pinned
        let suppressed = existing.suppressed
        let links = await Task.detached(priority: .utility) {
            AffinityEngine.links(among: subjects, pinned: pinned, suppressed: suppressed)
        }.value

        apply(links, over: existing.automatic, notes: notes, in: context)
        try context.save()
    }

    // MARK: Embedding

    /// What the background task needs to decide whether a note wants embedding.
    /// A value type, because the `Note` it came from can't leave the main actor.
    private struct Candidate: Sendable {
        let id: Int
        let text: String
        let source: EmbeddingSource?
        let hasVector: Bool
    }

    private struct Embedded: Sendable {
        let source: EmbeddingSource
        let vectors: [Int: [Float]]
    }

    /// `nonisolated` and off the main actor — this is where the `NL` model gets
    /// built and run, and it's the expensive half of a first launch.
    ///
    /// The queue is `embeddedAt == nil` **or a stored source that isn't the one
    /// loaded today**: two vectors from different models can't be compared, so
    /// a library embedded by the fallback is re-embedded in full the first time
    /// the contextual assets are there.
    private nonisolated static func embed(_ candidates: [Candidate]) -> Embedded? {
        guard let embedder = NoteEmbedding() else {
            // No vectorizer at all. Ask for the assets and leave the library
            // unconnected rather than half-connected by something else.
            Task.detached(priority: .background) { await NoteEmbedding.requestAssetsIfNeeded() }
            return nil
        }

        if embedder.source == .sentence {
            // Fire and forget: the download is Apple's, it finishes when it
            // finishes, and the next relink after it does re-embeds everything.
            Task.detached(priority: .background) { await NoteEmbedding.requestAssetsIfNeeded() }
        }

        var vectors: [Int: [Float]] = [:]
        for candidate in candidates where !candidate.hasVector || candidate.source != embedder.source {
            if let vector = embedder.vector(for: candidate.text) { vectors[candidate.id] = vector }
        }
        return Embedded(source: embedder.source, vectors: vectors)
    }

    // MARK: The edges

    private struct Existing {
        var pinned: Set<AffinityEngine.Pair> = []
        var suppressed: Set<AffinityEngine.Pair> = []
        var automatic: [AffinityEngine.Pair: NoteEdge] = [:]
    }

    /// Sorts the stored edges into the three kinds, deleting the ones that
    /// aren't a connection at all: an end that went missing, a note joined to
    /// itself, and a second copy of a pair already accounted for.
    private static func sort(_ edges: [NoteEdge], in context: ModelContext) throws -> Existing {
        var sorted = Existing()

        for edge in edges {
            guard let from = edge.from?.shortID, let to = edge.to?.shortID, from != to else {
                context.delete(edge)
                continue
            }
            let pair = AffinityEngine.Pair(from, to)

            if edge.isSuppressed {
                sorted.suppressed.insert(pair)
            } else if edge.isPinned {
                sorted.pinned.insert(pair)
            } else if sorted.automatic[pair] == nil {
                sorted.automatic[pair] = edge
            } else {
                context.delete(edge)
            }
        }

        // A pair that is both pinned and suppressed is a contradiction that
        // resolves in the reader's favour: suppression is the more recent
        // deliberate act, and it wins.
        sorted.pinned.subtract(sorted.suppressed)
        return sorted
    }

    /// Makes the store match the engine. Kept edges keep their identity and take
    /// a new score, so an edge doesn't churn through delete-and-reinsert every
    /// time a note is saved.
    private static func apply(
        _ links: [AffinityEngine.Link],
        over automatic: [AffinityEngine.Pair: NoteEdge],
        notes: [Int: Note],
        in context: ModelContext
    ) {
        var stale = automatic

        for link in links {
            if let edge = stale.removeValue(forKey: link.pair) {
                if edge.score != link.score { edge.score = link.score }
                continue
            }
            guard let from = notes[link.pair.low], let to = notes[link.pair.high] else { continue }
            // Direction is stored but never displayed, so it's fixed low → high:
            // one connection, written the same way every recompute.
            context.insert(NoteEdge(from: from, to: to, score: link.score))
        }

        // Whatever the engine no longer says holds. Pinned and suppressed edges
        // never reached this map, so neither is ever pruned here.
        for edge in stale.values { context.delete(edge) }
    }
}

// MARK: The trigger

extension View {

    /// Keeps the library's connections current, from one place.
    ///
    /// The queue is notes without an embedding, exactly as `docs/planning.md`
    /// describes it, so this covers the first launch backfill and every capture
    /// after it with the same rule — and one more relink when the total changes,
    /// because a delete frees degree budget that somebody else can now use.
    func linking() -> some View { modifier(Linking()) }
}

private struct Linking: ViewModifier {
    @Environment(\.modelContext) private var context
    @Query private var notes: [Note]

    func body(content: Content) -> some View {
        content.task(id: queue) {
            try? await LinkWriter.relink(in: context)
        }
    }

    /// Both counts, because either changing is a reason to recompute. The
    /// pending count going `40 → 0` on a first launch fires this a second time
    /// with nothing left to embed; that pass is a scoring run and a diff that
    /// finds nothing, and it's cheaper than a rule clever enough to skip it.
    private var queue: Queue {
        Queue(total: notes.count, pending: notes.filter { $0.embeddedAt == nil }.count)
    }

    private struct Queue: Equatable {
        let total: Int
        let pending: Int
    }
}
