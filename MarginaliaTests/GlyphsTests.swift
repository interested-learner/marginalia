import Testing
@testable import Marginalia

/// Phase 1 has little logic worth testing — these cover the two pure formatters
/// in `Glyphs` and, just as importantly, prove the test target builds and runs
/// before phase 2 starts leaning on it.
struct GlyphsTests {

    @Test func progressBarIsAlwaysTenCellsInBrackets() {
        #expect(Glyphs.progress(0) == "[░░░░░░░░░░]")
        #expect(Glyphs.progress(1) == "[██████████]")
        #expect(Glyphs.progress(0.3) == "[███░░░░░░░]")
    }

    @Test func progressBarClampsOutOfRangeInput() {
        #expect(Glyphs.progress(-5) == "[░░░░░░░░░░]")
        #expect(Glyphs.progress(99) == "[██████████]")
    }

    @Test func noteIDsAreZeroPaddedToTwoDigits() {
        #expect(Glyphs.noteID(5) == "n.05")
        #expect(Glyphs.noteID(11) == "n.11")
    }

    /// Ids keep growing past two digits rather than truncating — a note is
    /// never renamed, because a link pointing at the wrong note would be worse
    /// than one pointing at nothing.
    @Test func noteIDsGrowBeyondTwoDigits() {
        #expect(Glyphs.noteID(1234) == "n.1234")
    }

    @Test func waveformClampsLevelsToTheAvailableBars() {
        #expect(Glyphs.wave([0, 6]) == "▁▇")
        #expect(Glyphs.wave([-1, 99]) == "▁▇")
    }

    @Test func countsAreBracketed() {
        #expect(Glyphs.count(0) == "[0]")
        #expect(Glyphs.count(42) == "[42]")
    }
}
