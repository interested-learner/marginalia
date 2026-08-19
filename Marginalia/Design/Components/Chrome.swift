import SwiftUI

/// One header per screen.
///
/// The wordmark appears on **stream only** — every other screen gets a single
/// header carrying its own name. Never stack a wordmark row above a title row;
/// that was the prototype's arrangement and it spent ~50pt restating what the
/// tab bar already says.
struct ScreenHeader<Detail: View>: View {
    enum Style { case wordmark(subtitle: String), title(String) }

    let style: Style
    var trailing: String?
    /// The two screens the app has that aren't tabs — `search` and `settings` —
    /// hang off the stream's header, because the stream is home and there is no
    /// fifth tab to give them. Link buttons, like every other action in the app
    /// that isn't the one thing the screen is for.
    var actions: [HeaderAction] = []
    /// A screen pushed over another one names where it came back to. `←` is in
    /// the vocabulary already; this is the only place it's used.
    var back: BackLink?
    /// Anything the screen's own header carries under its title — book detail
    /// puts the author, the status and the progress bar here.
    @ViewBuilder var detail: Detail

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                if let back {
                    Button(action: back.action) {
                        Text("\(Glyphs.back) \(back.label)")
                            .font(Typography.source)
                            .foregroundStyle(Theme.textMute)
                            .frame(minHeight: 30, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    switch style {
                    case .wordmark(let subtitle):
                        Text("passim")
                            .font(Typography.wordmark)
                            .foregroundStyle(Theme.ink)
                        Text("· \(subtitle)")
                            .font(Typography.meta)
                            .foregroundStyle(Theme.textAsh)
                    case .title(let name):
                        Text(name)
                            .font(Typography.screenTitle)
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    if let trailing {
                        Text(trailing)
                            .font(Typography.meta)
                            .foregroundStyle(Theme.textAsh)
                    }

                    ForEach(actions) { action in
                        MarkerButton(title: action.label, kind: .link, action: action.action)
                    }
                }

                detail
            }
            .padding(.horizontal, 20)
            .padding(.top, 54)
            .padding(.bottom, 12)

            Hairline()
        }
        .background(Theme.canvas)
        // The header names the screen; it isn't the screen. See
        // `chromeTypeSize()` — and note this covers `detail` too, which is
        // where book detail's progress bar lives: `[████░░░░░░]` is ten cells
        // of monospace and a bar that wraps is not a bar.
        .chromeTypeSize()
    }
}

/// Where `←` goes, and what it's called there.
struct BackLink {
    let label: String
    let action: () -> Void
}

/// A word in a header that does something. `search` and `settings` are the only
/// two, and they're both on the stream.
struct HeaderAction: Identifiable {
    let label: String
    let action: () -> Void

    var id: String { label }
}

extension ScreenHeader where Detail == EmptyView {
    init(
        style: Style,
        trailing: String? = nil,
        actions: [HeaderAction] = [],
        back: BackLink? = nil
    ) {
        self.init(style: style, trailing: trailing, actions: actions, back: back) { EmptyView() }
    }
}

/// Three tabs. The active one is marked by a 2pt ink border on its *top* edge,
/// offset up 1pt so it overlaps the container hairline — the indicator sits
/// above the tab, not below it.
struct TabBar: View {
    @Binding var selection: Tab

    var body: some View {
        VStack(spacing: 0) {
            Hairline()
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    let active = tab == selection
                    Button {
                        selection = tab
                    } label: {
                        Text("\(tab.glyph) \(tab.label)")
                            .font(active ? Typography.tabLabelActive : Typography.tabLabel)
                            .foregroundStyle(active ? Theme.ink : Theme.textMute)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .overlay(alignment: .top) {
                                Rectangle()
                                    .fill(active ? Theme.ink : .clear)
                                    .frame(height: 2)
                                    .offset(y: -1)
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(Theme.canvas)
        // Three fixed labels sharing one row, so this is the ceiling that
        // matters most — see `chromeTypeSize()`. Above it the labels wrapped
        // into each other.
        .chromeTypeSize()
    }
}

enum Tab: CaseIterable {
    case stream, books, review

    var label: String {
        switch self {
        case .stream: "stream"
        case .books: "books"
        case .review: "review"
        }
    }

    init?(argument: String?) {
        guard let match = Tab.allCases.first(where: { $0.label == argument }) else { return nil }
        self = match
    }

    var glyph: String {
        switch self {
        case .stream: Glyphs.tabStream
        case .books: Glyphs.tabBooks
        case .review: Glyphs.tabReview
        }
    }
}

/// `[x] no notes yet — capture the first one`
struct EmptyState: View {
    let message: String
    var glyph: String = Glyphs.finished

    var body: some View {
        Text("\(glyph) \(message)")
            .font(Typography.noteBody)
            .foregroundStyle(Theme.textAsh)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
    }
}

/// A date group header in the stream: `today · wed aug 13`, `yesterday`, `earlier`.
struct GroupHeader: View {
    let label: String

    var body: some View {
        Text(label)
            .font(Typography.meta)
            .foregroundStyle(Theme.textAsh)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 6)
    }
}
