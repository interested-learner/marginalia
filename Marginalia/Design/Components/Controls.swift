import SwiftUI

/// Radius 4 on interactive elements. Everything else in the app is square —
/// never a pill, never a circle, never an iOS-style 26pt card corner.
let interactiveRadius: CGFloat = 4

/// The three button treatments. A disabled primary fills `disabled` and stops
/// responding; it never dims to 50% opacity.
struct MarkerButton: View {
    enum Kind { case primary, secondary, link }

    let title: String
    var kind: Kind = .primary
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            switch kind {
            case .primary:
                Text(title)
                    .font(Typography.button)
                    .foregroundStyle(Theme.onInk)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(enabled ? Theme.ink : Theme.disabled)
                    .clipShape(.rect(cornerRadius: interactiveRadius))

            case .secondary:
                Text(title)
                    .font(Typography.button)
                    .foregroundStyle(Theme.ink)
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
                    .foregroundStyle(Theme.textMute)
                    .underline(pattern: .solid)
                    .padding(.vertical, 4)
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// A tag filter chip. Selected inverts to filled ink — the same move the map
/// uses for a selected node.
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
