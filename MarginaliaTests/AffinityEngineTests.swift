import Foundation
import Testing
@testable import Marginalia

/// The three constraints, and the two overrides.
///
/// These prove the engine respects its own rules. **They cannot tell anyone
/// whether the connections are any good** — that needs a person reading real
/// output, which is what `AffinityDumpTests` is for.
struct AffinityEngineTests {

    /// Vectors are built by hand here rather than embedded, so a score is a
    /// number this file chose. Angle in the first two dimensions, unit length.
    private func subject(_ id: Int, angle: Double, tags: [String] = []) -> AffinityEngine.Subject {
        AffinityEngine.Subject(
            id: id,
            vector: [Float(cos(angle)), Float(sin(angle))],
            tags: tags
        )
    }

    /// `n` vectors fanned out over a right angle, so every pair has a different
    /// cosine and neighbourliness means something.
    private func fan(_ count: Int, spread: Double = .pi / 2) -> [AffinityEngine.Subject] {
        (1...count).map { subject($0, angle: spread * Double($0 - 1) / Double(count)) }
    }

    private func pairs(_ links: [AffinityEngine.Link]) -> Set<AffinityEngine.Pair> {
        Set(links.map(\.pair))
    }

    // MARK: The score

    @Test func scoreIsEightyPercentCosineAndTwentyPercentTags() {
        let a = AffinityEngine.Subject(id: 1, vector: [1, 0], tags: ["memory"])
        let b = AffinityEngine.Subject(id: 2, vector: [1, 0], tags: ["memory"])

        #expect(abs(AffinityEngine.score(a, b) - 1.0) < 0.0001)
    }

    @Test func identicalVectorsWithNoSharedTagsCannotReachOne() {
        let a = AffinityEngine.Subject(id: 1, vector: [1, 0], tags: ["memory"])
        let b = AffinityEngine.Subject(id: 2, vector: [1, 0], tags: ["systems"])

        #expect(abs(AffinityEngine.score(a, b) - 0.8) < 0.0001)
    }

    @Test func tagOverlapIsSharedOverAll() {
        #expect(AffinityEngine.tagOverlap(["a", "b"], ["a", "b"]) == 1)
        #expect(AffinityEngine.tagOverlap(["a", "b"], ["b", "c"]) == 1.0 / 3.0)
        #expect(AffinityEngine.tagOverlap(["a"], ["b"]) == 0)
    }

    /// A tag typed with its hash is the same tag. `TagIndex` is the one place
    /// that decides so, and the engine goes through it.
    @Test func tagOverlapNormalizes() {
        #expect(AffinityEngine.tagOverlap(["#Memory"], ["memory"]) == 1)
    }

    @Test func tagOverlapIsZeroWhenEitherSideHasNone() {
        #expect(AffinityEngine.tagOverlap([], ["memory"]) == 0)
        #expect(AffinityEngine.tagOverlap(["  ", "#"], ["memory"]) == 0)
    }

    @Test func cosineIgnoresMagnitude() {
        #expect(abs(AffinityEngine.cosine([2, 0], [7, 0]) - 1) < 0.0001)
        #expect(abs(AffinityEngine.cosine([1, 0], [0, 1])) < 0.0001)
    }

    @Test func cosineOfMismatchedOrEmptyVectorsIsZero() {
        #expect(AffinityEngine.cosine([1, 0], [1, 0, 0]) == 0)
        #expect(AffinityEngine.cosine([], []) == 0)
        #expect(AffinityEngine.cosine([0, 0], [1, 0]) == 0)
    }

    // MARK: The floor

    @Test func aPairBelowTheFloorIsNotAnEdge() {
        // 60° apart: cosine 0.5, and 0.8 · 0.5 = 0.4 with no tags to help it.
        let links = AffinityEngine.links(among: [
            subject(1, angle: 0),
            subject(2, angle: .pi / 3)
        ])

        #expect(links.isEmpty)
    }

    @Test func tagsCanCarryAPairOverTheFloor() {
        let angle = Double.pi / 3   // 0.4 on vectors alone
        let links = AffinityEngine.links(among: [
            subject(1, angle: 0, tags: ["memory", "attention"]),
            subject(2, angle: angle, tags: ["memory", "attention"])
        ])

        #expect(links.count == 1)          // 0.4 + 0.2 = 0.6
        #expect(links[0].score > AffinityEngine.floor)
    }

    // MARK: Mutual k-NN

    /// The constraint that matters. A note similar to everything is in nobody's
    /// top `k` once there are more than `k` better candidates for each of them.
    @Test func aNoteInTheOthersTopKButNotViceVersaGetsNoEdge() {
        // Twelve tight neighbours, and one broad note sitting near all of them
        // but closer to none than they are to each other.
        var subjects = (1...12).map { subject($0, angle: 0.01 * Double($0)) }
        subjects.append(subject(99, angle: 0.4))

        let links = AffinityEngine.links(among: subjects, neighbors: 3, degreeCap: 12)

        #expect(!links.contains { $0.pair.contains(99) })
        #expect(!links.isEmpty)
    }

