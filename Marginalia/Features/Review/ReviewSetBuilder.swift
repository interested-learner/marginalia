import Foundation

/// The day's review set: which notes come back today, and in what order.
///
/// **Pure.** Plain notes and a date in, notes out — no `ModelContext`, no fetch,
/// no clock of its own. That's what makes every rule in it assertable without a
/// container, and it's not negotiable.
///
/// ```
/// score(note) = days since it was last surfaced   (never surfaced ranks highest)
///             + a bonus if it's starred
///             + a little jitter, fixed for the day
///
/// take the highest, subject to:  at most 8 · at most 2 per book
///                                at least 1 from a book being read
/// ```
///
/// **Building a set surfaces nothing.** `lastSurfacedAt` and `surfaceCount` are
/// written only when a card is actually paged past — see `ReviewWriter`. If
/// building the set moved them, opening review twice would change tomorrow.
nonisolated enum ReviewSetBuilder {

    /// A day is a ritual with an end, not another infinite feed.
    static let dailyLimit = 8

    /// Otherwise a day's review is four notes from whatever you read last week.
    static let perBook = 2

    /// Below this, review points at capture instead — a set of two isn't one.
    static let minimum = 3

    /// A note that has never been surfaced is treated as a year unseen: highest
    /// possible score, and the ceiling every other note is measured against.
    private static let neverSurfaced: Double = 365

    /// A star is worth a week of not having been seen. Enough to win between two
    /// notes with the same history, not enough to pin one to the top forever.
    private static let starBonus: Double = 7

    /// Small enough that it never overturns a star or a month of neglect, large
    /// enough that a stable library doesn't read the same set every morning.
    private static let jitterRange: Double = 3

    /// The set for `day`, strongest first.
    ///
    /// `shown` carries the ids already seen — that's `[↻] keep going`, which
    /// extends past the day's eight rather than starting the same set over.
    static func set(
        from notes: [Note],
        on day: Date,
        calendar: Calendar = .current,
        limit: Int = dailyLimit,
        excluding shown: Set<Int> = []
    ) -> [Note] {
        guard limit > 0 else { return [] }

        let seed = daySeed(day, calendar)
        let candidates = notes
            .filter { !shown.contains($0.shortID) }
            .map { (note: $0, score: score($0, on: day, seed: seed)) }
            .sorted(by: strongestFirst)

        var chosen: [(note: Note, score: Double)] = []
        var taken: [ObjectIdentifier?: Int] = [:]

        for candidate in candidates where chosen.count < limit {
            let shelf = candidate.note.book.map(ObjectIdentifier.init)
            guard taken[shelf, default: 0] < perBook else { continue }
            taken[shelf, default: 0] += 1
            chosen.append(candidate)
        }

        // Review is worth opening because it talks about the book in your hand,
        // so one card is spent on it even when nothing from it scored.
        if !chosen.contains(where: { $0.note.book?.status == .reading }),
           let current = candidates.first(where: { $0.note.book?.status == .reading }) {
            // Dropping the weakest can't break either cap, and the note arriving
            // is the first from its book, so it can't break the per-book one.
            if chosen.count >= limit { chosen.removeLast() }
            chosen.append(current)
            chosen.sort(by: strongestFirst)
        }

        return chosen.map(\.note)
    }

    // MARK: Scoring

    private static func score(_ note: Note, on day: Date, seed: UInt64) -> Double {
        var score = daysUnseen(note, on: day)
        if note.isStarred { score += starBonus }
        return score + jitter(seed: seed, shortID: note.shortID)
    }

    private static func daysUnseen(_ note: Note, on day: Date) -> Double {
        guard let last = note.lastSurfacedAt else { return neverSurfaced }
        return min(neverSurfaced, max(0, day.timeIntervalSince(last) / 86_400))
    }

    /// Ties break on the id so the order is fixed rather than however the notes
    /// happened to arrive — a set that reshuffles under the thumb is a bug.
    private static func strongestFirst(
        _ a: (note: Note, score: Double),
        _ b: (note: Note, score: Double)
    ) -> Bool {
        a.score == b.score ? a.note.shortID < b.note.shortID : a.score > b.score
    }

    // MARK: The day's seed

    /// The calendar day, as a number. Same day in, same set out — leaving review
    /// and coming back must not reshuffle it.
    ///
    /// **Internal rather than private**, because `CrossingFinder` rotates the
    /// day's crossing on the same number. Two definitions of "a day" in one
    /// screen would drift the way two write paths would.
    static func daySeed(_ day: Date, _ calendar: Calendar) -> UInt64 {
        let start = calendar.startOfDay(for: day).timeIntervalSince1970
        return UInt64(bitPattern: Int64((start / 86_400).rounded(.down)))
    }

    /// Deterministic in the day and the note, so it's stable within a day and
    /// different across days. `Double.random` would reshuffle on every redraw.
    private static func jitter(seed: UInt64, shortID: Int) -> Double {
        var x = seed &* 0x9E37_79B9_7F4A_7C15
        x = x &+ UInt64(bitPattern: Int64(shortID)) &* 0xBF58_476D_1CE4_E5B9
        x ^= x >> 30
        x = x &* 0xBF58_476D_1CE4_E5B9
        x ^= x >> 27
        x = x &* 0x94D0_49BB_1331_11EB
        x ^= x >> 31
        return Double(x % 1_000_000) / 1_000_000 * jitterRange
    }
}
