import Foundation

/// The ASCII vocabulary. There are no icons in this app and no SF Symbols.
///
/// Never write one of these literals in a view — go through this enum, so the
/// vocabulary stays countable and a change lands everywhere at once.
nonisolated enum Glyphs {

    // MARK: Book status

    static let reading = "[+]"
    static let finished = "[x]"
    static let queued = "[-]"
    static let inbox = "[~]"

    // MARK: Tabs

    static let tabStream = "[~]"
    static let tabBooks = "[=]"
    static let tabMap = "[◇]"
    static let tabReview = "[↻]"

    // MARK: Note kinds

    static let quote = "[q]"
    static let thought = "[t]"
    static let voice = "[v]"
    static let scan = "[s]"

    // MARK: Actions

    static let add = "[+]"
    static let record = "[●]"      // the dot is `danger`, the brackets are `ink`
    /// The bare recording dot, beside the elapsed timer. `danger`, and the only
    /// place in the app besides `record` that it appears.
    static let dot = "●"
    static let stop = "■"
    static let close = "[x]"
    /// A field that opens a list of choices. Terminal furniture, like `■`.
    static let disclosure = "▼"
    static let refresh = "[↻]"     // also transcribing, also shuffle
    /// Bracket-plus-character, like every other marker. `★`/`✎` would be
    /// dingbats — they read as icons, which this system doesn't have.
    static let starred = "[*]"
    static let star = "[ ]"
    static let followUp = "[+]"

    // MARK: Navigation

    static let forward = "→"
    static let back = "←"
    static let up = "↑"

    // MARK: Meters

    static let barFilled = "█"
    static let barEmpty = "░"
    static let waveBars = Array("▁▂▃▄▅▆▇")

    /// The recording waveform, e.g. `▃▆▁▄▇▂…`.
    static func wave(_ levels: [Int]) -> String {
        String(levels.map { waveBars[min(max($0, 0), waveBars.count - 1)] })
    }

    /// `[███░░░░░░░]` — ten cells, always bracketed.
    static func progress(_ fraction: Double, cells: Int = 10) -> String {
        let filled = max(0, min(cells, Int((fraction * Double(cells)).rounded())))
        return "[" + String(repeating: barFilled, count: filled)
             + String(repeating: barEmpty, count: cells - filled) + "]"
    }

    /// `n.05` — ids are zero-padded to two digits and never reused after a delete.
    static func noteID(_ shortID: Int) -> String {
        "n." + String(format: "%02d", shortID)
    }

    /// `[4]` — note counts and library counts are bracketed.
    static func count(_ n: Int) -> String { "[\(n)]" }

    /// `[Meditations]` — a book as a hub node on the map.
    ///
    /// **The first word, not the title.** The design system draws the hub as
    /// `[Meditations]`, which is the whole of that book's title and none of
    /// `Zen and the Art of Motorcycle Maintenance` — forty characters of bold
    /// mono would sit across half the graph and cover the notes it's meant to
    /// be gathering. A leading article is dropped because `[The]` names
    /// nothing, and a single very long word is cut rather than allowed to
    /// sprawl. The panel at the foot carries the full title when a hub is
    /// selected.
    static func bookHub(_ title: String, limit: Int = 12) -> String {
        let words = title.split(whereSeparator: \.isWhitespace)
        let articles: Set<String> = ["the", "a", "an"]
        let first = words.first.map(String.init) ?? ""
        let word = words.count > 1 && articles.contains(first.lowercased())
            ? String(words[1])
            : first

        let trimmed = word.trimmingCharacters(in: .punctuationCharacters)
        let name = trimmed.isEmpty ? word : trimmed
        guard name.count > limit else { return "[\(name)]" }
        return "[\(name.prefix(limit))…]"
    }

    /// `#systems` — tags are stored bare and wear the hash only on screen.
    static func tag(_ name: String) -> String { "#\(name)" }
}
