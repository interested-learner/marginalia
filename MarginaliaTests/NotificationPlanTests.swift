import Foundation
import Testing
@testable import Marginalia

/// One reminder a day, seven ahead, each carrying a real note.
///
/// Pure, and separate from the scheduler for exactly this reason:
/// `UNUserNotificationCenter` can't be asked in a test what tomorrow's reminder
/// will say.
@MainActor
struct NotificationPlanTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    /// 2025-10-09, 06:00 UTC — earlier than every reminder these tests set, so
    /// "today still counts" is the default and a missed time is the exception.
    private var morning: Date { Date(timeIntervalSince1970: 1_759_989_600) }

    private func library(_ count: Int, book: Book? = nil) -> [Note] {
        (0..<count).map { Note(shortID: $0 + 1, text: "note \($0 + 1)", book: book) }
    }

    private func entries(
        _ notes: [Note],
        minute: Int = Preferences.defaultMinute,
        from now: Date? = nil,
        days: Int = NotificationPlan.days
    ) -> [NotificationPlan.Entry] {
        NotificationPlan.entries(for: notes, minute: minute, from: now ?? morning,
                                 calendar: calendar, days: days)
    }

    // MARK: How many, and when

    @Test func sevenAreQueued() {
        #expect(entries(library(20)).count == NotificationPlan.days)
    }

    @Test func eachFiresAtTheChosenTimeOnConsecutiveDays() {
        let plan = entries(library(20), minute: 21 * 60 + 30)
        #expect(plan.allSatisfy { $0.when.hour == 21 && $0.when.minute == 30 })

        let days = plan.compactMap(\.when.day)
        #expect(days == Array(days.first!..<(days.first! + NotificationPlan.days)))
    }

    /// A reminder set for 8am at nine in the morning starts tomorrow. Scheduling
    /// a time that has already passed would either fire at once or be dropped by
    /// iOS, and both are worse than waiting a day.
    @Test func aTimeAlreadyPastTodayStartsTomorrow() {
        let notes = library(20)
        let onTime = entries(notes, minute: 8 * 60)
        let late = entries(notes, minute: 8 * 60, from: morning.addingTimeInterval(6 * 3_600))

        #expect(onTime.first?.when.day != late.first?.when.day)
        #expect(late.count == NotificationPlan.days - 1)
    }

    // MARK: What it says

    /// The reminder names the first card of that day's set, so the alert and the
    /// screen it opens agree.
    @Test func eachReminderCarriesThatDaysFirstCard() {
        let notes = library(20)
        for entry in entries(notes) {
            let day = calendar.date(from: entry.when)!
            let card = ReviewSetBuilder.set(from: notes, on: day, calendar: calendar).first
            #expect(entry.shortID == card?.shortID)
        }
    }

    /// Readable from the lock screen without opening the app — often that's the
    /// whole interaction.
    @Test func theBodyIsTheNotesOwnText() {
        let notes = library(20)
        let written = Dictionary(uniqueKeysWithValues: notes.map { ($0.shortID, $0.text) })
        let plan = entries(notes)

        #expect(!plan.isEmpty)
        #expect(plan.allSatisfy { $0.body == written[$0.shortID] })
    }

    @Test func theTitleNamesTheNoteAndItsBook() {
        let plan = entries(library(20, book: Book(title: "Meditations", status: .reading)))
        #expect(plan.allSatisfy { $0.title.hasSuffix(" · Meditations") })
        #expect(plan.allSatisfy { $0.title.hasPrefix("n.") })
    }

    /// The Inbox is a book on screen and not a source worth naming in an alert.
    @Test func theInboxIsNotNamedAsASource() {
        let plan = entries(library(20, book: Book(title: Inbox.title, status: .inbox)))
        #expect(plan.allSatisfy { !$0.title.contains(Inbox.title) })
    }

    // MARK: Nothing to say

    /// Under `ReviewSetBuilder.minimum` there is no review to open, so there is
    /// nothing to be reminded about either.
    @Test func aLibraryTooSmallToReviewQueuesNothing() {
        #expect(entries(library(ReviewSetBuilder.minimum - 1)).isEmpty)
        #expect(entries(library(ReviewSetBuilder.minimum)).isEmpty == false)
    }

    @Test func anEmptyLibraryQueuesNothing() {
        #expect(entries([]).isEmpty)
    }

    @Test func askingForNoDaysQueuesNothing() {
        #expect(entries(library(20), days: 0).isEmpty)
    }
}
