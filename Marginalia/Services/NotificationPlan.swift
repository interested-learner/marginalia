import Foundation

/// What the next seven days' reminders say, and when they fire.
///
/// **Pure**, and separate from `NotificationScheduler` for the same reason
/// `AffinityEngine` is separate from `LinkWriter`: which note tomorrow's
/// reminder carries is a rule worth asserting, and `UNUserNotificationCenter`
/// can't be asked about it in a test.
///
/// The note is **the first card of that day's review set**, so the reminder and
/// the screen it opens agree — `ReviewSetBuilder` is day-stable, so asking it
/// today what Thursday will look like gets Thursday's real answer.
nonisolated enum NotificationPlan {

    /// Seven, as the spec says. Enough that a phone left in a drawer for a week
    /// still has something queued, few enough to re-schedule on every launch.
    static let days = 7

    struct Entry: Equatable, Identifiable {
        /// The note the reminder is about.
        let shortID: Int
        /// `n.11 · Meditations` — what the alert leads with. iOS puts the app's
        /// own name above this, so the line is spent on the note instead.
        let title: String
        /// The note's actual text. Often the whole interaction: read it on the
        /// lock screen and never open the app.
        let body: String
        /// When it fires, as the components a calendar trigger takes.
        let when: DateComponents

        var id: Int { shortID }
    }

    /// The next `days` reminders, earliest first.
    ///
    /// Starts at the **next** occurrence of `minute` — a reminder set for 8am at
    /// nine in the morning starts tomorrow, rather than firing immediately for
    /// a time that has already passed.
    ///
    /// A day whose set comes back empty is skipped rather than sent with nothing
    /// in it. Under `ReviewSetBuilder.minimum` notes there is no review to open,
    /// so there is nothing to be reminded about either.
    static func entries(
        for notes: [Note],
        minute: Int,
        from now: Date,
        calendar: Calendar = .current,
        days: Int = days
    ) -> [Entry] {
        guard notes.count >= ReviewSetBuilder.minimum else { return [] }

        let hour = ClockTime.hour(minute)
        let past = ClockTime.minute(minute)
        var entries: [Entry] = []

        for offset in 0..<max(0, days) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now),
                  let fires = calendar.date(bySettingHour: hour, minute: past, second: 0, of: day),
                  fires > now,
                  // The whole set, and its first card — not a set of one. The
                  // "at least one book you're reading" rule can pick a different
                  // note when it's the only slot, and a reminder that named a
                  // note the screen doesn't open on would be its own small lie.
                  let note = ReviewSetBuilder.set(from: notes, on: day, calendar: calendar).first
            else { continue }

            entries.append(Entry(
                shortID: note.shortID,
                title: title(for: note),
                body: note.text,
                // Components rather than a date, because a calendar trigger
                // takes components — and because a reminder that survives a
                // timezone change should stay at eight in the morning.
                when: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fires)
            ))
        }

        return entries
    }

    /// `n.11 · Meditations`, or just `n.11` when the note has no book worth
    /// naming. The Inbox is a book on screen and not a source in a reminder.
    private static func title(for note: Note) -> String {
        guard let book = note.book, book.status != .inbox, !book.title.isEmpty else {
            return Glyphs.noteID(note.shortID)
        }
        return "\(Glyphs.noteID(note.shortID)) · \(book.title)"
    }
}
