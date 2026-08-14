import Testing
@testable import Marginalia

/// What the camera hands back, and what a passage reads as.
///
/// VisionKit recognizes a printed page a line at a time, and a passage is
/// several of those lines tapped one after another. Turning them back into
/// prose is the whole of the pure half of the scanner, so it's tested here
/// rather than judged by eye through a viewfinder.
struct ScannedPassageTests {

    // MARK: Joining

    @Test func oneLineIsThePassage() {
        #expect(ScannedPassage.joined(["attention is a budget"]) == "attention is a budget")
    }

    @Test func linesAreJoinedWithOneSpace() {
        #expect(ScannedPassage.joined(["attention is", "a budget"]) == "attention is a budget")
    }

    /// A printed page breaks a word at the margin. Rejoining it is the one
    /// thing a reader would otherwise have to fix by hand on every scan.
    @Test func aWordBrokenAtTheMarginIsPutBackTogether() {
        #expect(ScannedPassage.joined(["the appear-", "ance of things"]) == "the appearance of things")
    }

    /// An en or em dash at the end of a line is punctuation, not a broken
    /// word — the sentence continues after it and the dash stays.
    @Test func aDashIsNotAWordBreak() {
        #expect(ScannedPassage.joined(["a system \u{2014}", "not a thing"]) == "a system \u{2014} not a thing")
    }

    /// A hyphen with a space in front of it was typed, not printed into the
    /// margin, so it isn't a break either.
    @Test func aHyphenStandingAloneIsNotAWordBreak() {
        #expect(ScannedPassage.joined(["a system -", "of a kind"]) == "a system - of a kind")
    }

    @Test func runsOfWhitespaceInsideALineCloseUp() {
        #expect(ScannedPassage.joined(["attention    is\ta budget"]) == "attention is a budget")
    }

    @Test func aLineBreakInsideOneRecognizedItemIsJoinedToo() {
        #expect(ScannedPassage.joined(["attention is\na budget"]) == "attention is a budget")
    }

    @Test func surroundingWhitespaceIsDropped() {
        #expect(ScannedPassage.joined(["  attention is a budget  "]) == "attention is a budget")
    }

    @Test func blankLinesContributeNothing() {
        #expect(ScannedPassage.joined(["attention", "   ", "is a budget"]) == "attention is a budget")
    }

    @Test func nothingScannedIsAnEmptyPassage() {
        #expect(ScannedPassage.joined([]).isEmpty)
    }

    // MARK: Appending

    /// Each tap adds a line to what's already collected, so the passage builds
    /// under the reader's thumb rather than arriving all at once.
    @Test func appendingAddsToWhatIsAlreadyThere() {
        let first = ScannedPassage.appending("attention is", to: "")
        #expect(ScannedPassage.appending("a budget", to: first) == "attention is a budget")
    }

    @Test func appendingToNothingIsJustTheLine() {
        #expect(ScannedPassage.appending("  attention  ", to: "") == "attention")
    }

    @Test func appendingRejoinsAWordBrokenAtTheMargin() {
        #expect(ScannedPassage.appending("ance of things", to: "the appear-") == "the appearance of things")
    }

    /// A tap that recognized nothing shouldn't leave a space behind it.
    @Test func appendingNothingLeavesThePassageAlone() {
        #expect(ScannedPassage.appending("   ", to: "attention is a budget") == "attention is a budget")
    }

    // MARK: What a scan becomes

    /// A scan is a passage off a printed page, so it's drawn with the quote
    /// rule — and it stays `[s] scan`, because how a note was captured is a
    /// fact about the note, the same rule voice notes follow.
    @Test func aScanReadsAsAPassage() {
        #expect(NoteKind.scan.isPassage)
        #expect(NoteKind.quote.isPassage)
        #expect(NoteKind.thought.isPassage == false)
        #expect(NoteKind.voice.isPassage == false)
    }

    @Test func aScanKeepsItsOwnMarker() {
        #expect(NoteKind.scan.marker == Glyphs.scan)
        #expect(NoteKind.scan.label == "scan")
    }
}
