import Foundation

/// `2 mins ago` — the second half of a stream row's metadata line.
///
/// Lowercase like every other piece of chrome, and deliberately not
/// `RelativeDateTimeFormatter`: that produces "2 minutes ago" and localizes
/// into shapes the monospaced grid wasn't drawn for.
enum RelativeTime {

    static func label(for date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let seconds = now.timeIntervalSince(date)

        // Clock skew and restored backups both hand back future dates. They
        // must not read `-3 mins ago`.
        guard seconds >= 60 else { return "just now" }

        let minutes = Int(seconds / 60)
        if minutes < 60 { return count(minutes, "min") }

        let hours = minutes / 60
        if hours < 24 { return count(hours, "hr") }

        let days = hours / 24
        if days < 7 { return count(days, "day") }

        return dateLabel(for: date, calendar: calendar)
    }

    private static func count(_ n: Int, _ unit: String) -> String {
        "\(n) \(unit)\(n == 1 ? "" : "s") ago"
    }

    /// `aug 01`. The year is dropped — a note's age past a week is context, not
    /// a fact you read off the row.
    private static func dateLabel(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.month, .day], from: date)
        guard let month = parts.month, let day = parts.day else { return "" }
        return "\(months[month - 1]) \(String(format: "%02d", day))"
    }

    private static let months = ["jan", "feb", "mar", "apr", "may", "jun",
                                 "jul", "aug", "sep", "oct", "nov", "dec"]

    /// `thu aug 13` — the date beside `today` in a stream group header.
    static func dayLabel(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.weekday, .month, .day], from: date)
        guard let weekday = parts.weekday, let month = parts.month, let day = parts.day
        else { return "" }
        return "\(weekdays[weekday - 1]) \(months[month - 1]) \(String(format: "%02d", day))"
    }

    private static let weekdays = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]

    /// `7 months apart` — the distance between the two notes on a crossing card,
    /// and the fact that makes the card land. *You thought this in August and
    /// again in March and never noticed.*
    ///
    /// **Symmetric**, because a crossing has no direction. `NoteEdge` stores one
    /// and the app has displayed both ways since phase 6; a line that read
    /// differently depending on which note came first would be the first place
    /// that stopped being true.
    static func gap(from a: Date, to b: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: min(a, b), to: max(a, b))
        if let years = parts.year, years > 0 { return apart(years, "year") }
        if let months = parts.month, months > 0 { return apart(months, "month") }
        if let days = parts.day, days > 0 { return apart(days, "day") }
        return "the same day"
    }

    private static func apart(_ n: Int, _ unit: String) -> String {
        "\(n) \(unit)\(n == 1 ? "" : "s") apart"
    }

    /// `0:07` — the timer beside the recording dot. Seconds are padded and
    /// minutes are not, so the row doesn't jitter as the count climbs.
    static func elapsed(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }
}
