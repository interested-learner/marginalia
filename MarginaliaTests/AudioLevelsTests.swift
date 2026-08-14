import Testing
@testable import Marginalia

/// The `▁▂▃▄▅▆▇` waveform, as a pure function of what the microphone heard.
///
/// Pure because the alternative is judging a recording animation by eye, and
/// the simulator has no microphone to drive it with.
struct AudioLevelsTests {

    // MARK: Power to bar

    @Test func silenceIsTheShortestBar() {
        #expect(AudioLevels.bar(power: -160) == 0)
    }

    @Test func fullScaleIsTheTallestBar() {
        #expect(AudioLevels.bar(power: 0) == 6)
    }

    /// Room tone sits well below the floor and must not draw a visible bar, or
    /// the waveform twitches in a silent room.
    @Test func anythingUnderTheFloorIsTheShortestBar() {
        #expect(AudioLevels.bar(power: -80) == 0)
    }

    @Test func halfwayUpFromTheFloorIsAMiddleBar() {
        #expect(AudioLevels.bar(power: -25) == 3)
    }

    @Test func aLouderSoundIsNeverAShorterBar() {
        let bars = stride(from: Float(-60), through: 0, by: 2).map(AudioLevels.bar(power:))
        #expect(bars == bars.sorted())
    }

    /// A clipped sample reads above 0 dBFS, and the glyph table ends at seven.
    @Test func aSampleAboveFullScaleStillFitsTheGlyphTable() {
        #expect(AudioLevels.bar(power: 12) == 6)
    }

    // MARK: The scrolling window

    @Test func aFreshWindowIsSilentAndFullWidth() {
        #expect(AudioLevels.silence(width: 18) == Array(repeating: 0, count: 18))
    }

    @Test func theWindowKeepsItsWidthAsItScrolls() {
        var levels = AudioLevels.silence(width: 18)
        for _ in 0..<40 { levels = AudioLevels.scrolling(levels, adding: 4, width: 18) }
        #expect(levels.count == 18)
    }

    /// The waveform reads left to right, so the newest sample is at the end.
    @Test func theNewestBarLandsAtTheEnd() {
        let levels = AudioLevels.scrolling(AudioLevels.silence(width: 4), adding: 5, width: 4)
        #expect(levels == [0, 0, 0, 5])
    }

    @Test func theOldestBarFallsOffTheFront() {
        let levels = AudioLevels.scrolling([1, 2, 3, 4], adding: 5, width: 4)
        #expect(levels == [2, 3, 4, 5])
    }

    /// The bar runs 18 bars and the full sheet 22, so a window has to be able to
    /// grow into its width rather than assuming it started there.
    @Test func aShortWindowFillsUpToItsWidth() {
        #expect(AudioLevels.scrolling([1, 2], adding: 3, width: 4) == [1, 2, 3])
    }
}
