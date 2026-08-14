import SwiftUI

/// The app asking whether it should really do the irreversible thing.
///
/// **Its own sheet rather than `confirmationDialog`.** A system dialog arrives
/// in San Francisco with pill buttons and a 26pt corner radius — three design
/// rules broken in one presentation, and it would be the only place in the app
/// that looked like iOS. The same argument that keeps the book picker off a
/// wheel.
///
/// The naming is deliberate: the button says what it will do (`[x] delete`),
/// never `ok` or `yes`. The sentence under the title says what goes with it,
/// because the whole point of asking is that the answer isn't obvious.
struct ConfirmSheet: View {
    /// `delete n.11?`
    let title: String
    /// What it takes with it, in the app's own words.
    let consequence: String
    /// `[x] delete` — a marker and a verb, like every other button here.
    let confirmTitle: String
    let confirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(Typography.screenTitle)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(consequence)
                .font(Typography.noteBody)
                .lineSpacing(Typography.bodyLeading)
                .foregroundStyle(Theme.textBody)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 16)

            // The destructive button is first and filled, because it's the one
            // the reader came here for. `cancel` is secondary and unmarked —
            // backing out isn't an action, it's the absence of one.
            MarkerButton(title: confirmTitle, kind: .danger) {
                confirm()
                // Every delete in the app goes through this button, so this is
                // the only place the erase haptic is fired from — the same
                // one-path-in rule `Eraser` itself follows. `cancel` below is
                // deliberately silent.
                Haptics.erased()
                dismiss()
            }
            MarkerButton(title: "cancel", kind: .secondary) { dismiss() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .padding(.top, 12)
        .background(Theme.canvas)
    }
}

extension View {

    /// The presentation every sheet in this app uses: square corners, the app's
    /// own canvas behind it, and no drag indicator. A confirmation takes half
    /// the screen rather than all of it — it's a question, not a screen.
    func confirmSheetChrome() -> some View {
        self
            .presentationBackground(Theme.canvas)
            .presentationCornerRadius(0)
            .presentationDragIndicator(.hidden)
            .presentationDetents([.medium])
    }
}
