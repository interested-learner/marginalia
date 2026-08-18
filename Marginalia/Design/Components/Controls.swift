import SwiftUI

/// Radius 4 on interactive elements. Everything else in the app is square —
/// never a pill, never a circle, never an iOS-style 26pt card corner.
let interactiveRadius: CGFloat = 4

/// The button treatments. A disabled button fills `disabled` and stops
/// responding; **it never dims to 50% opacity.**
///
/// Which is why the disabled state is drawn rather than declared: SwiftUI's own
/// `.disabled` fades the label, and a faded `onInk` on a `disabled` fill is the
/// one thing the design system says not to do. The tap is swallowed instead.
///
/// `danger` is `primary` in the one saturated color the app has, and it exists
/// for exactly one thing: the button that carries out a destructive
/// confirmation. It is never the button that *offers* one — the link that opens
/// a `ConfirmSheet` stays `textMute` like every other link, or the palette would
/// start colour-coding, which this system doesn't do.
struct MarkerButton: View {
    enum Kind { case primary, secondary, link, danger }

    let title: String
    var kind: Kind = .primary
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button { if enabled { action() } } label: {
            switch kind {
            case .primary:
                Text(title)
                    .font(Typography.button)
                    .foregroundStyle(Theme.onInk)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(enabled ? Theme.ink : Theme.disabled)
                    .clipShape(.rect(cornerRadius: interactiveRadius))

            case .danger:
                Text(title)
                    .font(Typography.button)
                    .foregroundStyle(Theme.onInk)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(enabled ? Theme.danger : Theme.disabled)
                    .clipShape(.rect(cornerRadius: interactiveRadius))

            case .secondary:
                Text(title)
                    .font(Typography.button)
                    .foregroundStyle(enabled ? Theme.ink : Theme.disabled)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Theme.canvas)
                    .overlay(
                        RoundedRectangle(cornerRadius: interactiveRadius)
                            .stroke(Theme.hairline, lineWidth: 1)
                    )
                    .clipShape(.rect(cornerRadius: interactiveRadius))

            case .link:
                Text(title)
                    .font(Typography.source)
                    .foregroundStyle(enabled ? Theme.textMute : Theme.disabled)
                    .underline(pattern: .solid)
                    .padding(.vertical, 4)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(enabled ? [] : .isStaticText)
    }
}

/// A row of segments, each `flex: 1`. Selected inverts to filled ink.
///
/// **Three fit a phone, not four.** A fourth segment at 13pt mono clips its own
/// label at the default text size, so `perRow` wraps the choices to two rows of
/// two rather than shrinking the type — which is what the capture sheet's type
/// selector does now that `[s] scan` exists. See `docs/design-system.md`.
///
/// Shared by the capture sheet's type selector, the book form's status and
/// settings' appearance, so they can't drift into three different segmented
/// controls.
struct SegmentedRow<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    /// How many segments go across before the row wraps. `nil` is one row,
    /// however many there are.
    var perRow: Int?
    let label: (Option) -> String

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { option in
                        segment(option)
                    }
                }
            }
        }
    }

    /// A short last row leaves its segments wide rather than leaving a gap —
    /// an empty slot would read as a choice that had been taken away.
    private var rows: [[Option]] {
        guard let perRow, perRow > 0, options.count > perRow else { return [options] }
        return stride(from: 0, to: options.count, by: perRow).map {
            Array(options[$0 ..< min($0 + perRow, options.count)])
        }
    }

    private func segment(_ option: Option) -> some View {
        let selected = option == selection
        return Button { selection = option } label: {
            Text(label(option))
                .font(Typography.buttonSmall)
                .foregroundStyle(selected ? Theme.onInk : Theme.textMute)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(selected ? Theme.ink : Theme.canvas)
                .overlay(
                    RoundedRectangle(cornerRadius: interactiveRadius)
                        .stroke(selected ? Theme.ink : Theme.hairline, lineWidth: 1)
                )
                .clipShape(.rect(cornerRadius: interactiveRadius))
        }
        .buttonStyle(.plain)
    }
}

