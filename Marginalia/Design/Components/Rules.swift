import SwiftUI

/// The only separation device in this app. There are no shadows anywhere —
/// a hairline or a shift to `surfaceSoft`, nothing else.
struct Hairline: View {
    var axis: Axis = .horizontal

    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(
                width: axis == .vertical ? 1 : nil,
                height: axis == .horizontal ? 1 : nil
            )
    }
}

/// A hairline that carries a word: `──── 29 days apart ────`.
///
/// **The divider as a statement rather than a boundary.** Everywhere else in
/// this app a `Hairline` means *these are separate things*, which is exactly
/// what the crossing card's seam must not say — the two halves of a crossing
/// are the one thing the card is about. A label in the break is what turns the
/// rule around, and it is the same 12% `Theme.hairline` doing it: no new
/// weight, no fill, and still not an arrow.
///
/// The label sits at `Typography.source` / `Theme.textMute`, the weight the gap
/// already had in the crossing card's foot. Nothing got louder; it moved.
///
/// **It folds past `isAccessibilitySize`**, the one conditional `MarginColumn`
/// also carries. At those sizes the label wraps to two and three lines and the
/// rules run through the middle of it — a rule with a paragraph in it has
/// stopped being a rule. Folded, the hairline goes above the label and spans
/// the full width, which is what a divider does everywhere else in the app.
struct LabeledRule: View {
    let label: String

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize { folded } else { ruled }
    }

    private var ruled: some View {
        HStack(spacing: 12) {
            Hairline()

            text
                // Two flexible hairlines will otherwise take the width from the
                // label and wrap it to one word a line.
                .layoutPriority(1)

            Hairline()
        }
    }

    private var folded: some View {
        VStack(alignment: .leading, spacing: 8) {
            Hairline()
            text
        }
    }

    private var text: some View {
        Text(label)
            .font(Typography.source)
            .foregroundStyle(Theme.textMute)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The device that carries the app's name.
///
/// Puts the note id in a 48pt leading column with a hairline down its trailing
/// edge, so the column reads as an actual margin and the id annotates the text
/// beside it. Used on stream rows and book detail — the review card is centered
/// and open by design, and does not use this.
///
/// **It folds at the accessibility sizes, and the id goes above the note.** The
/// column is a `@ScaledMetric` 48, so at
/// `accessibility-extra-extra-extra-large` it is 110pt of a 393pt screen and
/// the note it is annotating gets about five characters a line. The margin is
/// the app's identity at every size somebody reads at by choice; at the sizes
/// somebody reads at by necessity it costs nearly half the width of the thing
/// it exists to annotate, and the note has to win that. The id doesn't
/// disappear — it moves, to exactly where the review card has always put it.
struct MarginColumn<Content: View>: View {
    let label: String
    /// Applied inside the column so the rule still spans the full row height and
    /// meets the dividers above and below it.
    var inset: CGFloat = 12
    @ViewBuilder var content: Content

    @ScaledMetric(relativeTo: .footnote) private var width: CGFloat = 48
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize { folded } else { ruled }
    }

    /// The margin proper.
    private var ruled: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(label)
                .font(Typography.meta)
                .foregroundStyle(Theme.textAsh)
                .padding(.top, inset + 2)   // sits on the first text baseline
                .frame(width: width, alignment: .leading)

            Hairline(axis: .vertical)

            content
                .padding(.leading, 12)
                .padding(.vertical, inset)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// No column, no rule: the id sits above the note with the full width under
    /// it. There is no vertical hairline here on purpose — a rule down the edge
    /// of a full-width row would be a border, and this system doesn't have any.
    private var folded: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Typography.meta)
                .foregroundStyle(Theme.textAsh)

            content
        }
        .padding(.vertical, inset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// A thread of later thoughts, under the note they answer.
///
/// The same device as the quote rule and deliberately the quieter half of it: a
/// `hairline` where a quote gets 2pt of `ink`. A follow-up is subordinate to the
/// note it grew out of, and the weight of the rule is what says so.
///
/// Oldest first — a thread reads forward, because the answer comes after the
/// thing it answers.
struct ThreadRule: View {
    let followUps: [FollowUpRowData]
    /// Removing one thought from the thread, by its position in it. `nil`
    /// wherever the thread is being read rather than listed — see `NoteRow`.
    var onDelete: ((Int) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(followUps) { followUp in
                HStack(alignment: .top, spacing: 12) {
                    Rectangle()
                        .fill(Theme.hairline)
                        .frame(width: 1)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(followUp.when)
                            .font(Typography.meta)
                            .foregroundStyle(Theme.textAsh)
                        Text(followUp.text)
                            .font(Typography.noteBody)
                            .lineSpacing(Typography.bodyLeading)
                            .foregroundStyle(Theme.textBody)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .contentShape(Rectangle())
                .contextMenu {
                    if let onDelete {
                        Button("delete this thought", role: .destructive) {
                            onDelete(followUp.id)
                        }
                    }
                }
            }
        }
        .padding(.top, 8)
    }
}

/// Quoted matter, marked the way a printer marks it: a rule on the leading edge.
///
/// No fill, no radius, no block. The prototype used a filled `surfaceSoft` box
/// here — the one element borrowed from messaging UI rather than print, and it
/// competed with the page in dark mode.
///
/// Quote text is `ink` while thought bodies are `textBody`; that difference is
/// what keeps the two distinguishable now the fill is gone.
///
/// **The rule is the quotation mark, and there are no others.** The printer's
/// convention is a rule *or* quote marks, never both, and `“ ”` would be the
/// closest thing to a dingbat in a system that has ruled those out everywhere
/// else. `docs/issues.md` §18 asked the question and recorded the wrong answer
/// on the way past — it said no surface drew them when in fact two did.
struct QuoteRule: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(Theme.ink)
                .frame(width: 2)

            Text(text)
                .font(Typography.noteBody)
                .lineSpacing(Typography.bodyLeading)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 8)
    }
}
