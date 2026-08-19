import Foundation

/// Where the reader is in the day's review — which notes, which card, which
/// crossing — across tab switches, relaunches and a night in the background.
///
/// **`docs/decisions.md` §4 has promised this since phase 5**: the day's set is
/// "fixed per calendar day so leaving and returning doesn't reshuffle it." That
/// was implemented as held in `@State`, and `RootView` is a `switch` rather than
/// a `TabView`, so no view lifetime survives leaving the tab. Worse, a rebuild
/// isn't even the same set: `ReviewSetBuilder` scores mostly on `lastSurfacedAt`
/// and paging past a card writes it, so every card actually *read* scores ~0 on
/// the way back and drops out of the eight. The more of the set you read, the
/// less of it returns. The set has to be a stored fact, not a re-derivation.
///
/// `UserDefaults` rather than SwiftData, for the reason `Preferences` gives:
/// none of this is a note, and none of it should sync to another device as
/// content. Where you are in today's cards is a fact about this phone.
///
/// A `struct` with injected defaults, like `ShortIDCounter` — that is what makes
/// the day comparison testable, and the day comparison is the only thing
/// standing between the reader and yesterday's cards forever.
struct ReviewSession {

    enum Key {
        static let day = "review.day"
        static let set = "review.set"
        static let position = "review.position"
        static let crossing = "review.crossing"
    }

    /// A stored session that belongs to today. Ids rather than notes: this type
    /// never touches the store, and `rehydrate` is where they become notes again.
    struct Resumed: Equatable {
        /// Short ids in the order they were shown, `keep going`'s extension and all.
        let set: [Int]
        let position: Int
        /// The crossing's pair, or `nil` on a library that had none.
        let crossing: Pair?
    }

    /// The crossing's two notes. Unordered in meaning — `NoteEdge` stores a
    /// direction and the app has never displayed one — so it is stored low id
    /// first and compared that way.
    struct Pair: Equatable {
        let a: Int
        let b: Int

        init(_ a: Int, _ b: Int) {
            self.a = min(a, b)
            self.b = max(a, b)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: Reading

    /// Today's session, or `nil` when nothing is stored or what is stored
    /// belongs to another day. A new day builds a new set, which is the whole
    /// boundary §4 is about.
    func resume(on day: Date, calendar: Calendar = .current) -> Resumed? {
        guard let stored = storedDay, stored == Self.seed(day, calendar) else { return nil }

        let set = defaults.array(forKey: Key.set) as? [Int] ?? []
        guard !set.isEmpty else { return nil }

        return Resumed(
            set: set,
            position: defaults.integer(forKey: Key.position),
            crossing: storedPair
        )
    }

    /// Whether a set is stored **and** it belongs to an earlier day — the
    /// midnight rollover's cue.
    ///
    /// Deliberately not `resume(on:) == nil`, which is also true on a fresh
    /// install. Rolling the day over there would rebuild a set nobody had yet.
    func isStale(on day: Date, calendar: Calendar = .current) -> Bool {
        guard let stored = storedDay else { return false }
        return stored != Self.seed(day, calendar)
    }

    // MARK: Writing

    /// The whole session, every time. Four keys written together can't disagree
    /// about which day they belong to.
    func record(set: [Int], position: Int, crossing: Pair?,
                on day: Date, calendar: Calendar = .current) {
        defaults.set(Self.seed(day, calendar), forKey: Key.day)
        defaults.set(set, forKey: Key.set)
        defaults.set(position, forKey: Key.position)
        if let crossing {
            defaults.set([crossing.a, crossing.b], forKey: Key.crossing)
        } else {
            defaults.removeObject(forKey: Key.crossing)
        }
    }

    /// Backdates the stored day, so the next launch reads as a new one.
    /// `-reviewYesterday 1` and nothing else — `simctl` can't move the clock,
    /// and the rollover is otherwise unreachable from the command line.
    func backdate() {
        guard let stored = storedDay else { return }
        defaults.set(stored - 1, forKey: Key.day)
    }

    // MARK: Ids back into notes

    /// The stored ids as the notes that still exist, in the order they were
    /// shown — or **nothing**, when too few of them survive to be a day's review.
    ///
    /// Pure, and static for that reason: the shrink rule is policy worth
    /// asserting, and a set that lost notes to a delete between visits would
    /// otherwise draw review's "not enough notes yet" over a full library.
    static func rehydrate(_ ids: [Int], from library: [Note]) -> [Note] {
        var byID: [Int: Note] = [:]
        for note in library where byID[note.shortID] == nil {
            byID[note.shortID] = note
        }

        let kept = ids.compactMap { byID[$0] }
        return kept.count < ReviewSetBuilder.minimum ? [] : kept
    }

    // MARK: The day

    /// `ReviewSetBuilder.daySeed` and nothing else. It is internal rather than
    /// private precisely so the app has one definition of a day — a second one
    /// here would drift the way two write paths would.
    private static func seed(_ day: Date, _ calendar: Calendar) -> Int {
        Int(bitPattern: UInt(ReviewSetBuilder.daySeed(day, calendar)))
    }

    /// `nil` rather than 0 when the key was never written — day zero is a real
    /// day, so `integer(forKey:)`'s 0-for-missing can't be read as "no session".
    private var storedDay: Int? {
        defaults.object(forKey: Key.day) as? Int
    }

    private var storedPair: Pair? {
        guard let pair = defaults.array(forKey: Key.crossing) as? [Int], pair.count == 2
        else { return nil }
        return Pair(pair[0], pair[1])
    }
}
