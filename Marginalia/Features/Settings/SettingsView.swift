import SwiftUI
import SwiftData

/// Notification time and on/off · Markdown export · appearance · about.
///
/// Four things, and nothing else — the spec's list, in the spec's order. Reached
/// from `settings` in the stream's header, like `search`, and it keeps the tab
/// bar for the same reason: it's a screen, not a question.
///
/// **No iOS controls anywhere on it.** A `Toggle` is a green pill, a
/// `DatePicker` is a wheel, and either would be the only thing in the app that
/// looked like iOS — the same argument that keeps the capture sheet's book
/// picker inline. A setting is on when its box is filled.
struct SettingsView: View {
    /// `← stream`.
    let close: () -> Void

    @Query private var notes: [Note]
    @Query private var books: [Book]
    @Query private var edges: [NoteEdge]

    @Environment(\.modelContext) private var context

    @AppStorage(Preferences.Key.appearance) private var appearance = Appearance.system.rawValue
    @AppStorage(Preferences.Key.notificationsOn) private var reminders = false
    @AppStorage(Preferences.Key.notificationMinute) private var minute = Preferences.defaultMinute

    @State private var pickingTime = false
    /// Set when the reader turns reminders on and iOS has already been told no.
    /// The switch goes back off rather than sitting there lying.
    @State private var refused = false
    /// The export, written to a temporary file so `ShareLink` has something a
    /// reader can actually file. Built in a `.task`, never during a redraw.
    @State private var export: URL?
    @State private var rebuilding = false

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(style: .title("settings"),
                         back: BackLink(label: "stream", action: close))

            ScrollView {
                VStack(spacing: 0) {
                    dailyReview
                    appearanceSection
                    library
                    about
                }
            }
        }
        .background(Theme.canvas)
        .task(id: notes.count) { await buildExport() }
    }

    // MARK: Daily review

    private var dailyReview: some View {
        SettingsSection("daily review") {
            MarkerRow(
                label: "one note a day",
                on: reminders,
                action: { toggleReminders() }
            )

            if refused {
                Caption("notifications are off for marginalia in the phone's own "
                     + "settings. it can't ask again from here.")
            }

            if reminders {
                TimeField(minute: $minute, open: $pickingTime)
                Caption("the first card of that day's set, with the note's own text "
                     + "on it — often that's the whole of it.")
            }
        }
    }

    /// **The only place in the app that asks for notification permission.**
    /// Asked at the moment the feature is used, never at launch — the same rule
    /// the microphone and the camera follow, and the reason `.reminders()` on
    /// the root view checks rather than asks.
    ///
    /// The setting is written *after* permission comes back, not before: a
    /// filled box over a refused prompt would be the switch lying, and the
    /// scheduler watches this value, so flipping it last is also what makes the
    /// first seven reminders get written.
    private func toggleReminders() {
        refused = false
        guard !reminders else {
            reminders = false
            return
        }

        Task {
            if await NotificationScheduler.authorize() {
                reminders = true
            } else {
                refused = true
            }
        }
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        SettingsSection("appearance") {
            SegmentedRow(
                options: Appearance.allCases,
                selection: Binding(
                    get: { Appearance(rawValue: appearance) ?? .system },
                    set: { appearance = $0.rawValue }
                ),
                label: { $0.label }
            )
        }
    }

    // MARK: The library

    private var library: some View {
        SettingsSection("library") {
            if let export {
                ShareLink(item: export) {
                    Text("export as markdown")
                        .font(Typography.button)
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Theme.canvas)
                        .overlay(
                            RoundedRectangle(cornerRadius: interactiveRadius)
                                .stroke(Theme.hairline, lineWidth: 1)
                        )
                        .clipShape(.rect(cornerRadius: interactiveRadius))
                }
            }

            Caption("one section per book, threads nested under their notes, "
                 + "connections as [[n.05]] links.")

            MarkerButton(title: rebuilding ? "\(Glyphs.refresh) rebuilding…" : "rebuild connections",
                         kind: .secondary, enabled: !rebuilding) { rebuild() }

            Caption("\(count(notes.count, "note")) · \(count(shelf.count, "book")) · "
                 + "\(count(connections, "connection")). every recompute is a whole "
                 + "one, so this is what the app does on its own after every "
                 + "capture — it's here for when you want to watch it happen.")
        }
    }

    /// The button the spec asks for, over the machinery that was already there:
    /// `LinkWriter.relink` has been a full rebuild since phase 6, so *rebuild
    /// connections* is the same pass, asked for rather than triggered.
    private func rebuild() {
        rebuilding = true
        Task {
            try? await LinkWriter.relink(in: context)
            rebuilding = false
        }
    }

    // MARK: About

    private var about: some View {
        SettingsSection("about") {
            Caption("marginalia \(version) — notes taken from books.")
            Caption("everything stays on this phone. no account, no network, "
                 + "no analytics. the connections between notes are worked out "
                 + "here, by a model that ships with the phone.")
            Caption("JetBrains Mono is used under the SIL Open Font License. "
                 + "book data comes from Open Library.")
        }
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    // MARK: Export

    /// Rebuilt when the library changes rather than on every redraw — writing a
    /// file inside `body` would be a write on every scroll.
    private func buildExport() async {
        let joined = ConnectionIndex.build(edges: edges)
        let document = MarkdownExport.document(
            shelf.map { $0.exported(connections: joined) },
            exported: .now
        )
        export = try? MarkdownExport.file(document, on: .now)
    }

    private var shelf: [Book] { BookShelf.ordered(books) }

    private var connections: Int { edges.filter { !$0.isSuppressed }.count }

    private func count(_ n: Int, _ noun: String) -> String {
        "\(n) \(noun)\(n == 1 ? "" : "s")"
    }
}

