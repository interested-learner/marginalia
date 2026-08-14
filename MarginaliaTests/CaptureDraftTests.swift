import Testing
import Foundation
@testable import Marginalia

/// What the capture sheet holds before anything is written to the store.
///
/// Everything the user types arrives as a string — the page, the tags, the body
/// — and this is where those become the values a `Note` actually stores.
struct CaptureDraftTests {

    // MARK: Saveable

    @Test func aDraftWithNothingInItCannotBeSaved() {
        #expect(CaptureDraft().canSave == false)
    }

    @Test func aDraftOfNothingButWhitespaceCannotBeSaved() {
        #expect(CaptureDraft(text: "   \n\t ").canSave == false)
    }

    @Test func aDraftWithTextCanBeSaved() {
        #expect(CaptureDraft(text: "attention is a budget").canSave)
    }

    /// A page or a tag on its own is not a note.
    @Test func metadataAloneCannotBeSaved() {
        #expect(CaptureDraft(page: "214", tags: "#attention").canSave == false)
    }

    // MARK: Body

    @Test func theBodyDropsSurroundingWhitespace() {
        #expect(CaptureDraft(text: "  a thought\n").body == "a thought")
    }

    @Test func theBodyKeepsTheLineBreaksInsideIt() {
        #expect(CaptureDraft(text: "one\ntwo").body == "one\ntwo")
    }

    // MARK: Tags

    @Test func tagsAreSplitOnSpaces() {
        #expect(CaptureDraft(tags: "attention memory").tagList == ["attention", "memory"])
    }

    @Test func tagsAreSplitOnCommasToo() {
        #expect(CaptureDraft(tags: "attention, memory").tagList == ["attention", "memory"])
    }

    /// Tags are stored bare and wear the hash only on screen, so a typed `#`
    /// must not survive into the store as `##attention`.
    @Test func aTypedHashIsStrippedBeforeStoring() {
        #expect(CaptureDraft(tags: "#attention").tagList == ["attention"])
    }

    @Test func tagsAreLowercased() {
        #expect(CaptureDraft(tags: "Attention").tagList == ["attention"])
    }

    @Test func aTagRepeatedInTheFieldIsStoredOnce() {
        #expect(CaptureDraft(tags: "attention #attention").tagList == ["attention"])
    }

    @Test func anEmptyTagFieldYieldsNoTags() {
        #expect(CaptureDraft(tags: "  ,  ").tagList.isEmpty)
    }

    // MARK: Page

    @Test func aBareNumberIsThePage() {
        #expect(CaptureDraft(page: "214").pageNumber == 214)
    }

    /// The field is labelled `p.`, and people type the label back into it.
    @Test func aPagePrefixIsIgnored() {
        #expect(CaptureDraft(page: "p.214").pageNumber == 214)
    }

    @Test func anEmptyPageIsNoPage() {
        #expect(CaptureDraft(page: " ").pageNumber == nil)
    }

    /// `p.0` on a source line would read as a bug, and it is one.
    @Test func pageZeroIsNoPage() {
        #expect(CaptureDraft(page: "0").pageNumber == nil)
    }

    @Test func aNegativePageIsNoPage() {
        #expect(CaptureDraft(page: "-3").pageNumber == nil)
    }

    @Test func somethingThatIsntANumberIsNoPage() {
        #expect(CaptureDraft(page: "two hundred").pageNumber == nil)
    }
}
