import Testing
import Foundation
@testable import Marginalia

/// `today · wed aug 13` / `yesterday` / `earlier`.
struct StreamGroupingTests {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    private func groups(_ dates: [Date], now: Date) -> [StreamGrouping.Group<Date>] {
        StreamGrouping.groups(dates, date: { $0 }, now: now, calendar: calendar)
    }

    @Test func todayCarriesTheDateAlongsideTheWord() {
        let now = date(2026, 8, 13, 18)
        #expect(groups([date(2026, 8, 13, 9)], now: now).map(\.label) == ["today · thu aug 13"])
    }

    @Test func theThreeBucketsComeBackInOrder() {
        let now = date(2026, 8, 13, 18)
        let labels = groups([date(2026, 8, 13, 9),
                             date(2026, 8, 12, 20),
                             date(2026, 7, 30)], now: now).map(\.label)
        #expect(labels == ["today · thu aug 13", "yesterday", "earlier"])
    }

    /// Anything older than yesterday lands in one bucket rather than a header
    /// per day — a feed of one-row sections is unreadable.
    @Test func everythingOlderThanYesterdayShareOneBucket() throws {
        let now = date(2026, 8, 13, 18)
        let result = groups([date(2026, 8, 11), date(2026, 7, 30), date(2025, 1, 2)], now: now)
        #expect(result.count == 1)
        let earlier = try #require(result.first)
        #expect(earlier.label == "earlier")
        #expect(earlier.items.count == 3)
    }

    @Test func anEmptyBucketGetsNoHeader() {
        let now = date(2026, 8, 13, 18)
        #expect(groups([date(2026, 7, 30)], now: now).map(\.label) == ["earlier"])
    }

    @Test func noNotesMeansNoGroups() {
        #expect(groups([], now: date(2026, 8, 13)).isEmpty)
    }

    /// The stream is newest-first and grouping must not resort it.
    @Test func orderWithinAGroupIsPreserved() throws {
        let now = date(2026, 8, 13, 18)
        let newer = date(2026, 8, 13, 16)
        let older = date(2026, 8, 13, 8)
        let today = try #require(groups([newer, older], now: now).first)
        #expect(today.items == [newer, older])
    }

    /// An hour before midnight and an hour after are different days, however
    /// few minutes separate them.
    @Test func bucketsSplitOnTheCalendarDayNotOnElapsedHours() {
        let now = date(2026, 8, 13, 0)               // just past midnight
        let labels = groups([date(2026, 8, 12, 23)], now: now).map(\.label)
        #expect(labels == ["yesterday"])
    }
}
