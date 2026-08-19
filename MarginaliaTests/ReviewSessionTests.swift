import Testing
import Foundation
@testable import Marginalia

/// Where the reader is in the day's review, kept across tab switches, launches
/// and a night in the background.
///
/// `docs/decisions.md` §4 has promised since phase 5 that the day's set is
/// "fixed per calendar day so leaving and returning doesn't reshuffle it." It
/// was held in `@State`, and no view lifetime survives leaving the tab.
@MainActor
struct ReviewSessionTests {

    // MARK: Fixtures

    /// Each test gets its own suite so nothing leaks between them or into the
    /// app — the same device `ShortIDCounterTests` uses.
    private func scratch() -> UserDefaults {
        let name = "marginalia.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func day(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: 1_760_000_000 + Double(offset) * 86_400)
    }

    private func note(_ id: Int) -> Note {
        Note(shortID: id, text: "note \(id)")
    }

    // MARK: Coming back to the same day

    @Test func aRecordedSessionComesBackWhole() {
        let session = ReviewSession(defaults: scratch())
        session.record(set: [4, 9, 1], position: 2,
                       crossing: ReviewSession.Pair(7, 3),
                       on: day(0), calendar: calendar)

        let resumed = session.resume(on: day(0), calendar: calendar)

        #expect(resumed?.set == [4, 9, 1])
        #expect(resumed?.position == 2)
        #expect(resumed?.crossing == ReviewSession.Pair(3, 7))
    }

    /// The order is the order the cards were shown in, not sorted — `keep going`
    /// appends to it.
    @Test func theOrderOfTheSetIsKept() {
        let session = ReviewSession(defaults: scratch())
        session.record(set: [9, 1, 4], position: 0, crossing: nil,
                       on: day(0), calendar: calendar)

        #expect(session.resume(on: day(0), calendar: calendar)?.set == [9, 1, 4])
    }

    @Test func aLibraryWithNoCrossingStoresNone() {
        let session = ReviewSession(defaults: scratch())
        session.record(set: [1, 2, 3], position: 0, crossing: nil,
                       on: day(0), calendar: calendar)

        #expect(session.resume(on: day(0), calendar: calendar)?.crossing == nil)
    }

    /// A pair is unordered — `NoteEdge` stores a direction and the app has never
    /// displayed one, so the crossing must not depend on which end was written.
    @Test func aCrossingPairIsUnordered() {
        #expect(ReviewSession.Pair(7, 3) == ReviewSession.Pair(3, 7))
    }

    @Test func recordingAgainReplacesRatherThanAccumulates() {
        let session = ReviewSession(defaults: scratch())
        session.record(set: [1, 2, 3], position: 1, crossing: ReviewSession.Pair(5, 6),
                       on: day(0), calendar: calendar)
        session.record(set: [4, 5], position: 0, crossing: nil,
                       on: day(0), calendar: calendar)

        let resumed = session.resume(on: day(0), calendar: calendar)
        #expect(resumed?.set == [4, 5])
        #expect(resumed?.position == 0)
        #expect(resumed?.crossing == nil)
    }

    @Test func afreshInstallHasNothingToResume() {
        let session = ReviewSession(defaults: scratch())
        #expect(session.resume(on: day(0), calendar: calendar) == nil)
    }

    // MARK: The day boundary

    /// **The load-bearing one.** Before this type existed, review rebuilt on
    /// every arrival, so a new day was free. Now this comparison is the only
    /// thing standing between the reader and yesterday's cards forever.
    @Test func adifferentDayResumesNothing() {
        let session = ReviewSession(defaults: scratch())
        session.record(set: [1, 2, 3], position: 2, crossing: nil,
                       on: day(0), calendar: calendar)

        #expect(session.resume(on: day(1), calendar: calendar) == nil)
    }

    @Test func thesameDayResumesWhateverTheHour() {
        let session = ReviewSession(defaults: scratch())
        session.record(set: [1, 2, 3], position: 2, crossing: nil,
                       on: day(0), calendar: calendar)

        let laterThatDay = day(0).addingTimeInterval(6 * 3_600)
        #expect(session.resume(on: laterThatDay, calendar: calendar) != nil)
    }

    // MARK: Midnight, for an app that was left open

    /// Not `resume() == nil`, which is also true on a fresh install. Rolling the
    /// day over there would rebuild a set nobody had yet.
    @Test func afreshInstallIsNotStale() {
        let session = ReviewSession(defaults: scratch())
        #expect(session.isStale(on: day(0), calendar: calendar) == false)
    }

    @Test func thesameDayIsNotStale() {
        let session = ReviewSession(defaults: scratch())
        session.record(set: [1, 2, 3], position: 0, crossing: nil,
                       on: day(0), calendar: calendar)

        #expect(session.isStale(on: day(0), calendar: calendar) == false)
    }

    @Test func thenextDayIsStale() {
        let session = ReviewSession(defaults: scratch())
        session.record(set: [1, 2, 3], position: 0, crossing: nil,
                       on: day(0), calendar: calendar)

        #expect(session.isStale(on: day(1), calendar: calendar))
    }

    /// `-reviewYesterday 1`, which is the only way to reach the rollover from
    /// the command line — `simctl` cannot move the clock.
    @Test func backdatingMakesTodaysSessionStale() {
        let session = ReviewSession(defaults: scratch())
        session.record(set: [1, 2, 3], position: 0, crossing: nil,
                       on: day(0), calendar: calendar)
        session.backdate()

        #expect(session.isStale(on: day(0), calendar: calendar))
        #expect(session.resume(on: day(0), calendar: calendar) == nil)
    }

    @Test func backdatingAfreshInstallDoesNothing() {
        let session = ReviewSession(defaults: scratch())
        session.backdate()

        #expect(session.isStale(on: day(0), calendar: calendar) == false)
    }

    // MARK: Ids back into notes

    @Test func rehydrateReturnsTheNotesInTheOrderTheyWereShown() {
        let library = [note(1), note(2), note(3), note(4)]

        let kept = ReviewSession.rehydrate([4, 1, 3], from: library)

        #expect(kept.map(\.shortID) == [4, 1, 3])
    }

    /// A note deleted between visits. The rest of the set is still the set.
    @Test func rehydrateSkipsAnIDThatNoLongerExists() {
        let library = [note(1), note(2), note(3), note(4)]

        let kept = ReviewSession.rehydrate([1, 99, 2, 3], from: library)

        #expect(kept.map(\.shortID) == [1, 2, 3])
    }

    /// **Below the minimum the whole session is discarded**, so `ReviewView`
    /// builds fresh. Restoring two notes would draw review's "not enough notes
    /// to review yet" over a library of forty.
    @Test func rehydrateGivesUpWhenTooFewSurvive() {
        let library = [note(1), note(2)]

        let kept = ReviewSession.rehydrate([1, 2, 97, 98, 99], from: library)

        #expect(kept.isEmpty)
    }

    @Test func rehydrateKeepsAsetExactlyAtTheMinimum() {
        let library = [note(1), note(2), note(3)]

        let kept = ReviewSession.rehydrate([1, 2, 3], from: library)

        #expect(kept.count == ReviewSetBuilder.minimum)
    }
}
