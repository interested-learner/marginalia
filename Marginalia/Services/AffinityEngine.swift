import Foundation

/// Which notes connect to which, and how strongly.
///
/// **Pure.** Vectors and tags in, pairs out — no SwiftData, no store, no dates.
/// That's what makes the floor, the mutual k-NN rule and the degree cap
/// testable, and it's why `LinkWriter` does all the fetching and writing on the
/// other side of it.
nonisolated enum AffinityEngine {

    /// One note, reduced to the two things a score is made of.
    struct Subject: Sendable, Equatable {
        /// `Note.shortID`. The engine never sees a model.
        let id: Int
        /// Unit length, as `NoteEmbedding` returns it.
        let vector: [Float]
        let tags: [String]

        init(id: Int, vector: [Float], tags: [String] = []) {
            self.id = id
            self.vector = vector
            self.tags = tags
        }
    }

    /// An unordered pair. Edges store a direction and the UI shows both ends, so
    /// `n.07 → n.11` and `n.11 → n.07` are the same connection and have to hash
    /// as one, or a recompute would build the second alongside the first.
    struct Pair: Hashable, Sendable {
        let low: Int
        let high: Int

        init(_ a: Int, _ b: Int) {
            low = min(a, b)
            high = max(a, b)
        }

        func contains(_ id: Int) -> Bool { low == id || high == id }
        func other(_ id: Int) -> Int { id == low ? high : low }
    }

    struct Link: Sendable, Equatable {
        let pair: Pair
        let score: Double
    }

    // MARK: The constants

    /// `0.8 · cosine + 0.2 · tagOverlap`. Same-book is deliberately **not**
    /// boosted — books are already hub nodes on the map, and rewarding it again
    /// would clump each book into a ball.
    static let vectorWeight = 0.8
    static let tagWeight = 0.2

    /// An edge needs this much to exist at all.
    static let floor = 0.55
    /// Each note must be in the other's top `neighbors`. This is the constraint
    /// that matters: it's what stops one broadly-worded note from attaching
    /// itself to everything in the library.
    static let neighbors = 8
    /// At most this many edges on a note, strongest kept.
    static let degreeCap = 6

    // MARK: The engine

    /// The automatic edges the library should have.
    ///
    /// This is the **whole desired set**, not a delta: `LinkWriter` diffs it
    /// against what's stored, which is what lets a recompute remove a connection
    /// that no longer holds as well as add one that now does.
    ///
    /// `pinned` and `suppressed` are the two overrides, and neither appears in
    /// the result — a pinned edge already exists and is never pruned, a
    /// suppressed one was deleted by hand and is never suggested again. Pinned
    /// pairs **do** spend degree budget, because the cap is about how many lines
    /// meet at a node on the map, and a hand-made line is still a line.
    static func links(
        among subjects: [Subject],
        pinned: Set<Pair> = [],
        suppressed: Set<Pair> = [],
        floor: Double = floor,
        neighbors: Int = neighbors,
        degreeCap: Int = degreeCap
    ) -> [Link] {
        guard subjects.count > 1 else { return [] }

        // Every pair, scored once. O(N²), which is seconds at library sizes
        // this app will ever see and the reason `LinkWriter` runs it off the
        // main thread rather than inline.
        var scores: [Pair: Double] = [:]
        var ranked = [[(id: Int, score: Double)]](repeating: [], count: subjects.count)

        for i in subjects.indices {
            for j in (i + 1)..<subjects.count {
                let a = subjects[i]
                let b = subjects[j]
                guard a.id != b.id else { continue }
                let score = score(a, b)
                scores[Pair(a.id, b.id)] = score
                ranked[i].append((b.id, score))
                ranked[j].append((a.id, score))
            }
        }

        // Top-k is taken over **every** candidate, not only the ones above the
        // floor. Otherwise a note whose neighbours are all weak would promote
        // its ninth-best into the top eight and the two rules would stop being
        // independent.
        let shortlists: [Int: Set<Int>] = Dictionary(
            uniqueKeysWithValues: subjects.indices.map { index in
                let top = ranked[index]
                    .sorted { $0.score == $1.score ? $0.id < $1.id : $0.score > $1.score }
                    .prefix(neighbors)
                return (subjects[index].id, Set(top.map(\.id)))
            }
        )

        let mutual = scores
            .filter { pair, score in
                score >= floor
                    && !suppressed.contains(pair)
                    && !pinned.contains(pair)
                    && shortlists[pair.low]?.contains(pair.high) == true
                    && shortlists[pair.high]?.contains(pair.low) == true
            }
            .map { Link(pair: $0.key, score: $0.value) }
            .sorted { left, right in
                // Ties break on id so a recompute over unchanged notes returns
                // the same graph. A set that reshuffled every launch would look
                // like the app changing its mind.
                if left.score != right.score { return left.score > right.score }
                if left.pair.low != right.pair.low { return left.pair.low < right.pair.low }
                return left.pair.high < right.pair.high
            }

        // Strongest first, and a pair is dropped when either end is full.
        var degree: [Int: Int] = [:]
        for pair in pinned {
            degree[pair.low, default: 0] += 1
            degree[pair.high, default: 0] += 1
        }

        var kept: [Link] = []
        for link in mutual {
            guard degree[link.pair.low, default: 0] < degreeCap,
                  degree[link.pair.high, default: 0] < degreeCap else { continue }
            degree[link.pair.low, default: 0] += 1
            degree[link.pair.high, default: 0] += 1
            kept.append(link)
        }
        return kept
    }

    /// `0.8 · cosine + 0.2 · tagOverlap`, and nothing else goes in it.
    static func score(_ a: Subject, _ b: Subject) -> Double {
        vectorWeight * cosine(a.vector, b.vector) + tagWeight * tagOverlap(a.tags, b.tags)
    }

    /// Vectors arrive unit length, but the cosine is written out anyway — this
    /// is a pure function that a test can hand any two vectors, and one that
    /// quietly assumed normalization would be wrong for them and right for the
    /// app.
    static func cosine(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dot = Float(0)
        var left = Float(0)
        var right = Float(0)
        for index in a.indices {
            dot += a[index] * b[index]
            left += a[index] * a[index]
            right += b[index] * b[index]
        }

        let magnitude = (left * right).squareRoot()
        guard magnitude > 0 else { return 0 }
        return Double(dot / magnitude)
    }

    /// Jaccard — shared tags over all tags between them. Intersection alone
    /// would let a note tagged with everything score highly against everything,
    /// which is the same failure mutual k-NN exists to prevent.
    static func tagOverlap(_ a: [String], _ b: [String]) -> Double {
        let left = Set(a.map(TagIndex.normalized).filter { !$0.isEmpty })
        let right = Set(b.map(TagIndex.normalized).filter { !$0.isEmpty })
        guard !left.isEmpty, !right.isEmpty else { return 0 }
        return Double(left.intersection(right).count) / Double(left.union(right).count)
    }
}
