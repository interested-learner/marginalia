import SwiftUI

/// Every color in the app.
///
/// Views must not contain color literals — not a hex, not `.gray`, not `.secondary`.
/// System colors don't follow this palette in dark mode, which is the whole reason
/// this file exists. If you need a color that isn't here, add it here with both
/// appearances defined, then use it.
///
/// Light values are the prototype's exactly. Dark values are their counterparts,
/// tuned so contrast holds. See `docs/design-system.md`.
///
/// **`nonisolated` is load-bearing, not tidiness.** Every token below is a
/// dynamic `UIColor`, and UIKit stores its provider closure and calls back on
/// whatever thread is resolving the color — for SwiftUI that is regularly
/// `com.apple.SwiftUI.AsyncRenderer`, not main. The project defaults to
/// `MainActor` isolation, so without this the closure is `@MainActor`, Swift 6
/// traps entering it from the renderer, and the app dies with `EXC_BREAKPOINT`
/// somewhere unrelated to whatever you last changed. `ThemeIsolationTests`
/// resolves a color off the main thread on purpose to keep it that way.
nonisolated enum Theme {

    // MARK: Surfaces

    /// Page background. Secondary button fill.
    static let canvas = pair(light: 0xFDFCFC, dark: 0x201D1D)

    /// Text inputs at rest, pressed rows.
    static let surfaceSoft = pair(light: 0xF8F7F7, dark: 0x302C2C)

    /// Pressed state on secondary buttons.
    static let surfaceCard = pair(light: 0xF1EEEE, dark: 0x3A3636)

    // MARK: Ink

    /// Primary text, filled buttons, active indicators, quote rules.
    static let ink = pair(light: 0x201D1D, dark: 0xFDFCFC)

    /// Pressed state on filled buttons.
    static let inkDeep = pair(light: 0x0F0000, dark: 0xFFFFFF)

    /// Text on a filled surface.
    static let onInk = pair(light: 0xFDFCFC, dark: 0x201D1D)

    // MARK: Text ladder

    /// Note body text.
    static let textBody = pair(light: 0x424245, dark: 0xD8D6D6)

    /// Source lines, secondary labels, inactive tabs.
    static let textMute = pair(light: 0x646262, dark: 0x9A9898)

    /// Note ids, timestamps, metadata, counts.
    static let textAsh = pair(light: 0x9A9898, dark: 0x787676)

    /// Reserved. Quotes use `ink`; kept for future use.
    static let textCharcoal = pair(light: 0x302C2C, dark: 0xEBE9E9)

    // MARK: Lines

    /// Every divider, unfilled border, margin rule, and graph edge.
    /// The only separation device in the app — there are no shadows.
    static let hairline = pair(
        light: 0x0F0000, lightAlpha: 0.12,
        dark: 0xFDFCFC, darkAlpha: 0.14
    )

    // MARK: States

    /// A filled button with nothing to do. Never dim to 50% opacity instead.
    static let disabled = pair(light: 0x9A9898, dark: 0x646262)

    /// The one saturated color in the app: the recording dot and destructive
    /// confirmations. Nothing else.
    static let danger = pair(light: 0xFF3B30, dark: 0xFF453A)

    // MARK: - Construction

    private static func pair(light: UInt32, dark: UInt32) -> Color {
        pair(light: light, lightAlpha: 1, dark: dark, darkAlpha: 1)
    }

    private static func pair(
        light: UInt32, lightAlpha: CGFloat,
        dark: UInt32, darkAlpha: CGFloat
    ) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
