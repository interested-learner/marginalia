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

/// The device that carries the app's name.
///
/// Puts the note id in a 48pt leading column with a hairline down its trailing
/// edge, so the column reads as an actual margin and the id annotates the text
/// beside it. Used on stream rows and book detail — the review card is centered
/// and open by design, and does not use this.
struct MarginColumn<Content: View>: View {
    let label: String
    /// Applied inside the column so the rule still spans the full row height and
    /// meets the dividers above and below it.
    var inset: CGFloat = 12
    @ViewBuilder var content: Content

    @ScaledMetric(relativeTo: .footnote) private var width: CGFloat = 48

    var body: some View {
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
}

/// Quoted matter, marked the way a printer marks it: a rule on the leading edge.
///
/// No fill, no radius, no block. The prototype used a filled `surfaceSoft` box
/// here — the one element borrowed from messaging UI rather than print, and it
/// competed with the page in dark mode.
///
/// Quote text is `ink` while thought bodies are `textBody`; that difference is
/// what keeps the two distinguishable now the fill is gone.
struct QuoteRule: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(Theme.ink)
                .frame(width: 2)

            Text("\u{201C}\(text)\u{201D}")
                .font(Typography.noteBody)
                .lineSpacing(Typography.bodyLeading)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 8)
    }
}