// MARK: Parts

/// A titled group of settings, with the hairline above it. The same rhythm the
/// stream's date headers have — a label at 13 `textAsh` over what it names.
private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Hairline()

            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(Typography.meta)
                    .foregroundStyle(Theme.textAsh)
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }
}

/// A sentence under a control, saying what it does. 13pt `textMute` — the
/// weight of a source line, because it annotates the control above it rather
/// than being something to read on its own.
private struct Caption: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Typography.source)
            .foregroundStyle(Theme.textMute)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A setting that is on or off. `[*]` filled, `[ ]` empty — the app's own
/// checkbox, and the same pair the review card stars with.
private struct MarkerRow: View {
    let label: String
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(on ? Glyphs.starred : Glyphs.star)
                    .foregroundStyle(Theme.ink)
                Text(label)
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
            }
            .font(Typography.button)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The time a reminder fires, chosen from a list that opens inline.
///
/// **Not a `DatePicker`.** A wheel is the one piece of iOS chrome the capture
/// sheet's book picker was written to avoid, and this is the same field in the
/// same clothes: a `▼` that expands the choices beneath it.
private struct TimeField: View {
    @Binding var minute: Int
    @Binding var open: Bool

    /// Every half hour. Fine enough that nobody is fighting it, coarse enough
    /// that the list can be read rather than scrolled through.
    private var offered: [Int] {
        stride(from: 0, to: ClockTime.minutesInDay, by: 30).map { $0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.snappy(duration: 0.15)) { open.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Text("at \(ClockTime.label(minute))")
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 8)
                    Text(Glyphs.disclosure)
                        .foregroundStyle(Theme.textMute)
                }
                .font(Typography.input)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.canvas)
                .overlay(
                    RoundedRectangle(cornerRadius: interactiveRadius)
                        .stroke(open ? Theme.ink : Theme.hairline, lineWidth: 1)
                )
                .clipShape(.rect(cornerRadius: interactiveRadius))
            }
            .buttonStyle(.plain)

            if open {
                ScrollViewReader { scroll in
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(offered, id: \.self) { choice in
                                Button {
                                    minute = choice
                                    withAnimation(.snappy(duration: 0.15)) { open = false }
                                } label: {
                                    Text(ClockTime.label(choice))
                                        .font(Typography.source)
                                        .foregroundStyle(choice == minute ? Theme.ink : Theme.textBody)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(choice == minute ? Theme.surfaceSoft : Theme.canvas)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .id(choice)

                                Hairline()
                            }
                        }
                    }
                    .frame(height: 200)
                    .onAppear { scroll.scrollTo(nearestHalfHour, anchor: .center) }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: interactiveRadius)
                        .stroke(Theme.hairline, lineWidth: 1)
                )
                .clipShape(.rect(cornerRadius: interactiveRadius))
                .padding(.top, 8)
            }
        }
    }

    /// The list opens where the current setting is, not at midnight — otherwise
    /// choosing 8am means scrolling past sixteen rows nobody wants.
    private var nearestHalfHour: Int {
        ClockTime.normalized(minute) / 30 * 30
    }
}
