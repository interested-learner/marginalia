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
    /// boosted — notes from the same book already share vocabulary and tags,
    /// and rewarding that again would crowd a book's own notes into each
    /// other's degree budget at the expense of the crossings that connect
    /// two different books, which is the whole point of the graph.
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
    /// pairs **do** spend degree budget, because the cap is about how many
    /// connections a note carries, and a hand-made one is still a connection.
    static func links(
        among subjects: [Subject],
        pinned: Set<Pair> = [],
        suppressed: Set<Pair> = [],
        floor: Double = floor,
        neighbors: Int = neighbors,
        degreeCap: Int = degreeCap
    ) -> [Link] {
        guard subjects.count > 1 else { return [] }

        // **Everything that depends on one note is computed once, here.**
        // Normalizing a tag and squaring a vector are both O(N) jobs that the
        // pair loop was doing O(N²) times — half a million times over at a
        // thousand notes, for a thousand notes' worth of answers. Hoisting them
        // takes the pass from 1.50 µs a pair to 0.71, measured, at `-O`, with
        // the resulting graph unchanged edge for edge. `AffinityBenchmarkTests`
        // is where those numbers come from and `docs/issues.md` §15 is what
        // they replaced.
        let ids = subjects.map(\.id)
        let vectors = subjects.map(\.vector)
        let labels = subjects.map { Set($0.tags.map(TagIndex.normalized).filter { !$0.isEmpty }) }
        // Sum of squares rather than the magnitude, so the arithmetic below is
        // the same expression `cosine` uses and returns the same bits.
        let squares = vectors.map { vector in vector.reduce(Float(0)) { $0 + $1 * $1 } }

        // Every pair, scored once. Still O(N²) — a full recompute is what makes
        // mutual k-NN and the degree cap correct, and `docs/decisions.md` §14
        // chose that deliberately — but the constant is now a dot product.
        var scores: [Pair: Double] = [:]
        var ranked = [[(id: Int, score: Double)]](repeating: [], count: subjects.count)

        for i in subjects.indices {
            let a = ids[i]
            let vector = vectors[i]
            let squared = squares[i]
            let tags = labels[i]

            for j in (i + 1)..<subjects.count {
                let b = ids[j]
                guard a != b else { continue }
                let score = vectorWeight * cosine(vector, vectors[j], squared, squares[j])
                    + tagWeight * jaccard(tags, labels[j])
                scores[Pair(a, b)] = score
                ranked[i].append((b, score))
                ranked[j].append((a, score))
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

        var left = Float(0)
        var right = Float(0)
        for index in a.indices {
            left += a[index] * a[index]
            right += b[index] * b[index]
        }
        return cosine(a, b, left, right)
    }

    /// The same cosine with both sums of squares already in hand — the shape a
    /// full pass wants, where every vector's own magnitude is a property of one
    /// note and not of the pair it's in.
    ///
    /// Same expression, same order of accumulation, so it returns the same bits
    /// as the two-argument form. That matters: a score sits either side of a
    /// floor, and a graph that changed shape because a magnitude was factored
    /// out differently would be a bug nobody could see.
    private static func cosine(
        _ a: [Float],
        _ b: [Float],
        _ aSquared: Float,
        _ bSquared: Float
    ) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dot = Float(0)
        for index in a.indices {
            dot += a[index] * b[index]
        }

        let magnitude = (aSquared * bSquared).squareRoot()
        guard magnitude > 0 else { return 0 }
        return Double(dot / magnitude)
    }

    /// Jaccard — shared tags over all tags between them. Intersection alone
    /// would let a note tagged with everything score highly against everything,
    /// which is the same failure mutual k-NN exists to prevent.
    static func tagOverlap(_ a: [String], _ b: [String]) -> Double {
        jaccard(Set(a.map(TagIndex.normalized).filter { !$0.isEmpty }),
                Set(b.map(TagIndex.normalized).filter { !$0.isEmpty }))
    }

    /// The same measure over tags already normalized. One definition, two ways
    /// in: a full pass normalizes each note's tags once and comes here, and
    /// anything holding two raw lists goes through `tagOverlap` above.
    private static func jaccard(_ left: Set<String>, _ right: Set<String>) -> Double {
        guard !left.isEmpty, !right.isEmpty else { return 0 }
        return Double(left.intersection(right).count) / Double(left.union(right).count)
    }
}
