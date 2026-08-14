import Foundation

/// Tapped lines → the passage as it was printed. Pure.
///
/// VisionKit recognizes a page a line at a time, and a passage worth keeping is
/// several of them. This is the half of the scanner that has nothing to do with
/// a camera: it takes the strings the controller hands back and puts the prose
/// back together, so the reader corrects meaning rather than layout.
///
/// **Nothing here infers a page number.** A running head or a folio caught in
/// the frame is text like any other and is only in the passage if it was
/// tapped — the page field is typed, always, which is a rule the spec sets and
/// this file is the obvious place to break it.
nonisolated enum ScannedPassage {

    /// Every line, in the order they were tapped.
    static func joined(_ lines: [String]) -> String {
        lines.reduce("") { appending($1, to: $0) }
    }

    /// One more tapped line onto what's collected so far.
    ///
    /// **A word broken at the margin is put back together.** A line of printed
    /// text ending in a hyphen is nearly always a word the typesetter split, so
    /// the hyphen goes and the halves close up. That is wrong for a line whose
    /// last word genuinely ends in one — `well-` / `known` — and there is no
    /// way to tell the two apart without a dictionary. It's the rarer case, and
    /// the passage lands in an editable field either way.
    ///
    /// A hyphen with a space in front of it was typed as punctuation rather
    /// than printed into the margin, and an en or em dash never breaks a word,
    /// so neither closes up.
    static func appending(_ line: String, to passage: String) -> String {
        let piece = normalized(line)
        guard !piece.isEmpty else { return passage }
        guard !passage.isEmpty else { return piece }

        if breaksAWord(passage) {
            return String(passage.dropLast()) + piece
        }
        return passage + " " + piece
    }

    /// Whitespace of every kind — including the line breaks inside a single
    /// recognized item — collapses to one space.
    private static func normalized(_ line: String) -> String {
        line.split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// A trailing hyphen, with a word character in front of it.
    private static func breaksAWord(_ passage: String) -> Bool {
        guard passage.hasSuffix("-") else { return false }
        let before = passage.dropLast().last
        return before.map { $0.isLetter || $0.isNumber } ?? false
    }
}
