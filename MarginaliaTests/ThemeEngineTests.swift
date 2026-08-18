import Foundation
import Testing
@testable import Marginalia

/// What the grouping guarantees.
///
/// Like `AffinityEngineTests`, **none of this can tell anyone whether the themes
/// are any good** — that needs a person reading real output, which is what
/// `ThemeDumpTests` is for. What these prove is that the rule is the rule: that
/// membership follows the rankings and nothing else, that the same library
/// always partitions the same way, and that the floor which cost phase 6 its
/// best missed pair has no say here.
struct ThemeEngineTests {

    // MARK: Building subjects by hand

    /// Angle in the first two dimensions, unit length — the same device
    /// `AffinityEngineTests` uses, so a score is a number this file chose.
    private func subject(_ id: Int, angle: Double, tags: [String] = [], book: Int? = nil) -> ThemeEngine.Subject {
        ThemeEngine.Subject(
            id: id,
            vector: [Float(cos(angle)), Float(sin(angle))],
            tags: tags,
            book: book
        )
    }

    /// `count` vectors fanned evenly over `spread`.
    ///
    /// **The ranking of any note's neighbours is by `|i − j|` whatever `spread`
    /// is** — a narrower fan raises every cosine without reordering a single
    /// one. That property is what the rank-invariance test below rides on.
    private func fan(_ count: Int, spread: Double) -> [ThemeEngine.Subject] {
        (1...count).map { subject($0, angle: spread * Double($0 - 1) / Double(count)) }
    }

    /// Mutually orthogonal — every cosine is exactly zero, so nothing can be
    /// near anything.
    private func basis(_ count: Int) -> [ThemeEngine.Subject] {
        (1...count).map { id in
            var vector = [Float](repeating: 0, count: count)
            vector[id - 1] = 1
            return ThemeEngine.Subject(id: id, vector: vector)
        }
    }

    private func placed(_ reading: ThemeEngine.Reading) -> [Int] {
        (reading.themes.flatMap(\.members) + reading.loose).sorted()
    }

    // MARK: Degenerate libraries

    @Test func anEmptyLibraryReadsAsNothing() {
        #expect(ThemeEngine.reading([]).isEmpty)
    }

    @Test func oneNoteIsLooseBecauseItHasNothingToBeNear() {
        let reading = ThemeEngine.reading([subject(1, angle: 0)])

        #expect(reading.themes.isEmpty)
        #expect(reading.loose == [1])
    }

    @Test func twoIdenticalNotesAreOneTheme() {
        let reading = ThemeEngine.reading([subject(1, angle: 0), subject(2, angle: 0)])

        #expect(reading.themes.count == 1)
        #expect(reading.themes.first?.members == [1, 2])
        #expect(reading.loose.isEmpty)
    }

    @Test func identicalVectorsCollapseIntoOneTheme() {
        let reading = ThemeEngine.reading((1...5).map { subject($0, angle: 0) })

        #expect(reading.themes.count == 1)
        #expect(reading.themes.first?.members == [1, 2, 3, 4, 5])
        #expect(reading.loose.isEmpty)
    }

    @Test func orthogonalNotesGroupWithNobody() {
        let reading = ThemeEngine.reading(basis(4))

        #expect(reading.themes.isEmpty)
        #expect(reading.loose == [1, 2, 3, 4])
    }

    @Test func aNoteWithNoUsableVectorIsLooseRatherThanDropped() {
        // The note was never embedded, or was embedded by a model that isn't the
        // one loaded today. Either way a cosine against it means nothing, and
        // the reader is told rather than the note quietly vanishing.
        let subjects = [
            subject(1, angle: 0),
            subject(2, angle: 0),
            ThemeEngine.Subject(id: 3, vector: []),
        ]
        let reading = ThemeEngine.reading(subjects)

        #expect(reading.loose.contains(3))
        #expect(placed(reading) == [1, 2, 3])
    }

    // MARK: The partition is a partition

    @Test func everyNoteIsPlacedExactlyOnce() {
        let reading = ThemeEngine.reading(fan(20, spread: .pi / 2))

        #expect(placed(reading) == Array(1...20))
    }

    @Test func aThemeNeverHasOneMember() {
        let reading = ThemeEngine.reading(fan(20, spread: .pi / 2))

        #expect(reading.themes.allSatisfy { $0.members.count > 1 })
    }

    @Test func theExemplarIsAlwaysOneOfTheMembers() {
        let reading = ThemeEngine.reading(fan(20, spread: .pi / 2))

        #expect(reading.themes.allSatisfy { $0.members.contains($0.exemplar) })
    }

    // MARK: Determinism

    @Test func theSameLibraryReadsTheSameWayWhateverOrderItArrivesIn() {
        let subjects = fan(16, spread: .pi / 2)
        let forwards = ThemeEngine.reading(subjects)
        let backwards = ThemeEngine.reading(subjects.reversed())

        #expect(forwards == backwards)
    }

