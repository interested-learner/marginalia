import Testing
import Foundation
@testable import Marginalia

/// The `2 min ago` half of a stream row's metadata line.
struct RelativeTimeTests {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private func label(_ then: Date, _ now: Date) -> String {
        RelativeTime.label(for: then, now: now, calendar: calendar)
    }

    @Test func underAMinuteReadsAsJustNow() {
        let now = date(2026, 8, 13)
        #expect(label(now.addingTimeInterval(-30), now) == "just now")
    }

    @Test func minutesAreSingularAtOne() {
        let now = date(2026, 8, 13)
        #expect(label(now.addingTimeInterval(-60), now) == "1 min ago")
        #expect(label(now.addingTimeInterval(-60 * 2), now) == "2 mins ago")
    }

    @Test func hoursAreSingularAtOne() {
        let now = date(2026, 8, 13)
        #expect(label(now.addingTimeInterval(-3600), now) == "1 hr ago")
        #expect(label(now.addingTimeInterval(-3600 * 5), now) == "5 hrs ago")
    }

    @Test func daysAreSingularAtOne() {
        let now = date(2026, 8, 13)
        #expect(label(now.addingTimeInterval(-86400), now) == "1 day ago")
        #expect(label(now.addingTimeInterval(-86400 * 6), now) == "6 days ago")
    }

    /// Past a week the count stops meaning anything, so it becomes a date —
    /// lowercase, like every other piece of chrome in the app.
    @Test func beyondAWeekItBecomesALowercaseDate() {
        #expect(label(date(2026, 8, 1), date(2026, 8, 13)) == "aug 01")
    }

    /// A date in another year still reads as a date; the year is what's dropped,
    /// not the note.
    @Test func aDateInAnotherYearKeepsTheSameShape() {
        #expect(label(date(2025, 12, 24), date(2026, 8, 13)) == "dec 24")
    }

    /// Clock skew and iCloud can hand back a future date. It must not read
    /// `-3 mins ago`.
    @Test func aFutureDateReadsAsJustNow() {
        let now = date(2026, 8, 13)
        #expect(label(now.addingTimeInterval(600), now) == "just now")
    }

    // MARK: gap — the crossing card's distance line
    //
    // Reuses the `calendar` and `date(_:_:_:)` helpers already at the top of
    // this struct. Do not add a second UTC calendar beside them.

    @Test func gapWithinADayIsTheSameDay() {
        #expect(RelativeTime.gap(from: date(2026, 3, 1), to: date(2026, 3, 1), calendar: calendar)
                == "the same day")
    }

    @Test func gapOfOneDayIsSingular() {
        #expect(RelativeTime.gap(from: date(2026, 3, 1), to: date(2026, 3, 2), calendar: calendar)
                == "1 day apart")
    }

    @Test func gapInDaysBelowAMonth() {
        #expect(RelativeTime.gap(from: date(2026, 3, 1), to: date(2026, 3, 20), calendar: calendar)
                == "19 days apart")
    }

    @Test func gapInMonths() {
        #expect(RelativeTime.gap(from: date(2025, 8, 14), to: date(2026, 3, 20), calendar: calendar)
                == "7 months apart")
    }

    @Test func gapInYears() {
        #expect(RelativeTime.gap(from: date(2024, 1, 10), to: date(2026, 3, 20), calendar: calendar)
                == "2 years apart")
    }

    /// A crossing has no direction, so neither does the line that measures it.
    @Test func gapIsSymmetric() {
        let earlier = date(2025, 8, 14)
        let later = date(2026, 3, 20)
        #expect(RelativeTime.gap(from: later, to: earlier, calendar: calendar)
                == RelativeTime.gap(from: earlier, to: later, calendar: calendar))
    }
}