/// A single-line text input. Fills `surfaceSoft` at rest; on focus the fill
/// goes to `canvas` and the border to `ink`.
///
/// The placeholder carries the label — there are no field labels in this
/// system, and `p.` in the box says what a caption above it would.
struct InputField: View {
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var autocapitalize: TextInputAutocapitalization = .never
    /// A screen whose whole purpose is one field opens with the keyboard up —
    /// search does, the book form doesn't. Same idiom as `CaptureBar`.
    var focusAtLaunch = false
    var onSubmit: (() -> Void)?

    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .font(Typography.input)
            .foregroundStyle(Theme.ink)
            .tint(Theme.ink)
            .keyboardType(keyboard)
            .autocorrectionDisabled()
            .textInputAutocapitalization(autocapitalize)
            .submitLabel(onSubmit == nil ? .return : .search)
            .onSubmit { onSubmit?() }
            .focused($focused)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(focused ? Theme.canvas : Theme.surfaceSoft)
            .overlay(
                RoundedRectangle(cornerRadius: interactiveRadius)
                    .stroke(focused ? Theme.ink : Theme.hairline, lineWidth: 1)
            )
            .clipShape(.rect(cornerRadius: interactiveRadius))
            .task { if focusAtLaunch { focused = true } }
    }
}

/// A multi-line text input. The same treatment as `InputField` in a taller box:
/// `surfaceSoft` at rest, `canvas` and an `ink` border on focus.
///
/// Shared by the capture sheet and the review card's follow-up composer, so the
/// two can't drift into two different editors. `TextEditor` has no placeholder
/// of its own, hence the label behind it.
struct BodyField: View {
    let placeholder: String
    @Binding var text: String
    /// Grows into whatever room the sheet has left over.
    var minHeight: CGFloat = 150

    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(Typography.input)
                    .foregroundStyle(Theme.textAsh)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 20)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .font(Typography.input)
                .lineSpacing(Typography.bodyLeading)
                .foregroundStyle(Theme.ink)
                .tint(Theme.ink)
                .scrollContentBackground(.hidden)
                .focused($focused)
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
        }
        .frame(minHeight: minHeight, maxHeight: .infinity)
        .background(focused ? Theme.canvas : Theme.surfaceSoft)
        .overlay(
            RoundedRectangle(cornerRadius: interactiveRadius)
                .stroke(focused ? Theme.ink : Theme.hairline, lineWidth: 1)
        )
        .clipShape(.rect(cornerRadius: interactiveRadius))
    }
}

/// A tag filter chip. Selected inverts to filled ink.
struct TagChip: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Typography.source)
                .foregroundStyle(selected ? Theme.onInk : Theme.textMute)
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .background(selected ? Theme.ink : Theme.canvas)
                .overlay(
                    RoundedRectangle(cornerRadius: interactiveRadius)
                        .stroke(selected ? Theme.ink : Theme.hairline, lineWidth: 1)
                )
                .clipShape(.rect(cornerRadius: interactiveRadius))
        }
        .buttonStyle(.plain)
    }
}

/// `[███░░░░░░░]`
struct ASCIIProgressBar: View {
    let fraction: Double

    var body: some View {
        Text(Glyphs.progress(fraction))
            .font(Typography.button)
            .tracking(1)
            .foregroundStyle(Theme.textMute)
    }
}

/// The live recording waveform, `▁▂▃▄▅▆▇` driven by input amplitude.
struct Waveform: View {
    let levels: [Int]

    var body: some View {
        Text(Glyphs.wave(levels))
            .font(Typography.button)
            .tracking(2)
            .foregroundStyle(Theme.ink)
            .lineLimit(1)
    }
}

/// `[●]` — the brackets are ink, the dot is the one saturated color in the app.
struct RecordGlyph: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("[").foregroundStyle(Theme.ink)
            Text("●").foregroundStyle(Theme.danger)
            Text("]").foregroundStyle(Theme.ink)
        }
        .font(Typography.button)
    }
}