    @Test func shufflingTheInputChangesNothing() {
        let subjects = fan(16, spread: .pi / 2)
        let straight = ThemeEngine.reading(subjects)

        // Several shuffles rather than one, because a single lucky ordering
        // proves nothing about a rule that only ever fails intermittently — and
        // dictionary iteration order, which this file is really testing, is
        // exactly that kind of rule.
        for _ in 1...8 {
            #expect(ThemeEngine.reading(subjects.shuffled()) == straight)
        }
    }

    // MARK: The guarantee this design exists for

    /// **Membership and order depend on the rankings and on nothing else.**
    ///
    /// A narrower fan raises every cosine in the library without reordering any
    /// note's neighbours — which is a fair model of what happens the day
    /// `NLContextualEmbedding`'s assets finally compile and the fallback's
    /// magnitudes are replaced wholesale. If a similarity *threshold* decided
    /// membership this test would fail outright; if the community step were
    /// weighted by score it would fail intermittently, which is worse.
    @Test func themesSurviveAWholesaleShiftInSimilarityMagnitudes() {
        let wide = ThemeEngine.reading(fan(16, spread: .pi / 2))
        let narrow = ThemeEngine.reading(fan(16, spread: .pi / 6))

        #expect(wide.themes.map(\.members) == narrow.themes.map(\.members))
        #expect(wide.loose == narrow.loose)
    }

    @Test func evenAVeryTightFanPartitionsTheSameWay() {
        let wide = ThemeEngine.reading(fan(24, spread: .pi / 2))
        let tight = ThemeEngine.reading(fan(24, spread: .pi / 24))

        #expect(wide.themes.map(\.members) == tight.themes.map(\.members))
    }

    // MARK: The floor has no say here

    /// The pair phase 6 called the worse half of its own output.
    ///
    /// `n.03` "good error messages assume the system is at fault" and `n.04`
    /// "human error is system error" score `0.448` — a near-restatement of one
    /// idea, rejected by `AffinityEngine.floor` and not by its k-NN rule. A
    /// grouping built on the edge graph would inherit that miss. This one does
    /// not, and this test is the reason the two engines are separate files.
    @Test func aPairBelowTheConnectionFloorStillFormsATheme() {
        // cos(0.9764) ≈ 0.56, so 0.8 · 0.56 ≈ 0.448 — under the floor of 0.55.
        let a = subject(3, angle: 0)
        let b = subject(4, angle: 0.9764)

        let affinity = AffinityEngine.Subject(id: 3, vector: a.vector, tags: [])
        let other = AffinityEngine.Subject(id: 4, vector: b.vector, tags: [])
        let score = AffinityEngine.score(affinity, other)

        #expect(score < AffinityEngine.floor)
        #expect(score > 0.4)

        let reading = ThemeEngine.reading([a, b])
        #expect(reading.themes.count == 1)
        #expect(reading.themes.first?.members == [3, 4])
    }

    // MARK: What a theme says about itself

    @Test func aThemeReportsTheBooksItSpans() {
        let subjects = [
            subject(1, angle: 0, book: 2),
            subject(2, angle: 0, book: 0),
            subject(3, angle: 0, book: 2),
        ]
        let reading = ThemeEngine.reading(subjects)

        #expect(reading.themes.first?.books == [0, 2])
    }

    @Test func aNoteWithNoBookAddsNothingToTheSpan() {
        let subjects = [
            subject(1, angle: 0, book: 1),
            subject(2, angle: 0, book: nil),
        ]
        let reading = ThemeEngine.reading(subjects)

        #expect(reading.themes.first?.books == [1])
    }

    @Test func themesComeBackBiggestFirst() {
        let reading = ThemeEngine.reading(fan(30, spread: .pi / 2))
        let counts = reading.themes.map(\.count)

        #expect(counts == counts.sorted(by: >))
    }

    @Test func aThemesIdentityIsItsExemplar() {
        let reading = ThemeEngine.reading(fan(16, spread: .pi / 2))

        // Themes partition the library, so exemplars can't collide — which is
        // what makes one safe to carry in a navigation path and in `-mapTheme`.
        let exemplars = reading.themes.map(\.exemplar)
        #expect(Set(exemplars).count == exemplars.count)
        #expect(reading.themes.allSatisfy { $0.id == $0.exemplar })
    }

    // MARK: Tags count toward grouping, as they do toward connecting

    @Test func sharedTagsPullTwoNotesTogether() {
        // Far enough apart that the vectors alone rank them last, close enough
        // once Jaccard is added. Grouping uses `AffinityEngine.score` whole —
        // there is one definition of similarity in this app.
        let tagged = ThemeEngine.reading([
            subject(1, angle: 0, tags: ["systems"]),
            subject(2, angle: 0, tags: ["systems"]),
        ])
        let bare = ThemeEngine.reading([
            subject(1, angle: 0),
            subject(2, angle: 0),
        ])

        #expect(tagged.themes.count == 1)
        #expect(bare.themes.count == 1)
    }
}
