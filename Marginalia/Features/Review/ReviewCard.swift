import SwiftUI

/// One note, filling the screen.
///
/// **Centered and open — deliberately not using the margin.** The margin belongs
/// to the stream and book detail, where a row is one of many; here the note is
/// the whole screen and there's nothing beside it to annotate.
struct ReviewCard: View {
    let note: NoteRowData
    let actions: ReviewActions

    var body: some View {
        // Centered vertically, which `Spacer` can't do inside a scroll view —
        // the content sizes to itself there and the spacers collapse. The card
        // scrolls only once a long note plus its thread outgrows the screen.
        GeometryReader { proxy in
            ScrollView {
                card.frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(note.idLabel) · \(note.meta)")
                .font(Typography.meta)
                .foregroundStyle(Theme.textAsh)

            Text(note.isQuote ? "\u{201C}\(note.text)\u{201D}" : note.text)
                .font(Typography.reviewBody)
                .lineSpacing(Typography.reviewLeading)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if !note.source.isEmpty {
                Text("— \(note.source)")
                    .font(Typography.source)
                    .foregroundStyle(Theme.textMute)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !note.links.isEmpty {
                Text(connections)
                    .font(Typography.source)
                    .foregroundStyle(Theme.textMute)
                    .tint(Theme.textMute)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // The thread the card's own `[+] add a thought` writes into. A
            // note that has been answered shows the answer here too, or the
            // action would appear to do nothing.
            if !note.followUps.isEmpty {
                ThreadRule(followUps: note.followUps)
            }

            ActionRow(note: note, actions: actions)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }

    /// `→ n.09 · → n.11`, the same non-breaking, in-palette links the stream
    /// draws. Backlinks included — edges store a direction, both ends show it.
    private var connections: AttributedString {
        var line = AttributedString()
        for (position, shortID) in note.links.enumerated() {
            if position > 0 { line += AttributedString(" · ") }
            var part = AttributedString("\(Glyphs.forward)\u{00A0}\(Glyphs.noteID(shortID))")
            part.underlineStyle = .single
            part.link = NoteLink.url(for: shortID)
            line += part
        }
        return line
    }
}

/// What a card can do. Passed in rather than reached for, so `ReviewCard` stays
/// a view over `NoteRowData` and never sees the store.
struct ReviewActions {
    let addThought: () -> Void
    let toggleStar: () -> Void
    /// `nil` when the note somehow has no book — the action hides rather than
    /// sitting there doing nothing.
    let openBook: (() -> Void)?
    let shareCard: () -> Image?
}

/// `[+] add a thought` · `[ ] star` · `→ open book` · `share`.
///
/// **Two rows of two, not one row of four.** At 13pt mono the four labels are
/// about 320pt of text before gaps, which overflows a phone at the default text
/// size and is hopeless above it — the same reason the capture sheet's type
/// selector offers three segments rather than four.
private struct ActionRow: View {
    let note: NoteRowData
    let actions: ReviewActions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 20) {
                MarkerButton(title: "\(Glyphs.followUp) add a thought", kind: .link,
                             action: actions.addThought)
                MarkerButton(title: star, kind: .link, action: actions.toggleStar)
                Spacer(minLength: 0)
            }

            HStack(spacing: 20) {
                if let openBook = actions.openBook {
                    MarkerButton(title: "\(Glyphs.forward) open book", kind: .link,
                                 action: openBook)
                }
                ShareCardLink(note: note, image: actions.shareCard)
                Spacer(minLength: 0)
            }
        }
    }

    /// A starred note fills its star. There is no other state change — no
    /// count, no color, no animation.
    private var star: String {
        note.isStarred ? "\(Glyphs.starred) starred" : "\(Glyphs.star) star"
    }
}

/// `share`, drawn as a link button like `edit` on book detail.
///
/// Bare rather than glyphed: every marker in this app is bracket-plus-character
/// and there is no bracketed character that means "share" without becoming a
/// picture.
private struct ShareCardLink: View {
    let note: NoteRowData
    let image: () -> Image?

    var body: some View {
        if let rendered = image() {
            ShareLink(item: rendered,
                      preview: SharePreview(note.idLabel, image: rendered)) {
                Text("share")
                    .font(Typography.source)
                    .foregroundStyle(Theme.textMute)
                    .underline(pattern: .solid)
                    .padding(.vertical, 4)
            }
        }
    }
}

// MARK: The share card

/// What leaves the app: one note, the way the app draws it, plus the wordmark.
///
/// Rendered by `ImageRenderer` at 3× — a fixed 420pt wide rather than the
/// screen's width, so the image is the same whatever phone it came from.
struct ShareCard: View {
    let note: NoteRowData

    static let width: CGFloat = 420
    static let scale: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(note.idLabel)
                .font(Typography.meta)
                .foregroundStyle(Theme.textAsh)

            if note.isQuote {
                QuoteRule(text: note.text)
            } else {
                Text(note.text)
                    .font(Typography.reviewBody)
                    .lineSpacing(Typography.reviewLeading)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !note.source.isEmpty {
                Text("— \(note.source)")
                    .font(Typography.source)
                    .foregroundStyle(Theme.textMute)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Hairline()

            Text("marginalia")
                .font(Typography.wordmark)
                .foregroundStyle(Theme.ink)
        }
        .padding(32)
        .frame(width: Self.width, alignment: .leading)
        .background(Theme.canvas)
    }
}

extension ShareCard {

    /// The card as an image, in the appearance the reader is actually looking
    /// at — sharing a white card out of a dark app would be a surprise.
    @MainActor
    static func rendered(_ note: NoteRowData, in scheme: ColorScheme) -> Image? {
        let renderer = ImageRenderer(content: ShareCard(note: note).environment(\.colorScheme, scheme))
        renderer.scale = scale
        guard let image = renderer.uiImage else { return nil }
        return Image(uiImage: image)
    }
}
