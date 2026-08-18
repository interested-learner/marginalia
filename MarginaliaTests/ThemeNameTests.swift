import Foundation
import Testing
@testable import Marginalia

/// A theme's name is an extraction from the notes' own words. **It is never
/// invented, and it never comes from a tag** — these are the tests that keep it
/// that way.
///
/// The tag rule was removed rather than relaxed. It was correct — grouping never
/// needed tags — but six of seven themes on the seed library came out tag-named,
/// which read as though tagging were the mechanism.
struct ThemeNameTests {

    /// Phrases the way the app makes them, so these tests exercise the real
    /// path rather than a hand-written approximation of it.
    private func document(_ id: Int, _ text: String) -> ThemeName.Document {
        ThemeName.Document(id: id, phrases: NounPhrases.in(text))
    }

    private func phrases(_ id: Int, _ phrases: [String]) -> ThemeName.Document {
        ThemeName.Document(id: id, phrases: phrases)
    }

    // MARK: Nothing comes from a tag

    @Test func aDocumentCannotCarryATagAtAll() {
        // The type is the guarantee: there is nowhere to put one. If this stops
        // compiling because `tags` came back, the rule came back with it.
        let document = ThemeName.Document(id: 1, phrases: ["human error"])

        #expect(document.phrases == ["human error"])
    }

    @Test func twoNotesSharingAPhraseAreNamedByIt() {
        let members = [
            document(1, "Good error messages assume the system is at fault."),
            document(2, "Human error usually is a result of poor design."),
        ]
        let library = members + [
            document(3, "The motorcycle is a system you are part of."),
            document(4, "Quality is not a thing you add afterwards."),
        ]

        #expect(ThemeName.name(for: members, in: library).text.contains("error"))
    }

    // MARK: Phrases beat bare words

    @Test func aPhraseWinsOverTheWordInsideIt() {
        // `human error` and `error` are shared by exactly the same notes, so
        // they tie on frequency. The one that names an idea has to win.
        let members = [
            phrases(1, ["human error", "human", "error"]),
            phrases(2, ["human error", "human", "error"]),
        ]

        #expect(ThemeName.name(for: members, in: members).text == "human error")
    }

    @Test func aNameNeverRepeatsAWordAcrossItsParts() {
        // Without the disjointness rule this comes out
        // `human error · system error · error messages` — one idea said three
        // times, which is worse than saying it once.
        let members = [
            phrases(1, ["human error", "system error", "error messages", "error"]),
            phrases(2, ["human error", "system error", "error messages", "error"]),
        ]
        let name = ThemeName.name(for: members, in: members)
        let parts = name.text.components(separatedBy: ThemeName.separator)

        // Which of the three wins is the alphabetical tie-break's business —
        // they weigh the same. What matters is that only one of them does.
        #expect(parts.count == 1)
        #expect(name.text.contains("error"))
    }

    @Test func distinctPhrasesAllSurvive() {
        let members = [
            phrases(1, ["human error", "system design", "cognitive ease"]),
            phrases(2, ["human error", "system design", "cognitive ease"]),
        ]
        let name = ThemeName.name(for: members, in: members)
        let parts = name.text.components(separatedBy: ThemeName.separator)

        #expect(parts.count == 3)
        #expect(Set(parts) == ["human error", "system design", "cognitive ease"])
    }

    @Test func aNameCarriesAtMostThreePhrases() {
        let shared = ["alpha one", "beta two", "gamma three", "delta four", "epsilon five"]
        let members = [phrases(1, shared), phrases(2, shared)]
        let name = ThemeName.name(for: members, in: members)

        #expect(name.text.components(separatedBy: ThemeName.separator).count <= ThemeName.terms)
    }

    @Test func phrasesAreJoinedByTheMiddotTheRestOfTheAppUses() {
        let members = [
            phrases(1, ["human error", "system design"]),
            phrases(2, ["human error", "system design"]),
        ]

        #expect(ThemeName.name(for: members, in: members).text.contains(" · "))
    }

    // MARK: What may not name a theme

    @Test func aPhraseInOnlyOneNoteDoesNotNameTheGroup() {
        let members = [
            phrases(1, ["attention", "hapax"]),
            phrases(2, ["attention"]),
        ]
        let name = ThemeName.name(for: members, in: members)

        #expect(name.text == "attention")
        #expect(!name.text.contains("hapax"))
    }

