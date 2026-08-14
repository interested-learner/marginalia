import Foundation
import SwiftUI
import Testing
@testable import Marginalia

/// The clock on a settings row, and the appearance that reaches the whole app.
struct PreferencesTests {

    // MARK: The clock

    @Test func minutesPastMidnightReadAsATime() {
        #expect(ClockTime.label(0) == "12:00 am")
        #expect(ClockTime.label(8 * 60) == "8:00 am")
        #expect(ClockTime.label(12 * 60) == "12:00 pm")
        #expect(ClockTime.label(13 * 60 + 30) == "1:30 pm")
        #expect(ClockTime.label(23 * 60 + 59) == "11:59 pm")
    }

    @Test func theDefaultIsEightInTheMorning() {
        #expect(ClockTime.label(Preferences.defaultMinute) == "8:00 am")
    }

    /// Wrapped rather than clamped: stepping past midnight comes back round to
    /// the start of the day instead of sticking at 23:59.
    @Test func aTimePastMidnightWrapsRatherThanSticking() {
        #expect(ClockTime.normalized(ClockTime.minutesInDay) == 0)
        #expect(ClockTime.normalized(ClockTime.minutesInDay + 90) == 90)
        #expect(ClockTime.normalized(-30) == 23 * 60 + 30)
    }

    @Test func hourAndMinuteComeApartTheWayACalendarWantsThem() {
        #expect(ClockTime.hour(13 * 60 + 30) == 13)
        #expect(ClockTime.minute(13 * 60 + 30) == 30)
    }

    // MARK: Appearance

    @Test func systemDefersToThePhone() {
        #expect(Appearance.system.scheme == nil)
        #expect(Appearance.light.scheme == .light)
        #expect(Appearance.dark.scheme == .dark)
    }

    @Test func theThreeChoicesFitOneSegmentedRow() {
        #expect(Appearance.allCases.map(\.label) == ["system", "light", "dark"])
    }

    /// Stored as a raw string, for the same reason `statusRaw` is: a setting
    /// written by one version has to still be readable by the next.
    @Test func anUnknownStoredAppearanceFallsBackRatherThanCrashing() {
        #expect(Appearance(rawValue: "sepia") == nil)
    }
}
