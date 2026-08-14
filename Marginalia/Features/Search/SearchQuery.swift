import Foundation

/// What was typed into the search field, taken apart.
///
/// **Pure**, like `CaptureDraft` and `TypedPage` and for the same reason: what
/// counts as a tag, what counts as a word, and what an empty query means are all
/// rules worth asserting without a store.
///
/// `#tag` in the query filters by tag rather than searching for the text `#tag`
/// — that's the one piece of syntax the field has, and the spec asks for it.
/// Everything else is a word.
nonisolated struct SearchQuery: Equatable {

    /// Words, lowercased. Every one has to appear somewhere in a note for it to
    /// match — typing a second word narrows rather than widens, which is what
    /// anybody typing a second word means by it.
    let terms: [String]

    /// Tags, bare and normalized through `TagIndex` so `#Attention`, `attention`
    /// and `##attention` are the same filter. Every one has to be on the note.
    let tags: [String]

    /// Nothing to search for. A field holding only `#` or only spaces is empty,
    /// because neither says anything about which notes are wanted.
    var isEmpty: Bool { terms.isEmpty && tags.isEmpty }

    init(_ raw: String) {
        var terms: [String] = []
        var tags: [String] = []

        for token in raw.split(whereSeparator: \.isWhitespace) {
            if token.hasPrefix("#") {
                let tag = TagIndex.normalized(String(token))
                // A bare `#` is somebody halfway through typing a tag, not a
                // filter that matches nothing.
                if !tag.isEmpty, !tags.contains(tag) { tags.append(tag) }
            } else {
                let term = token.lowercased()
                if !terms.contains(term) { terms.append(term) }
            }
        }

        self.terms = terms
        self.tags = tags
    }
}
