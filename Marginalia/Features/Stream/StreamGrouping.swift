import Foundation

/// The stream's date headers: `today · thu aug 13` / `yesterday` / `earlier`.
///
/// Generic over the item so it stays free of SwiftData and can be tested with
/// plain dates. Input order is preserved — the stream is newest-first and
/// grouping is not allowed to resort it.
enum StreamGrouping {

    struct Group<Item>: Identifiable {
        let id: String
        let label: String
        let items: [Item]
    }

    private enum Bucket: Int, CaseIterable {
        case today, yesterday, earlier
    }

    static func groups<Item>(
        _ items: [Item],
        date: (Item) -> Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Group<Item>] {
        var buckets: [Bucket: [Item]] = [:]
        for item in items {
            buckets[bucket(for: date(item), now: now, calendar: calendar), default: []].append(item)
        }

        return Bucket.allCases.compactMap { bucket in
            guard let items = buckets[bucket], !items.isEmpty else { return nil }
            return Group(id: String(bucket.rawValue),
                         label: label(for: bucket, now: now, calendar: calendar),
                         items: items)
        }
    }

    /// Days are calendar days, not elapsed hours — an hour before midnight and
    /// an hour after it are different days however few minutes separate them.
    private static func bucket(for date: Date, now: Date, calendar: Calendar) -> Bucket {
        if calendar.isDate(date, inSameDayAs: now) { return .today }
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return .earlier }
        return calendar.isDate(date, inSameDayAs: yesterday) ? .yesterday : .earlier
    }

    /// Everything older than yesterday shares one header. A feed of one-row
    /// sections is unreadable.
    private static func label(for bucket: Bucket, now: Date, calendar: Calendar) -> String {
        switch bucket {
        case .today: "today · \(RelativeTime.dayLabel(for: now, calendar: calendar))"
        case .yesterday: "yesterday"
        case .earlier: "earlier"
        }
    }
}