    @Test func mutualityIsSymmetric() {
        let links = AffinityEngine.links(among: fan(6), neighbors: 2, degreeCap: 6)

        // Every kept pair holds both ways or it wouldn't be here; the check is
        // that no pair was written twice under the two directions.
        #expect(links.count == pairs(links).count)
    }

    // MARK: The degree cap

    @Test func aNoteKeepsAtMostTheCapsWorthOfEdges() {
        // Ten nearly identical notes: every pair clears the floor and every one
        // is in everyone's top eight.
        let subjects = (1...10).map { subject($0, angle: 0.001 * Double($0)) }

        let links = AffinityEngine.links(among: subjects, neighbors: 10, degreeCap: 3)

        var degree: [Int: Int] = [:]
        for link in links {
            degree[link.pair.low, default: 0] += 1
            degree[link.pair.high, default: 0] += 1
        }
        #expect(degree.values.allSatisfy { $0 <= 3 })
        #expect(!links.isEmpty)
    }

    @Test func theCapKeepsTheStrongestEdges() {
        let subjects = [
            subject(1, angle: 0),
            subject(2, angle: 0.01),    // closest to 1
            subject(3, angle: 0.02),
            subject(4, angle: 0.03)
        ]

        let links = AffinityEngine.links(among: subjects, degreeCap: 1)

        #expect(links.contains { $0.pair == AffinityEngine.Pair(1, 2) })
        #expect(links.count == 2)   // 1–2 and 3–4; nothing has room for more
    }

    // MARK: The overrides

    @Test func aPinnedPairIsNeverReturnedAgain() {
        let subjects = fan(4, spread: 0.05)
        let pinned: Set = [AffinityEngine.Pair(1, 2)]

        let links = AffinityEngine.links(among: subjects, pinned: pinned)

        #expect(!links.contains { $0.pair == AffinityEngine.Pair(1, 2) })
    }

    /// A pinned edge exists whatever the engine says, so it has to spend degree
    /// budget — the cap is about how many lines meet at a node on the map, and a
    /// hand-made line is still a line.
    @Test func pinnedEdgesSpendDegreeBudget() {
        let subjects = (1...6).map { subject($0, angle: 0.001 * Double($0)) }
        let pinned: Set = [AffinityEngine.Pair(1, 5), AffinityEngine.Pair(1, 6)]

        let links = AffinityEngine.links(among: subjects, pinned: pinned, degreeCap: 3)

        let automatic = links.filter { $0.pair.contains(1) }.count
        #expect(automatic == 1)   // three slots, two already spent
    }

    @Test func aSuppressedPairNeverComesBack() {
        let subjects = fan(4, spread: 0.05)
        let suppressed: Set = [AffinityEngine.Pair(1, 2)]

        let links = AffinityEngine.links(among: subjects, suppressed: suppressed)

        #expect(!links.contains { $0.pair == AffinityEngine.Pair(1, 2) })
    }

    /// A pair somehow marked both ways resolves to suppressed — and, more to the
    /// point, doesn't come back as an automatic edge through the gap.
    @Test func suppressionBeatsPinning() {
        let subjects = fan(4, spread: 0.05)
        let pair = AffinityEngine.Pair(1, 2)

        let links = AffinityEngine.links(among: subjects, pinned: [pair], suppressed: [pair])

        #expect(!links.contains { $0.pair == pair })
    }

    // MARK: Shape

    @Test func aPairIsTheSameConnectionInEitherDirection() {
        #expect(AffinityEngine.Pair(7, 11) == AffinityEngine.Pair(11, 7))
        #expect(AffinityEngine.Pair(7, 11).other(7) == 11)
        #expect(AffinityEngine.Pair(7, 11).other(11) == 7)
    }

    @Test func aLibraryOfOneHasNoConnections() {
        #expect(AffinityEngine.links(among: []).isEmpty)
        #expect(AffinityEngine.links(among: [subject(1, angle: 0)]).isEmpty)
    }

    /// Recomputing over unchanged notes has to return the same graph in the same
    /// order, or the map would look like the app changing its mind.
    @Test func theSameLibraryScoresTheSameWayTwice() {
        let subjects = fan(9, spread: 0.3)

        let first = AffinityEngine.links(among: subjects)
        let second = AffinityEngine.links(among: subjects.reversed())

        #expect(pairs(first) == pairs(second))
        #expect(first.map(\.pair) == second.map(\.pair))
    }

    @Test func linksComeBackStrongestFirst() {
        let links = AffinityEngine.links(among: fan(8, spread: 0.2))

        #expect(links.map(\.score) == links.map(\.score).sorted(by: >))
    }
}
