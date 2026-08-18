import Foundation

/// The day's crossing: two notes from two different books that the app connected
/// by meaning, months apart.
///
/// **Pure**, in the sense the rest of this app means it — plain models and a
/// date in, one crossing out, no `ModelContext` and no clock of its own. The
/// same shape as `ReviewSetBuilder`, and for the same reason.
///
/// This is what the map tab computed that was worth keeping. It lived in
/// `MapView.crossingRows` as a computed property on a screen nobody opened;
/// `docs/decisions.md` §21 is why it moved here and the drawing didn't.
nonisolated enum CrossingFinder {

    /// One connection that spans two books. Carries the edge because
    /// `[x] not related` suppresses it, and re-finding it by note ids
    /// afterwards would be a second way to identify the same thing.
    struct Crossing {
        let edge: NoteEdge
        let a: Note
        let b: Note

        var score: Double { edge.score }
    }

    /// Every crossing in the library, strongest first, each note appearing once.
    static func all(from edges: [NoteEdge]) -> [Crossing] {
        var found: [Crossing] = []

        for edge in edges {
            guard !edge.isSuppressed, let from = edge.from, let to = edge.to else { continue }
            guard let left = from.book, let right = to.book else { continue }
            // The Inbox is found by status and is not a source. `BookWriter`
            // refuses to restatus it and `Eraser` refuses to delete it; this is
            // the third place it is special, and for the same reason.
            guard left.status != .inbox, right.status != .inbox else { continue }
            guard left.persistentModelID != right.persistentModelID else { continue }
            found.append(Crossing(edge: edge, a: from, b: to))
        }

        found.sort(by: strongestFirst)

        // **One appearance per note, and this is a display rule rather than a
        // claim about the data.** The hub behaviour phase 6 measured — `n.02`
        // and `n.13` turn up in half the shortlists, and mutual k-NN does not
        // stop it at forty notes — put `n.18` in three consecutive rows the
        // first time this ran. Every one of those connections still exists,
        // under the note itself; this list just takes the strongest each note
        // has, so three crossings are three ideas.
        var used: Set<Int> = []
        var kept: [Crossing] = []
        for crossing in found {
            guard !used.contains(crossing.a.shortID), !used.contains(crossing.b.shortID)
            else { continue }
            used.insert(crossing.a.shortID)
            used.insert(crossing.b.shortID)
            kept.append(crossing)
        }
        return kept
    }

    /// The one crossing today's review carries, or `nil` on a library that has
    /// none — in which case review is exactly what it was before this existed.
    ///
    /// **Day-stable, and it rotates.** `daySeed` advances by one a day, so the
    /// reader walks the ranked list an entry at a time and it cycles rather than
    /// repeating one pair forever. The alternatives were a `lastShownAt` on
    /// `NoteEdge` — a schema change, bought for a rotation — or always showing
    /// the strongest, which shows one pair every day until it is suppressed.
    ///
    /// `avoiding` is the ids already in the day's set. A crossing that overlaps
    /// them is skipped where another is available, and shown anyway where none
    /// is: seeing `n.03` as card 2 and again as half of card 9 is a small
    /// oddity, and suppressing the whole feature on a small library is a bigger
    /// one.
    static func pick(
        from edges: [NoteEdge],
        on day: Date,
        calendar: Calendar = .current,
        avoiding: Set<Int> = []
    ) -> Crossing? {
        let ranked = all(from: edges)
        guard !ranked.isEmpty else { return nil }

        let clear = ranked.filter {
            !avoiding.contains($0.a.shortID) && !avoiding.contains($0.b.shortID)
        }
        let pool = clear.isEmpty ? ranked : clear

        let seed = ReviewSetBuilder.daySeed(day, calendar)
        return pool[Int(seed % UInt64(pool.count))]
    }

    /// Ties break on the pair, low id first — the same rule `AffinityEngine`,
    /// `MapGraph` and `ReviewSetBuilder` all use, so a recompute over unchanged
    /// notes returns the same order.
    private static func strongestFirst(_ x: Crossing, _ y: Crossing) -> Bool {
        guard x.score == y.score else { return x.score > y.score }
        return pairKey(x) < pairKey(y)
    }

    private static func pairKey(_ crossing: Crossing) -> (Int, Int) {
        (min(crossing.a.shortID, crossing.b.shortID), max(crossing.a.shortID, crossing.b.shortID))
    }
}
