import Testing
@testable import Marginalia

/// `0:07` — the timer beside the recording dot.
struct ElapsedTimeTests {

    @Test func recordingStartsAtZero() {
        #expect(RelativeTime.elapsed(0) == "0:00")
    }

    /// Seconds are always two digits, or the row jitters as the number grows.
    @Test func secondsArePaddedToTwoDigits() {
        #expect(RelativeTime.elapsed(7) == "0:07")
    }

    @Test func aMinuteRollsTheLeadingFigureOver() {
        #expect(RelativeTime.elapsed(83) == "1:23")
    }

    /// Minutes are not padded — `12:05`, not `012:05`.
    @Test func minutesGrowPastTenWithoutPadding() {
        #expect(RelativeTime.elapsed(725) == "12:05")
    }

    @Test func anHourKeepsCountingInMinutes() {
        #expect(RelativeTime.elapsed(3661) == "61:01")
    }

    /// A clock read before the recording started must not show `-1:-5`.
    @Test func aNegativeIntervalReadsAsZero() {
        #expect(RelativeTime.elapsed(-5) == "0:00")
    }

    @Test func aFractionOfASecondRoundsDown() {
        #expect(RelativeTime.elapsed(1.9) == "0:01")
    }
}
