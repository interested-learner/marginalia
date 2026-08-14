import Foundation

/// A note being written, before anything reaches the store.
///
/// Everything the user types arrives as a string — the body, the page, the tags
/// — and this is the one place those become the values a `Note` stores. Keeping
/// it a plain value with no SwiftData in it is what makes the rules below
/// testable without a container.
struct CaptureDraft {
    var kind: NoteKind = .thought
    var text: String = ""
    /// Typed. Never inferred from a scan — inferring it would be wrong often
    /// enough to be worse than useless.
    var page: String = ""
    /// One field, space or comma separated. `#` optional.
    var tags: String = ""

    /// A page or a tag on its own is not a note.
    var canSave: Bool { !body.isEmpty }

    /// Trimmed at the ends, untouched inside — a note written over three lines
    /// keeps its three lines.
    var body: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Stored bare and lowercased, in the order they were typed. A tag repeated
    /// in the field is one tag.
    var tagList: [String] {
        var seen: Set<String> = []
        return tags
            .split(whereSeparator: { $0 == "," || $0.isWhitespace })
            .map { TagIndex.normalized(String($0)) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// The field is labelled `p.`, and people type the label back into it.
    /// Anything that isn't a page — blank, zero, negative, prose — is no page,
    /// because `p.0` on a source line reads as a bug and is one.
    var pageNumber: Int? {
        let digits = page.filter(\.isNumber)
        guard !digits.isEmpty, !page.contains("-"), let number = Int(digits), number > 0
        else { return nil }
        return number
    }
}
