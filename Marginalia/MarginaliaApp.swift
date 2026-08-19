import SwiftUI
import SwiftData

@main
struct MarginaliaApp: App {
    // **There is no in-memory fallback, and adding one back is a data-loss bug.**
    //
    // Until phase 15 a store that wouldn't open was answered by opening a
    // temporary one instead, on the reasoning that an empty library beats a
    // crash log. It does — but the reader was never told, so what they got was
    // an app that looked fine, accepted every note they wrote into it, and
    // dropped all of them on quit. `docs/issues.md` §7 called that "arguably
    // worse than the crash was — it's just quieter", and it was right.
    //
    // `StoreFailureView` is the answer instead: it says the notes are still
    // there and prints what the store actually said. An app that can't reach
    // the library has to refuse to take writes it can't keep.

    /// `nil` when the library on disk would not open. That used to be a
    /// `fatalError`, which shipped the user a crash log instead of a sentence —
    /// see `docs/issues.md` §7.
    private let container: ModelContainer?
    /// What the store said on the way down, kept so the failure screen can show
    /// it rather than making the reader guess.
    private let failure: String?

    init() {
        var opened: ModelContainer?
        var problem: String?

        // `-storeFailure 1` goes straight to the screen, which is otherwise only
        // reachable by corrupting a real store. Same device as `-tinyLibrary`:
        // a state worth having drawn correctly that nothing in a healthy app
        // will ever get you to.
        if UserDefaults.standard.bool(forKey: "storeFailure") {
            problem = "-storeFailure — no store was opened on purpose."
        } else {
            do {
                opened = try Library.open(bootstrap: Self.bootstrap)
            } catch {
                problem = error.localizedDescription
            }
        }

        self.container = opened
        self.failure = problem

        // Before any notification can be tapped. Without a delegate a tap only
        // foregrounds the app and the note the reminder was about is lost.
        NotificationRouter.install()
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                RootView()
                    .modelContainer(container)
            } else {
                StoreFailureView(detail: failure)
            }
        }
    }

    /// What a first launch is given.
    ///
    /// **A reader gets `.empty` — the Inbox and nothing else.** The sample
    /// library used to arrive on every fresh install, which handed a reader
    /// five books they had not read and forty notes they had not written, and
    /// then fed those notes back to them in review as things they once thought.
    /// `docs/decisions.md` §25.
    ///
    /// It is still reachable, because every screenshot in this project needs a
    /// library to photograph and the simulator can't be tapped:
    ///
    /// - `-sampleLibrary 1` — all forty notes and the five books.
    /// - `-tinyLibrary <n>` — the sample books and `n` notes, for review's
    ///   empty state and an exhausted `[↻] keep going`, neither of which is
    ///   reachable in a library of forty.
    ///
    /// **A bootstrap only runs against an empty store**, so uninstall first or
    /// you'll keep whatever is already there.
    private static var bootstrap: Library.Bootstrap {
        let defaults = UserDefaults.standard
        let tiny = defaults.integer(forKey: "tinyLibrary")
        if tiny > 0 { return .sample(notes: tiny) }
        if defaults.bool(forKey: "sampleLibrary") { return .sample(notes: nil) }
        return .empty
    }
}

struct RootView: View {
    /// Only for resolving a `passim://book/…` link — a book is addressed by
    /// one of its notes and somebody has to look it up. Every other screen
    /// reaches the store through its own `@Query`.
    @Environment(\.modelContext) private var context

    /// The one setting that reaches the whole app. Read here rather than in
    /// `Theme`, which stays a table of colors and knows nothing about choices.
    @AppStorage(Preferences.Key.appearance) private var appearance = Appearance.system.rawValue

    // `-startTab books` opens straight to a tab. Used for screenshot passes,
    // since the simulator can't be tapped from the command line.
    @State private var tab: Tab = Tab(argument: UserDefaults.standard.string(forKey: "startTab")) ?? .stream

    /// Set by a `passim://note/11` link on a source line. The stream clears
    /// it once it has scrolled there.
    ///
    /// `-openNote 20` seeds it at launch, for the same reason `-startTab` exists:
    /// the simulator can't be tapped from the command line, so this is the only
    /// way to screenshot what following a connection actually looks like.
    @State private var focus: Int? = {
        let requested = UserDefaults.standard.integer(forKey: "openNote")
        return requested > 0 ? requested : nil
    }()

    /// Set by `→ open book` on a review card. The library picks it up when the
    /// tab switches and pushes that book's detail.
    ///
    /// The first cross-tab route in the app: a source line's book title also
    /// reaches this one.
    @State private var book: Book?

    /// Set by a tapped reminder: the card review should open on.
    @State private var card: Int?

    /// True while the stream's capture field has focus.
    ///
    /// **The tab bar comes off the screen while it does.** Content, capture bar
    /// and tab bar are one `VStack`, and `.ignoresSafeArea(.container,…)` below
    /// does not cover the `.keyboard` region — so the keyboard lifts the whole
    /// stack and the tab bar rides up to sit between the capture bar and the
    /// keys, with its 26pt of home-indicator clearance stranded above them.
    ///
    /// Ignoring the keyboard region instead would fix the tab bar by breaking
    /// the capture bar, which is the one thing on the screen that *must* stay
    /// above the keys. So the signpost goes rather than the tool: nothing on a
    /// tab bar is reachable with a keyboard up anyway.
    @State private var capturing = false

