import Testing
@testable import Marginalia

/// The chips above the stream are derived from the notes, never hand-listed.
struct TagIndexTests {

    @Test func tagsAreOrderedByHowOftenTheyAreUsed() {
        let tags = TagIndex.chips(for: [["craft"], ["design", "craft"], ["craft", "design"]])
        #expect(tags == ["craft", "design"])
    }

    @Test func equallyUsedTagsFallBackToAlphabetical() {
        #expect(TagIndex.chips(for: [["systems"], ["craft"], ["design"]])
                == ["craft", "design", "systems"])
    }

    @Test func aTagUsedTwiceOnOneNoteCountsOnce() {
        let tags = TagIndex.chips(for: [["craft", "craft"], ["design"], ["design"]])
        #expect(tags == ["design", "craft"])
    }

    @Test func notesWithoutTagsContributeNothing() {
        #expect(TagIndex.chips(for: [[], []]) == [])
    }

    /// Tags are stored bare and rendered with the `#`, so a stray one typed by
    /// the user must not produce a `##design` chip.
    @Test func aLeadingHashIsStrippedFromStorage() {
        #expect(TagIndex.chips(for: [["#design"], ["design"]]) == ["design"])
    }

    @Test func caseAndSurroundingSpaceDoNotSplitATag() {
        #expect(TagIndex.chips(for: [[" Design "], ["design"]]) == ["design"])
    }
}
