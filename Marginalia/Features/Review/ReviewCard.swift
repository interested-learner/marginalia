import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers

/// One note, filling the screen.
///
/// **Centered and open — deliberately not using the margin.** The margin belongs
/// to the stream and book detail, where a row is one of many; here the note is
/// the whole screen and there's nothing beside it to annotate.
struct ReviewCard: View {
    let note: NoteRowData
    let actions: ReviewActions

    /// How tall the card actually turned out. A vertical scroll view nested
    /// inside the vertical *paging* scroll view swallows the page gesture, so
    /// this one is only allowed to scroll when it has something to scroll to.
    @State private var content: CGFloat = 0

    var body: some View {
        // Centered vertically, which `Spacer` can't do inside a scroll view —
        // the content sizes to itself there and the spacers collapse. The card
        // scrolls only once a long note plus its thread outgrows the screen.
        GeometryReader { proxy in
            ScrollView {
                card
                    .frame(minHeight: proxy.size.height)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { content = $0 }
            }
            // **The one that ate the swipe.** `scrollBounceBehavior` stops the
            // rubber band; it does not stop the scroll. A card that fits still
            // consumed a drag the pager should have had, and the closing card —
            // which has no inner scroll view at all — behaved differently from
            // every card before it, which is what made the end of the set feel
            // stuck rather than finished.
            .scrollDisabled(content <= proxy.size.height + 0.5)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(note.idLabel) · \(note.meta)")
                .font(Typography.meta)
                .foregroundStyle(Theme.textAsh)

            // No quote marks on a passage here either — see `QuoteRule`. The
            // card doesn't draw the rule (it's centred and open, with nothing
            // beside it to rule against), so a quote is marked by `quote` in the
            // metadata line above and by `— book · page` below it.
            Text(note.text)
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
}

/// What a card can do. Passed in rather than reached for, so `ReviewCard` stays
/// a view over `NoteRowData` and never sees the store.
struct ReviewActions {
    let addThought: () -> Void
    let toggleStar: () -> Void
    /// `nil` when the note somehow has no book — the action hides rather than
    /// sitting there doing nothing.
    let openBook: (() -> Void)?
    /// **What to share, not the sharing of it.** This used to be
    /// `() -> Image?`, called from `ShareCardLink.body` — so every visible card
    /// rendered a 420pt bitmap at 3x on every body pass, synchronously, inside
    /// SwiftUI's own render pass. Now the card hands over the *description* of
    /// the image and nothing draws until the reader taps `share`.
    let shareCard: () -> ShareableCard
    /// Connect this note to another by hand. The one thing in the app that
    /// writes `isPinned`, and the only place the reader ever *makes* a link —
    /// everything else on the graph is the app's own work.
    let link: () -> Void
}

/// `[+] add a thought` · `[ ] star` · `→ open book` · `share` · `→ link`.
///
/// **Rows of two, never a row of four.** At 13pt mono four labels are about
/// 320pt of text before gaps, which overflows a phone at the default text size
/// and is hopeless above it — the same reason the capture sheet's type selector
/// offers three segments rather than four. Five actions is still three rows —
/// `→ link` gets a row of its own rather than crowding a third label beside
/// `→ open book` and `share`.
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
                ShareCardLink(note: note, card: actions.shareCard)
                Spacer(minLength: 0)
            }

            HStack(spacing: 20) {
                MarkerButton(title: "\(Glyphs.forward) link", kind: .link, action: actions.link)
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
    let card: () -> ShareableCard

    var body: some View {
        // `ShareLink` asks its item for bytes when the share sheet opens, so
        // the render happens on a tap rather than on a redraw. The preview is
        // the note's id — a text preview costs nothing, and an image preview
        // would put the whole bitmap back in `body` by another door.
        ShareLink(item: card(), preview: SharePreview(note.idLabel)) {
            Text("share")
                .font(Typography.source)
                .foregroundStyle(Theme.textMute)
                .underline(pattern: .solid)
                .padding(.vertical, 4)
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

/// One note, ready to leave the app — and **not yet drawn**.
///
/// The renderer is the most expensive thing on the review screen: a 420pt card
/// at 3x is several megabytes of bitmap, and it used to be built inside
/// `body`, for every card the paging scroll had realized, on every redraw.
/// That is a nested SwiftUI render pass inside a render pass, at a memory rate
/// a phone will eventually answer by killing the app.
///
/// A `Transferable` is the shape of the fix rather than a workaround for it:
/// `ShareLink` holds this value and asks it for bytes only when the share sheet
/// actually opens. Nothing renders until somebody shares.
struct ShareableCard: Transferable {
    let note: NoteRowData
    /// The appearance the reader is actually looking at — sharing a white card
    /// out of a dark app would be a surprise.
    let scheme: ColorScheme

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { card in
            await card.png() ?? Data()
        }
        .suggestedFileName { "\($0.note.idLabel).png" }
    }

    @MainActor
    private func png() -> Data? {
        let renderer = ImageRenderer(
            content: ShareCard(note: note).environment(\.colorScheme, scheme)
        )
        renderer.scale = ShareCard.scale
        return renderer.uiImage?.pngData()
    }
}
