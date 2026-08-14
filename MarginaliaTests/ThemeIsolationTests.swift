import Testing
import SwiftUI
import UIKit
@testable import Marginalia

/// Every color in the app is a dynamic `UIColor` whose provider closure UIKit
/// stores and calls back **on whatever thread is resolving the color** — which
/// for SwiftUI is regularly `com.apple.SwiftUI.AsyncRenderer`, not main.
///
/// The project defaults to `MainActor` isolation, so that closure is
/// `@MainActor` unless `Theme` says otherwise, and Swift 6 traps on the way in.
/// It cost five identical `EXC_BREAKPOINT` crashes before anyone looked.
///
/// These tests resolve a color from a detached task on purpose. They do not
/// merely *fail* if `Theme` loses its `nonisolated` — they stop compiling, and
/// if the isolation check is ever weakened they take the test runner down with
/// a `SIGTRAP` in `Theme.pair`. Either way you'll know.
struct ThemeIsolationTests {

    /// `(red, green, blue, alpha)` — plain values, because `UIColor` isn't
    /// `Sendable` and can't come back across the boundary itself.
    private func resolved(
        _ color: Color,
        _ style: UIUserInterfaceStyle
    ) async -> (CGFloat, CGFloat, CGFloat, CGFloat) {
        await Task.detached {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(color)
                .resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
                .getRed(&r, green: &g, blue: &b, alpha: &a)
            return (r, g, b, a)
        }.value
    }

    private func hex(_ channels: (CGFloat, CGFloat, CGFloat, CGFloat)) -> String {
        let (r, g, b, _) = channels
        return String(format: "%02X%02X%02X",
                      Int((r * 255).rounded()), Int((g * 255).rounded()),
                      Int((b * 255).rounded()))
    }

    /// The one that crashed. Resolving off the main thread must be ordinary.
    @Test func aColorResolvesOffTheMainThread() async {
        #expect(hex(await resolved(Theme.ink, .light)) == "201D1D")
    }

    @Test func bothAppearancesResolveOffTheMainThread() async {
        #expect(hex(await resolved(Theme.canvas, .light)) == "FDFCFC")
        #expect(hex(await resolved(Theme.canvas, .dark)) == "201D1D")
    }

    /// The hairline is the only token with an alpha, and it's the separation
    /// device the whole design rests on.
    @Test func theHairlineKeepsItsAlphaInBothAppearances() async {
        let light = await resolved(Theme.hairline, .light)
        let dark = await resolved(Theme.hairline, .dark)
        #expect(abs(light.3 - 0.12) < 0.01)
        #expect(abs(dark.3 - 0.14) < 0.01)
    }
}
