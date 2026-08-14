import SwiftUI

/// One typeface, three weights, at every size in the app.
///
/// There is no sans face, no display face, and no italic in this system.
/// Swapping to Berkeley Mono later means changing `Face` and dropping the
/// files into `Resources/Fonts` — nothing else.
///
/// Every size is declared `relativeTo:` a text style, so the whole scale moves
/// with the reader's Dynamic Type setting. Never use `.system(size:)`.
enum Typography {

    private enum Face {
        static let regular = "JetBrainsMono-Regular"
        static let medium = "JetBrainsMono-Medium"
        static let bold = "JetBrainsMono-Bold"
    }

    // MARK: Chrome

    /// `marginalia` — stream only.
    static let wordmark = Font.custom(Face.bold, size: 16, relativeTo: .headline)

    /// The single header on every screen that isn't stream.
    static let screenTitle = Font.custom(Face.bold, size: 18, relativeTo: .title3)

    static let tabLabel = Font.custom(Face.regular, size: 13, relativeTo: .caption)
    static let tabLabelActive = Font.custom(Face.bold, size: 13, relativeTo: .caption)

    // MARK: Content

    /// Note bodies in the stream and on book detail.
    static let noteBody = Font.custom(Face.regular, size: 15, relativeTo: .body)

    /// The note on a review card — the only place text gets this much room.
    static let reviewBody = Font.custom(Face.regular, size: 18, relativeTo: .title3)

    static let bookTitle = Font.custom(Face.bold, size: 15, relativeTo: .body)

    /// Source lines and links: book · page · tag.
    static let source = Font.custom(Face.regular, size: 13, relativeTo: .footnote)

    /// Note ids, timestamps, type labels, counts.
    static let meta = Font.custom(Face.regular, size: 13, relativeTo: .footnote)

    // MARK: Controls

    static let input = Font.custom(Face.regular, size: 15, relativeTo: .body)
    static let button = Font.custom(Face.medium, size: 15, relativeTo: .body)

    /// `■ stop`, and the capture sheet's type selector — the two buttons that
    /// have to sit inside a row rather than span it.
    static let buttonSmall = Font.custom(Face.medium, size: 13, relativeTo: .footnote)

    // MARK: Map

    // A node's connection count shows as **weight**, 400 → 500 → 700, never as
    // size. Varying node size would introduce a visual dimension the rest of
    // the app doesn't have.

    static let mapNode = Font.custom(Face.regular, size: 13, relativeTo: .footnote)
    static let mapNodeStrong = Font.custom(Face.medium, size: 13, relativeTo: .footnote)

    /// A note at the top of the weight ladder. The same face as `mapHub` and a
    /// separate name on purpose: a hub is bold because it's a book, and this is
    /// bold because it's well connected. They're never confused on screen —
    /// only a hub is bracketed.
    static let mapNodeHeavy = Font.custom(Face.bold, size: 13, relativeTo: .footnote)

    static let mapHub = Font.custom(Face.bold, size: 13, relativeTo: .footnote)

    // MARK: Line spacing
    //
    // SwiftUI's `lineSpacing` is *extra* leading, not a multiplier, so these are
    // the deltas that land on the design system's ratios at the default size.

    /// 15pt at ~1.6.
    static let bodyLeading: CGFloat = 4

    /// 18pt at ~1.7.
    static let reviewLeading: CGFloat = 7
}