    /// The test `ThemeDumpTests` wrote.
    ///
    /// This originally asserted the opposite — that a group sharing nothing
    /// should still be named from one member's vocabulary. Run against the seed
    /// library that rule produced `aspects · attention · automatically`: with
    /// nothing shared, every candidate ties on weight and the alphabetical
    /// tie-break hands back the first three words in the group. A theme with
    /// nothing in common has no name, and the overview leads with its exemplar.
    @Test func aGroupSharingNoPhraseIsLeftUnnamed() {
        let members = [phrases(1, ["porcelain"]), phrases(2, ["harbour"])]

        #expect(ThemeName.name(for: members, in: members).isEmpty)
    }

    @Test func aNameNeverComesOutAlphabeticalByAccident() {
        let members = [
            phrases(1, ["aspects", "automatically", "apparatus"]),
            phrases(2, ["harbour", "porcelain", "kestrel"]),
        ]

        #expect(ThemeName.name(for: members, in: members).isEmpty)
    }

    @Test func notesWithNoPhrasesProduceNoName() {
        let members = [document(1, "the and of"), document(2, "it is a")]
        let name = ThemeName.name(for: members, in: members)

        #expect(name.isEmpty)
        #expect(name == .none)
    }

    @Test func noMembersProduceNoName() {
        #expect(ThemeName.name(for: [], in: []).isEmpty)
    }

    /// A phrase every note in the library carries says nothing about *this*
    /// theme, so the inverse-frequency term has to bury it.
    @Test func aPhraseCommonToTheWholeLibraryLosesToARarerOne() {
        let members = [
            phrases(1, ["everywhere", "peculiar thing"]),
            phrases(2, ["everywhere", "peculiar thing"]),
        ]
        let library = members + (3...20).map { phrases($0, ["everywhere"]) }
        let name = ThemeName.name(for: members, in: library)

        #expect(name.text.hasPrefix("peculiar thing"))
    }

    // MARK: Determinism

    @Test func theSameNotesAlwaysProduceTheSameName() {
        let shared = ["human error", "system design", "cognitive ease", "error"]
        let members = [phrases(1, shared), phrases(2, shared), phrases(3, shared)]
        let library = members + [phrases(4, ["a wholly separate matter"])]
        let first = ThemeName.name(for: members, in: library)

        for _ in 1...12 {
            #expect(ThemeName.name(for: members.shuffled(), in: library.shuffled()) == first)
        }
    }

    // MARK: Splitting, which the stopword list is written against

    @Test func wordsAreLowercasedAndStrippedOfPunctuation() {
        #expect(ThemeName.words(in: "Affordance, Signifier; MAPPING.") == ["affordance", "signifier", "mapping"])
    }

    @Test func shortWordsAreDropped() {
        #expect(ThemeName.words(in: "an ox is up") == [])
    }

    @Test func stopwordsAreDropped() {
        #expect(ThemeName.words(in: "the error was because they should think") == ["error"])
    }
}

/// The impure half: `NLTagger` in, phrases out.
struct NounPhrasesTests {

    @Test func anAdjectiveAndANounMakeAPhrase() {
        let found = NounPhrases.in("Human error is the problem.")

        #expect(found.contains("human error"))
    }

    @Test func theNounsInsideAPhraseAreOfferedToo() {
        // Phrases are sparse — `human error` may appear in one note while
        // `error` appears in six — so the bare nouns have to be candidates or
        // most themes would find nothing shared and go unnamed.
        let found = NounPhrases.in("Human error is the problem.")

        #expect(found.contains("error"))
    }

    @Test func aTrailingAdjectiveIsNotAPhrase() {
        // `the design is good` must not offer `good`, which names nothing.
        let found = NounPhrases.in("The design is good.")

        #expect(!found.contains("good"))
        #expect(found.contains("design"))
    }

    @Test func stopwordsNeverBecomePhrases() {
        let found = NounPhrases.in("The thing is the same thing.")

        #expect(!found.contains("thing"))
    }

    @Test func shortWordsNeverBecomePhrases() {
        #expect(NounPhrases.in("An ox ate.").allSatisfy { $0.count >= 3 })
    }

    @Test func aPhraseIsCappedInLength() {
        let longest = NounPhrases.in("The great big red american fire truck arrived.")
            .map { $0.split(separator: " ").count }
            .max() ?? 0

        #expect(longest <= NounPhrases.longest)
    }

    @Test func emptyTextHasNoPhrases() {
        #expect(NounPhrases.in("").isEmpty)
    }

    @Test func theSameTextAlwaysGivesTheSamePhrases() {
        let text = "Good error messages assume the system is at fault."

        #expect(NounPhrases.in(text) == NounPhrases.in(text))
    }
}
