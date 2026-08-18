import Foundation

/// Which notes belong together, and which belong to nothing yet.
///
/// **Pure.** Vectors, tags and book indices in; themes and loose ids out — no
/// SwiftData, no store, no dates. The same discipline `AffinityEngine` keeps,
/// and for the same reason: the grouping rule is the whole of this file's value
/// and a test has to be able to ask it directly.
///
/// **This is not `AffinityEngine` with different constants.** It deliberately
/// ignores the floor, the mutual k-NN at 8 and the degree cap of 6 — those three
/// exist to keep a force-directed *drawing* legible, and grouping is a different
/// job. See `docs/decisions.md` §20.
///
/// ## Ranked, never thresholded
///
/// The obvious build is agglomerative clustering cut at a similarity threshold,
/// and it would have been wrong. **An absolute threshold is a number tuned to a
/// model the app is designed to abandon.** On today's fallback embedder two
/// paraphrases about attention score `0.267` against each other and `0.274`
/// against an unrelated note about a kitchen tap — a cut at `0.45` yields zero
/// themes. The day `NLContextualEmbedding`'s assets compile the magnitudes move
/// wholesale and the same constant could yield one blob. Phase 6 refused
/// exactly this when it left the floor and the weights at the spec's values
/// rather than fitting them to the fallback.
///
/// So: rank. Each note ranks every other by `AffinityEngine.score`, pairs are
/// kept where each is in the other's top `neighbors`, and communities are found
/// by greedy modularity merging until no merge improves modularity. There is no
/// magic number in the grouping at all — modularity carries its own stopping
/// point, which also bounds the theme count, because a summary showing sixty
/// themes is not a summary.
///
/// ## What rank-invariance does and does not cover
///
/// **Membership and order depend on nothing but the rankings.** The graph is
/// built from mutual top-`neighbors` nominations, and the communities are found
/// by *unweighted* modularity — scores are deliberately kept out of the merge,
/// because modularity gain is not invariant under a non-uniform change in
/// weights and the move from one embedder to another is precisely that.
///
/// **The exemplar is the exception, and knowingly so.** It is the score medoid
/// of its theme, so a different embedder may nominate a different note at the
/// centre of the same group. That is a display choice rather than a grouping
/// one, and the alternative — the most-connected member — ties constantly in
/// small themes and answers a worse question.
///
/// **And rank-invariance fixes scale, not signal.** If the embedder cannot
/// measure meaning at note length then the rankings are noise too and the themes
/// are well-formed nonsense. `ThemeDumpTests` exists so that judgement can be
/// made by reading rather than by hoping.
nonisolated enum ThemeEngine {

    // MARK: What it's told

    /// One note, reduced to what a grouping needs of it.
    struct Subject: Sendable, Equatable {
        /// `Note.shortID`. The engine never sees a model.
        let id: Int
        /// Unit length, as `NoteEmbedding` returns it. **Empty means no usable
        /// vector** — either the note hasn't been embedded yet or it was
        /// embedded by a model that isn't the one loaded today, and a cosine
        /// across two models is a number with no meaning. Such a note is
        /// `loose` and says so, rather than being dropped where nobody sees it.
        let vector: [Float]
        let tags: [String]
        /// Index into `BookShelf.ordered`, or `nil` for a note whose book has
        /// gone. Carried only so a theme can say how many books it spans.
        let book: Int?

        init(id: Int, vector: [Float], tags: [String] = [], book: Int? = nil) {
            self.id = id
            self.vector = vector
            self.tags = tags
            self.book = book
        }
    }

    // MARK: What it says

    struct Theme: Identifiable, Sendable, Equatable {
        /// The exemplar's short id. Themes partition the library, so no two can
        /// share one — which makes it a stable identity for a navigation path
        /// and for `-mapTheme`.
        var id: Int { exemplar }

        /// The note at the centre of the group: the member with the greatest
        /// summed similarity to the rest of it. **It is the evidence**, and the
        /// overview quotes it so a reader can judge a grouping the app got
        /// wrong.
        let exemplar: Int
        /// Every note in the theme, `exemplar` included, ascending.
        let members: [Int]
        /// Distinct book indices the members were written from, ascending. An
        /// idea that appears in three books is the thing this app exists to
        /// notice.
        let books: [Int]
        /// How many mutual connections run *inside* the theme. Ranking only,
        /// never shown — a reader has no scale to read it against.
        ///
        /// A count and not a summed score, deliberately: see the note on
        /// rank-invariance at the top of this file. Everything that decides
        /// membership or order has to be topology, or the promise is only
        /// half-kept.
        let ties: Int

        var count: Int { members.count }
    }

    /// The whole reading of a library: what grouped, and what didn't.
    struct Reading: Sendable, Equatable {
        var themes: [Theme] = []
        /// Notes in no theme, ascending. Shown, not hidden — a summary that
        /// carried only the connections the app found would be dishonest.
        var loose: [Int] = []

        var isEmpty: Bool { themes.isEmpty && loose.isEmpty }
    }

    /// A neighbour and what it scored. A named type rather than a tuple —
    /// `compactMap` into a tuple, then `sorted`, then a key-path `map` is the
    /// shape that stalls Swift's type checker outright.
    private struct Ranked {
        let id: Int
        let score: Double
    }

    // MARK: The one constant, and it is a rank

    /// How many neighbours a note nominates. Six is a rank, not a similarity —
    /// nothing about it changes meaning when the embedder changes, which is the
    /// entire point of the design. `AffinityEngine.neighbors` is 8 and is
    /// deliberately not shared: that number is answering a question about how
    /// many lines may meet at a node on a drawing.
    static let neighbors = 6

    // MARK: The reading

    static func reading(_ subjects: [Subject]) -> Reading {
        // Sorted up front so every downstream tie-break is against a stable
        // order, whatever order the store handed the notes over in. The same
        // rule `AffinityEngine` sorts by, for the reason phase 6 gave: a map
        // that reshuffled on every launch would read as the app changing its
        // mind.
        let ordered = subjects.sorted { $0.id < $1.id }

        // A note with no comparable vector can't be ranked against anything, so
        // it is loose by construction rather than by scoring badly.
        let usable = ordered.filter { !$0.vector.isEmpty }
        var loose = ordered.filter { $0.vector.isEmpty }.map(\.id)

        guard usable.count > 1 else {
            return Reading(themes: [], loose: (loose + usable.map(\.id)).sorted())
        }

        let scores = pairScores(usable)
        let mutual = mutualPairs(usable, scores: scores)

        guard !mutual.isEmpty else {
            return Reading(themes: [], loose: (loose + usable.map(\.id)).sorted())
        }

        let communities = merge(mutual, among: usable.map(\.id))

        let books = Dictionary(usable.map { ($0.id, $0.book) }, uniquingKeysWith: { first, _ in first })
        var themes: [Theme] = []

        for members in communities {
            guard members.count > 1 else {
                loose.append(contentsOf: members)
                continue
            }
            themes.append(
                theme(members: members, scores: scores, books: books, mutual: mutual)
            )
        }

        // Biggest first, then most densely tied, then by lowest member so the
        // order is total. **Lowest member and not exemplar**: members are
        // rank-derived and the exemplar is score-derived, and the ordering must
        // not inherit the softer guarantee of the two.
        themes.sort { left, right in
            if left.count != right.count { return left.count > right.count }
            if left.ties != right.ties { return left.ties > right.ties }
            return (left.members.first ?? 0) < (right.members.first ?? 0)
        }

        return Reading(themes: themes, loose: loose.sorted())
    }

    // MARK: Every pair, scored once

    /// `AffinityEngine.score` over every pair, so there is **one** definition of
    /// similarity in this app rather than two that could drift apart.
    ///
    /// O(n²), which is what a relink already costs — 0.71 µs a pair at `-O`,
    /// measured in `AffinityBenchmarkTests`. Only the ranks are kept afterwards,
    /// so nothing here holds an O(n²) matrix beyond this call.
    private static func pairScores(_ subjects: [Subject]) -> [AffinityEngine.Pair: Double] {
        var scores: [AffinityEngine.Pair: Double] = [:]
        scores.reserveCapacity(subjects.count * neighbors * 2)

        let affinity = subjects.map {
            AffinityEngine.Subject(id: $0.id, vector: $0.vector, tags: $0.tags)
        }

        for i in affinity.indices {
            for j in (i + 1)..<affinity.count {
                let score = AffinityEngine.score(affinity[i], affinity[j])
                guard score > 0 else { continue }
                scores[AffinityEngine.Pair(affinity[i].id, affinity[j].id)] = score
            }
        }
        return scores
    }

    /// Each note's top `neighbors`, kept only where the nomination is returned.
    ///
    /// **No floor.** This is what catches the pair phase 6 called the worse half
    /// of its own output: `n.03` "good error messages assume the system is at
    /// fault" and `n.04` "human error is system error" score `0.448` and fail
    /// the floor, not the k-NN rule. A near-restatement of one idea belongs in
    /// one theme whatever the absolute number happened to be.
    private static func mutualPairs(
        _ subjects: [Subject],
        scores: [AffinityEngine.Pair: Double]
    ) -> Set<AffinityEngine.Pair> {
        let ids = subjects.map(\.id)

        var shortlist: [Int: Set<Int>] = [:]
        for id in ids {
            var ranked: [Ranked] = []
            for other in ids where other != id {
                guard let score = scores[AffinityEngine.Pair(id, other)] else { continue }
                ranked.append(Ranked(id: other, score: score))
            }
            // Strongest first, then by id, so a tie at the cut-off resolves the
            // same way every time.
            ranked.sort { $0.score != $1.score ? $0.score > $1.score : $0.id < $1.id }

            var top: Set<Int> = []
            for entry in ranked.prefix(neighbors) { top.insert(entry.id) }
            shortlist[id] = top
        }

        var mutual: Set<AffinityEngine.Pair> = []
        for pair in scores.keys {
            guard shortlist[pair.low]?.contains(pair.high) == true,
                  shortlist[pair.high]?.contains(pair.low) == true else { continue }
            mutual.insert(pair)
        }
        return mutual
    }

    // MARK: Communities, by modularity

    /// Greedy modularity merging — start every note alone, repeatedly merge the
    /// two communities whose union gains the most modularity, stop when no merge
    /// gains any.
    ///
    /// **The stopping point is the algorithm's, not a constant of ours.** That
    /// is the whole reason this was chosen over a threshold cut: there is no
    /// number here to tune against an embedder, and the theme count comes out
    /// bounded on its own.
    ///
    /// A community is keyed by its lowest note id, and merges tie-break on that
    /// key, so the same graph always partitions the same way.
    private static func merge(
        _ edges: Set<AffinityEngine.Pair>,
        among ids: [Int]
    ) -> [[Int]] {
        // **Unweighted, and that is the point.** Modularity gain is not
        // invariant under a non-uniform change in edge weights, and the change
        // from one embedder to another is exactly that — a cosine of 0.7 and one
        // of 0.9 do not move by the same ratio. Feeding scores in here would
        // have let the partition shift while every ranking stayed identical,
        // which is the guarantee this file is built to make. So an edge counts
        // one, and only the graph's shape decides.
        let total = Double(edges.count) * 2
        guard total > 0 else { return ids.map { [$0] } }

        var members: [Int: [Int]] = Dictionary(uniqueKeysWithValues: ids.map { ($0, [$0]) })
        var degree: [Int: Double] = Dictionary(uniqueKeysWithValues: ids.map { ($0, 0) })
        var between: [AffinityEngine.Pair: Double] = [:]

        for pair in edges {
            degree[pair.low, default: 0] += 1
            degree[pair.high, default: 0] += 1
            between[pair, default: 0] += 1
        }

        while true {
            var best: (pair: AffinityEngine.Pair, gain: Double)?

            for (pair, weight) in between {
                guard let left = degree[pair.low], let right = degree[pair.high] else { continue }
                // ΔQ = 2·( w_ij/2m − (d_i/2m)·(d_j/2m) )
                let gain = 2 * (weight / total - (left / total) * (right / total))
                guard gain > 0 else { continue }

                if let current = best {
                    guard gain > current.gain
                        || (gain == current.gain && pair.low < current.pair.low)
                        || (gain == current.gain && pair.low == current.pair.low
                            && pair.high < current.pair.high) else { continue }
                }
                best = (pair, gain)
            }

            guard let winner = best else { break }

            // The surviving key is the lower id, which keeps "a community is
            // named by its lowest member" true through every merge.
            let keep = winner.pair.low
            let drop = winner.pair.high

            members[keep, default: []].append(contentsOf: members[drop] ?? [])
            members[drop] = nil
            degree[keep, default: 0] += degree[drop] ?? 0
            degree[drop] = nil

            // Re-home every edge the absorbed community had. The edge between
            // the two of them becomes internal and simply goes.
            for (pair, weight) in between where pair.contains(drop) {
                between[pair] = nil
                let other = pair.other(drop)
                guard other != keep else { continue }
                between[AffinityEngine.Pair(keep, other), default: 0] += weight
            }
        }

        return members.values
            .map { $0.sorted() }
            .sorted { left, right in
                guard let a = left.first, let b = right.first else { return left.count > right.count }
                return a < b
            }
    }

    // MARK: One theme

    private static func theme(
        members: [Int],
        scores: [AffinityEngine.Pair: Double],
        books: [Int: Int?],
        mutual: Set<AffinityEngine.Pair>
    ) -> Theme {
        // The medoid: whichever member is most like the rest of them. Summed
        // similarity over *all* pairs inside the theme, not just the mutual
        // ones — the question is which note sits at the centre, and every pair
        // is evidence about that whether or not it survived the rank cut.
        var affinity: [Int: Double] = [:]
        for id in members {
            affinity[id] = members
                .filter { $0 != id }
                .reduce(0) { $0 + (scores[AffinityEngine.Pair(id, $1)] ?? 0) }
        }

        let exemplar = members.min { left, right in
            let a = affinity[left] ?? 0
            let b = affinity[right] ?? 0
            return a != b ? a > b : left < right
        } ?? members[0]

        let inside = Set(members)
        let ties = mutual.count { inside.contains($0.low) && inside.contains($0.high) }

        let spanned = Set(members.compactMap { books[$0] ?? nil }).sorted()

        return Theme(exemplar: exemplar, members: members, books: spanned, ties: ties)
    }
}
