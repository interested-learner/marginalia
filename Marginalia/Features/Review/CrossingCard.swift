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
/// be the first place it contradicted that. It is a `LabeledRule` rather than a
/// bare one — see the seam below for why a plain divider was saying the wrong
/// thing — and a label is not a direction.
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
            head

            half(crossing.a)
            // **The seam carries the claim.** A bare `Hairline` here is the
            // same rule the app uses everywhere else to mean *these are
            // separate items*, which is the opposite of what this card says.
            // `29 days apart` is the fact that lands (`docs/decisions.md` §21)
            // and it used to sit in the foot, below both notes, reading as
            // chrome — so it moved to the one place the reader has to cross.
            LabeledRule(label: crossing.gap)
            half(crossing.b)

            foot
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }

    /// `[◇] crossing` over the sentence that says who is claiming it.
    ///
    /// **The two ids came out.** They said nothing a reader could use — the
    /// same reason `→ n.11` came off every row — and the two books are
    /// already named in the halves' own source lines.
    ///
    /// **The sentence names the app, not the idea.** `docs/decisions.md` §21 is
    /// exact that the three things carrying this card are facts and none of
    /// them is a claim the model makes; *the same idea* would have been one,
    /// on scores `docs/issues.md` §14 says nobody has ever verified. That the
    /// app drew a line is a fact, and it is also the thing `[x] not related`
    /// operates on: a reader can contradict the app, not an idea.
    private var head: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(Glyphs.crossing) crossing")
                .font(Typography.meta)
                .foregroundStyle(Theme.textAsh)

            Text("the app connected these two notes")
                .font(Typography.source)
                .foregroundStyle(Theme.textMute)
                .fixedSize(horizontal: false, vertical: true)
        }
        // **The head is a signpost, so it stops growing** — the fifth and last
        // place in the app that does, beside the tab bar, `ScreenHeader`,
        // review's foot and the capture bar's two markers.
        //
        // Uncapped it cost four lines at `accessibility-extra-extra-extra-large`
        // and pushed the seam — the whole point of the card — off the bottom of
        // the screen, so the card explained itself at the price of not showing
        // the thing it was explaining. `docs/design-system.md` puts it as a
        // rule: a signpost that fills the room it points out of is worse at its
        // job. Both notes below stay uncapped and get every point they ask for.
        .chromeTypeSize()
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

    /// **The one action, and nothing else.** The gap used to share this row;
    /// it is now the seam between the halves, where the reader passes it.
    private var foot: some View {
        HStack(spacing: 20) {
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
