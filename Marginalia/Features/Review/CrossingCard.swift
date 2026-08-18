import SwiftUI

/// What a crossing card needs to draw itself. Two notes and the distance
/// between them — no edge, no score, no model, like every other row type.
struct CrossingCardData {
    /// The older of the two. A gap reads forward.
    let a: NoteRowData
    let b: NoteRowData
    /// `7 months apart`.
    let gap: String
}

/// Two notes from two books that say the same thing, filling one screen of the
/// daily review.
///
/// **Centred and open like `ReviewCard`, and for the same reason** — the margin
/// belongs to the stream and book detail, where a row is one of many.
///
/// **A hairline between the halves, never an arrow.** `NoteEdge` stores a
/// direction and the app has displayed both ways since phase 6; a `→` here would
/// be the first place it contradicted that.
struct CrossingCard: View {
    let crossing: CrossingCardData
    /// True once the reader has said the pair isn't one. The card stays where it
    /// is and the action becomes a past tense — see `ReviewView.rejected`.
    let rejected: Bool
    let onOpen: (Int) -> Void
    let onReject: () -> Void

    /// How tall the card turned out. A vertical scroll view nested inside the
    /// vertical *paging* scroll view swallows the page gesture, so this one only
    /// scrolls when it has something to scroll to — `ReviewCard` carries the
    /// same guard and the note above it explains what it cost to learn.
    @State private var content: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                card
                    .frame(minHeight: proxy.size.height)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { content = $0 }
            }
            .scrollDisabled(content <= proxy.size.height + 0.5)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(crossing.a.idLabel) · \(crossing.b.idLabel) · \(Glyphs.crossing) crossing")
                .font(Typography.meta)
                .foregroundStyle(Theme.textAsh)

            half(crossing.a)
            Hairline()
            half(crossing.b)

            foot
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }

    /// **`noteBody`, not `reviewBody`.** Every other review card is one note
    /// filling the screen and gets 18pt; this one is two, and at 18pt each the
    /// second half is below the fold before the reader has a reason to look for
    /// it. The gap is the point of the card and both halves have to be on it.
    private func half(_ note: NoteRowData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(note.text)
                .font(Typography.noteBody)
                .lineSpacing(Typography.bodyLeading)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if !note.source.isEmpty {
                Text("— \(note.source)")
                    .font(Typography.source)
                    .foregroundStyle(Theme.textMute)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        // Everything a note can do — star, add a thought — is where the note
        // is. The card doesn't duplicate six actions for two notes; it opens
        // them. `ActionRow`'s own note records that four labels already
        // overflow a phone at 13pt mono.
        .onTapGesture { onOpen(note.id) }
    }

    private var foot: some View {
        HStack(spacing: 20) {
            Text(crossing.gap)
                .font(Typography.source)
                .foregroundStyle(Theme.textMute)

            if rejected {
                Text("disconnected")
                    .font(Typography.source)
                    .foregroundStyle(Theme.textAsh)
            } else {
                // The first feedback loop in the linking system: the app has
                // guessed at meaning since phase 6 and nothing anywhere could
                // tell it it was wrong. An affordance, never a question —
                // skipping it is free, and `docs/decisions.md` §10's promise
                // that nobody is asked to link anything is unbroken.
                MarkerButton(title: "\(Glyphs.close) not related", kind: .link, action: onReject)
            }

            Spacer(minLength: 0)
        }
    }
}
