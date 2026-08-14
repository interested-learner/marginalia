import SwiftUI

/// What the reader has chosen about the app rather than about their library.
///
/// `UserDefaults`, not SwiftData: none of it is a note, none of it should sync
/// to another device as content, and `ShortIDCounter` already lives there for
/// the same kind of reason.
///
/// The keys are named once here so a screen and a scheduler can't disagree about
/// what "the notification time" is stored under.
nonisolated enum Preferences {

    enum Key {
        static let appearance = "preference.appearance"
        static let notificationsOn = "preference.notifications"
        /// Minutes past midnight. A `Date` would carry a day with it, and the
        /// day is the one thing a daily reminder must not remember.
        static let notificationMinute = "preference.notificationMinute"
    }

    /// 08:00. Early enough to be part of the morning, late enough not to be an
    /// alarm clock.
    static let defaultMinute = 8 * 60
}

/// System, light, or dark — the third setting the spec asks for, and the one the
/// design system has been carrying two palettes for since phase 1.
nonisolated enum Appearance: String, CaseIterable, Sendable {
    case system, light, dark

    var label: String { rawValue }

    /// `nil` is "whatever the phone says", which is what SwiftUI wants for it.
    var scheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// `8:00 am` — the notification time, written the way the app writes everything
/// else: lowercase, and no locale surprises in the middle of a settings row.
nonisolated enum ClockTime {

    static let minutesInDay = 24 * 60

    /// Wrapped rather than clamped, so stepping past midnight comes back round
    /// to the start of the day instead of sticking at 23:59.
    static func normalized(_ minute: Int) -> Int {
        let wrapped = minute % minutesInDay
        return wrapped < 0 ? wrapped + minutesInDay : wrapped
    }

    static func hour(_ minute: Int) -> Int { normalized(minute) / 60 }

    static func minute(_ minute: Int) -> Int { normalized(minute) % 60 }

    static func label(_ minute: Int) -> String {
        let hours = hour(minute)
        let minutes = self.minute(minute)
        let clock = hours % 12 == 0 ? 12 : hours % 12
        return String(format: "%d:%02d %@", clock, minutes, hours < 12 ? "am" : "pm")
    }
}
