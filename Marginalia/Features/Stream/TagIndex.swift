import Foundation

/// The chips above the stream, derived from the notes rather than hand-listed.
///
/// Ordered by how often a tag is used, so the ones worth filtering by sit where
/// the thumb already is. Ties break alphabetically, which keeps the row from
/// reshuffling every time a note is saved.
enum TagIndex {

    /// The chip that clears the filter. Not a tag, so it never comes back from
    /// `chips(for:)`.
    static let all = "all"

    static func chips(for tagLists: [[String]]) -> [String] {
        var counts: [String: Int] = [:]
        for tags in tagLists {
            // A tag repeated on one note is still one use of it.
            for tag in Set(tags.map(normalized)) where !tag.isEmpty {
                counts[tag, default: 0] += 1
            }
        }
        return counts.keys.sorted {
            counts[$0]! == counts[$1]! ? $0 < $1 : counts[$0]! > counts[$1]!
        }
    }

    /// Tags are stored bare and rendered with the `#`, so a hash typed by the
    /// user must not produce a `##design` chip.
    static func normalized(_ tag: String) -> String {
        var trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while trimmed.hasPrefix("#") { trimmed.removeFirst() }
        return trimmed
    }
}