    /// The two screens that aren't tabs. There is no fifth tab to give them, so
    /// they hang off the stream's header and take the tab content's place while
    /// they're open — the tab bar stays, because neither is a question and
    /// neither should feel like a modal.
    @State private var screen: Screen? = Screen.atLaunch

    private enum Screen: Equatable {
        case search, settings

        /// `-search "attention"` and `-settings 1`. Neither screen is reachable
        /// without a tap, and the simulator can't be tapped — same device as
        /// `-startTab`.
        static var atLaunch: Self? {
            let defaults = UserDefaults.standard
            if defaults.bool(forKey: "settings") { return .settings }
            if defaults.string(forKey: "search") != nil { return .search }
            return nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch screen {
                case .search:
                    SearchView(close: { screen = nil }, onOpenNote: open)
                case .settings:
                    SettingsView(close: { screen = nil })
                case .none:
                    switch tab {
                    case .stream:
                        StreamView(focus: $focus, capturing: $capturing,
                                   onSearch: { screen = .search },
                                   onSettings: { screen = .settings })
                    case .books: BooksView(open: $book)
                    case .review:
                        ReviewView(card: $card, onOpenBook: open, onOpenNote: open)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !capturing {
                TabBar(selection: $tab)
            }
        }
        // A tab is a way out of search and settings as much as `← stream` is —
        // and leaving the stream by any route puts the tab bar back, or it
        // would stay hidden on a screen with no capture field to hide it for.
        .onChange(of: tab) { _, _ in
            screen = nil
            capturing = false
        }
        .onChange(of: screen) { _, _ in capturing = false }
        .background(Theme.canvas)
        // **Top only.** The header draws under the status bar deliberately; the
        // bottom does not, any more. Ignoring it meant the foot of every screen
        // sat over the home indicator and `TabBar` carried a hardcoded 26pt to
        // put itself back — a number that is wrong on any device with a
        // different indicator and on every device with none. Letting the system
        // say how much room it needs also means the capture bar clears the
        // indicator by itself on the one screen that hides the tab bar.
        .ignoresSafeArea(.container, edges: .top)
        // Notes connect themselves. Nothing below this line knows it happens,
        // and nothing asks the reader to confirm a connection.
        .linking()
        // And the next seven days' reminders stay current, whether or not
        // anybody opens settings.
        .reminders()
        .preferredColorScheme(Appearance(rawValue: appearance)?.scheme)
        // A tapped reminder opens the note it was about. `NotificationRouter`
        // posts rather than navigating — this is the only thing in the app that
        // knows how to open a note, and a second copy would drift.
        .onReceive(NotificationCenter.default.publisher(for: NotificationRouter.tapped)) { note in
            guard let shortID = note.userInfo?[NotificationScheduler.noteKey] as? Int else { return }
            openReview(shortID)
        }
        // Tapping a book title inside a source line. The line has to stay one
        // wrapping paragraph, so the title is a link rather than a button, and
        // this is where the link lands.
        .environment(\.openURL, OpenURLAction { url in
            guard let target = NoteLink.target(from: url) else { return .systemAction }
            follow(target)
            return .handled
        })
    }

    /// Where a link in a source line goes. There is one kind left.
    private func follow(_ target: NoteLink.Target) {
        switch target {
        case .book(of: let shortID):
            // A book has no id of its own, so the link names one of its notes.
            // One fetch, on a tap, rather than a schema change to shorten a URL.
            var wanted = FetchDescriptor<Note>(predicate: #Predicate { $0.shortID == shortID })
            wanted.fetchLimit = 1
            guard let book = try? context.fetch(wanted).first?.book else { return }
            open(book)
        }
    }

    private func open(_ shortID: Int) {
        screen = nil
        tab = .stream
        focus = shortID
    }

    private func open(_ book: Book) {
        screen = nil
        self.book = book
        tab = .books
    }

    /// Where a tapped reminder lands: review, on the card the reminder carried.
    /// It's the first card of that day's set — that's how the reminder chose it
    /// — but a notification tapped a day late shouldn't land on the wrong note,
    /// so the card is asked for by id rather than assumed.
    private func openReview(_ shortID: Int) {
        screen = nil
        card = shortID
        tab = .review
    }
}

/// `passim://book/11` — the scheme behind the book title on a source line.
///
/// It has to stay inline in a wrapping paragraph, so it's rendered as a link in
/// an `AttributedString` rather than as a button. This is the other half of that.
///
/// **There was a `passim://note/11` beside it**, behind the `→ n.11`
/// connections every row used to carry. Those came out in phase 13
/// (`docs/decisions.md` §22) and the note form went with them — nothing produced
/// it any more. Opening a note by id is still a thing the app does, from
/// `-openNote` and from a tapped reminder; neither ever went through a URL.
///
/// **A book is addressed by one of its notes, not by an id of its own.** Books
/// have no `shortID` — only notes do — and giving them one to make a URL work
/// would be a schema change in the service of a link. `n.11`'s book is a thing
/// the store can already answer.
nonisolated enum NoteLink {
    static let scheme = "passim"

    enum Target: Equatable {
        /// The book that note was written from.
        case book(of: Int)
    }

    static func url(forBookOf shortID: Int) -> URL? {
        URL(string: "\(scheme)://book/\(shortID)")
    }

    static func target(from url: URL) -> Target? {
        guard url.scheme == scheme, let shortID = Int(url.lastPathComponent) else { return nil }
        switch url.host {
        case "book": return .book(of: shortID)
        default: return nil
        }
    }
}
