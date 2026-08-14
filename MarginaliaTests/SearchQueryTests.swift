import Testing
@testable import Marginalia

/// What was typed, taken apart. `#tag` is the one piece of syntax the field has.
struct SearchQueryTests {

    @Test func wordsBecomeTerms() {
        let query = SearchQuery("attention budget")
        #expect(query.terms == ["attention", "budget"])
        #expect(query.tags.isEmpty)
    }

    @Test func termsAreLowercasedSoTypingIsNotACommitment() {
        #expect(SearchQuery("Attention").terms == ["attention"])
    }

    @Test func aHashedWordFiltersByTagInsteadOfSearchingForIt() {
        let query = SearchQuery("#attention")
        #expect(query.tags == ["attention"])
        #expect(query.terms.isEmpty)
    }

    @Test func tagsAndTermsMixInOneQuery() {
        let query = SearchQuery("error #systems design")
        #expect(query.terms == ["error", "design"])
        #expect(query.tags == ["systems"])
    }

    /// The same normalization `TagIndex` does everywhere else, or `#Attention`
    /// would be a different filter from the chip above the stream.
    @Test func aTagIsNormalizedTheWayEveryOtherTagIs() {
        #expect(SearchQuery("#Attention").tags == ["attention"])
        #expect(SearchQuery("##attention").tags == ["attention"])
    }

    @Test func aRepeatedWordIsAskedForOnce() {
        #expect(SearchQuery("design design #a #a").terms == ["design"])
        #expect(SearchQuery("design design #a #a").tags == ["a"])
    }

    @Test func nothingTypedIsAnEmptyQuery() {
        #expect(SearchQuery("").isEmpty)
        #expect(SearchQuery("    ").isEmpty)
    }

    /// Somebody halfway through typing a tag hasn't asked for a filter that
    /// matches nothing.
    @Test func aBareHashIsNotAFilter() {
        #expect(SearchQuery("#").isEmpty)
    }
}
