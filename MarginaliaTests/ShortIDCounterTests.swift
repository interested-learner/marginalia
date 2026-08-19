import Testing
import Foundation
@testable import Marginalia

/// Ids are never reused after a delete: a dangling `[[n.07]]` in an exported
/// document, pointing at a *different* note, is worse than one pointing at
/// nothing.
struct ShortIDCounterTests {

    /// Each test gets its own suite so nothing leaks between them or into the app.
    private func scratch() -> UserDefaults {
        let name = "marginalia.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func firstIDOnAFreshInstallIsOne() {
        let counter = ShortIDCounter(defaults: scratch())
        #expect(counter.next() == 1)
    }

    @Test func idsIncreaseByOne() {
        let counter = ShortIDCounter(defaults: scratch())
        let issued: [Int] = [counter.next(), counter.next(), counter.next()]
        #expect(issued == [1, 2, 3])
    }

    /// The whole reason the counter exists rather than `max(shortID) + 1`.
    @Test func deletingTheNewestNoteDoesNotFreeItsID() {
        let defaults = scratch()
        let counter = ShortIDCounter(defaults: defaults)
        _ = counter.next()
        _ = counter.next()
        _ = counter.next()
        // n.03 is deleted; the store's highest id is now 2. Ask again anyway.
        #expect(counter.next() == 4)
    }

    /// Defends against a store that outlives its `UserDefaults` — reinstalling
    /// over an existing container must not hand out ids that already exist.
    @Test func reserveRaisesTheCounterAboveAnExistingID() {
        let counter = ShortIDCounter(defaults: scratch())
        counter.reserve(above: 40)
        #expect(counter.next() == 41)
    }

    @Test func reserveNeverLowersTheCounter() {
        let counter = ShortIDCounter(defaults: scratch())
        counter.reserve(above: 40)
        counter.reserve(above: 5)
        #expect(counter.next() == 41)
    }

    @Test func aSecondCounterOverTheSameDefaultsContinuesTheSequence() {
        let defaults = scratch()
        _ = ShortIDCounter(defaults: defaults).next()
        #expect(ShortIDCounter(defaults: defaults).next() == 2)
    }
}
