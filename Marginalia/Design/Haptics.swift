import UIKit

/// Every haptic in the app, named for what happened rather than for how it
/// feels.
///
/// **One vocabulary, for the same reason `Glyphs` is one vocabulary.** Six call
/// sites each choosing their own generator is six different apps under the
/// thumb, and the drift is invisible in code review — a `.heavy` on a star and
/// a `.light` on a delete would read as backwards and nobody would ever see it
/// in a diff. Name the event here, call it there.
///
/// **This is the app's only use of feedback that isn't drawn.** The design
/// system has one font, one line weight and no shadows, and the same restraint
/// applies: a haptic marks something that *happened to the library* — a note
/// exists, a note is gone, a card was read. Navigation gets nothing. Tapping a
/// tab, opening a sheet and pressing `cancel` are all silent on purpose.
///
/// The generators are UIKit's rather than SwiftUI's `.sensoryFeedback`, because
/// five of the six events are closures that fire rather than state that
/// changes, and giving each one a `@State` counter to bind a modifier to would
/// be more scaffolding than signal. Both respect the reader's system haptics
/// setting; neither needs asking.
@MainActor
enum Haptics {

    /// A note or a book now exists. The one unambiguously good outcome in the
    /// app, and the only event that gets the notification generator.
    static func saved() { notify(.success) }

    /// A star went on or came off. Light, because it's a mark on a note rather
    /// than a change to the library — and identical in both directions, since
    /// the reader is looking at the marker that just changed.
    static func starred() { impact(.light) }

    /// A confirmed delete. **Heavy, and not `.error`** — the erase succeeded;
    /// it's the *weight* that should say something irreversible just happened,
    /// not a buzz that reads as a failure. Fired from the confirmation's own
    /// button, so `cancel` is silent.
    static func erased() { impact(.heavy) }

    /// A review card paged past. `.selection` is the detent feel — the same
    /// thing a picker does — which is what paging through a fixed set is.
    static func paged() { selection() }

    /// A line of a scanned page was tapped and kept. Light and identical to
    /// `starred`: both are one small thing collected, and this one fires with
    /// the phone held at arm's length over a book, where the haptic is the only
    /// confirmation the reader can feel without moving their eyes.
    static func captured() { impact(.light) }

    // MARK: - Generators

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private static func notify(_ kind: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(kind)
    }

    private static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
