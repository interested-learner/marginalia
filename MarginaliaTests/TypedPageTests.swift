import Testing
@testable import Marginalia

/// The rule every page field in the app goes through, tested where it lives.
///
/// It had no tests of its own until phase 11 — the same rules were asserted
/// twice over, once through `CaptureDraftTests` and once through
/// `BookDraftTests`, against two separate implementations that happened to
/// agree. Both callers now go through this one, so this is the file that says
/// what `p. 214` means.
@Suite struct TypedPageTests {

    @Test func aPlainNumberIsThePage() {
        #expect(TypedPage.parse("214") == 214)
    }

    /// People type the label back into a field labelled `p.`
    @Test func theLabelIsIgnored() {
        #expect(TypedPage.parse("p. 214") == 214)
        #expect(TypedPage.parse("p.214") == 214)
        #expect(TypedPage.parse("page 214") == 214)
    }

    @Test func nothingIsNoPage() {
        #expect(TypedPage.parse("") == nil)
        #expect(TypedPage.parse("   ") == nil)
    }

    /// `p.0` on a source line reads as a bug and is one.
    @Test func zeroIsNoPage() {
        #expect(TypedPage.parse("0") == nil)
        #expect(TypedPage.parse("p. 0") == nil)
    }

    /// A range is not a page, and neither is a negative — both contain a
    /// hyphen, which is the whole of the test and the reason it's one rule.
    @Test func aRangeIsNoPage() {
        #expect(TypedPage.parse("214-216") == nil)
        #expect(TypedPage.parse("-214") == nil)
    }

    @Test func proseWithNoDigitsIsNoPage() {
        #expect(TypedPage.parse("somewhere near the end") == nil)
    }

    /// Digits anywhere in the string, joined. Deliberate: it is what makes
    /// `p. 214` work, and it means `2 or 14` reads as `214` — the rarer typo,
    /// and one the reader can see in the field they just filled.
    @Test func digitsAreCollected() {
        #expect(TypedPage.parse("chapter 2, p. 14") == 214)
    }
}
