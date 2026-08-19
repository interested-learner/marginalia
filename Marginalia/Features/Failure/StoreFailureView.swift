import SwiftUI

/// What the app shows when it has no library to show.
///
/// This is the whole app, drawn without a `ModelContainer` — so it can't use a
/// single row, chip or capture bar, all of which read from the store. What it
/// can do is say what happened in the app's own voice and print what the store
/// actually said, which is the one thing a bug report needs and the one thing a
/// crash log never gave anybody.
///
/// **Nothing here offers to fix it.** A `[↻] try again` would have to reopen a
/// container from inside a screen that exists because that failed, and a button
/// that usually doesn't work is worse than no button.
struct StoreFailureView: View {
    /// What the store said, if it said anything.
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()

            Text("passim")
                .font(Typography.wordmark)
                .foregroundStyle(Theme.ink)

            Text("\(Glyphs.close) the library won't open")
                .font(Typography.screenTitle)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("your notes have not been deleted — the app just couldn't get "
                 + "to them this time. quit passim and open it again; if it "
                 + "says this twice, the message below is what to report.")
                .font(Typography.noteBody)
                .lineSpacing(Typography.bodyLeading)
                .foregroundStyle(Theme.textBody)
                .fixedSize(horizontal: false, vertical: true)

            if let detail, !detail.isEmpty {
                Hairline()
                Text(detail)
                    .font(Typography.source)
                    .foregroundStyle(Theme.textMute)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .background(Theme.canvas)
    }
}
