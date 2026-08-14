import Foundation

/// Hands out the `n.11` ids, from a monotonic counter rather than from
/// `max(shortID) + 1`.
///
/// Ids are **never reused after a delete**. A dangling `→ n.07` pointing at a
/// *different* note is worse than one pointing at nothing, and a counter derived
/// from the store would do exactly that the moment the newest note is deleted.
struct ShortIDCounter {
    private static let key = "note.nextShortID"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The next unused id. Fresh installs start at 1.
    func next() -> Int {
        let id = max(defaults.integer(forKey: Self.key), 1)
        defaults.set(id + 1, forKey: Self.key)
        return id
    }

    /// Raises the counter past an id that already exists, never lowering it.
    ///
    /// The store can outlive its `UserDefaults` — reinstalling over an existing
    /// container, or a restore that carries the database but not the domain.
    /// Seeding and launch both call this with the highest id on hand.
    func reserve(above shortID: Int) {
        if defaults.integer(forKey: Self.key) <= shortID {
            defaults.set(shortID + 1, forKey: Self.key)
        }
    }
}
