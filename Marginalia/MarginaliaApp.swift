import SwiftUI
import SwiftData

@main
struct MarginaliaApp: App {
    /// `nil` when neither the real store nor a temporary one would open. That
    /// used to be a `fatalError`, which shipped the user a crash log instead of
    /// a sentence — see `docs/issues.md` §7.
    private let container: ModelContainer?
    /// What the store said on the way down, kept so the failure screen can show
    /// it rather than making the reader guess.
    private let failure: String?

    init() {
        // A store that won't open would otherwise take the whole app down. In
        // development that's usually a schema change, and an in-memory library
        // is a far more useful thing to land in than a crash log.
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
                opened = try ModelContainer.marginalia()
            } catch {
                do {
                    opened = try ModelContainer.marginalia(inMemory: true)
                } catch let fallback {
                    problem = "\(error.localizedDescription)"
                        + " — and then: \(fallback.localizedDescription)"
                }
            }
        }

        self.container = opened
        self.failure = problem

        if let opened {
            try? Library.prepare(opened.mainContext, noteLimit: Self.seedLimit)
        }

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

    /// `-tinyLibrary 2` seeds a library that small instead of the full forty.
    ///
    /// Review's empty state needs fewer than `ReviewSetBuilder.minimum` notes
    /// and an exhausted `[↻] keep going` needs fewer than a set's worth, and
    /// neither is reachable in a library of forty — so neither had ever been
    /// seen. Same device as `-startTab`: the simulator can't be tapped.
    ///
    /// **The seed only runs against an empty store**, so uninstall first.
    private static var seedLimit: Int? {
        let requested = UserDefaults.standard.integer(forKey: "tinyLibrary")
        return requested > 0 ? requested : nil
    }
}

struct RootView: View {
    /// Only for resolving a `marginalia://book/…` link — a book is addressed by
    /// one of its notes and somebody has to look it up. Every other screen
    /// reaches the store through its own `@Query`.
    @Environment(\.modelContext) private var context

    /// The one setting that reaches the whole app. Read here rather than in
    /// `Theme`, which stays a table of colors and knows nothing about choices.
    @AppStorage(Preferences.Key.appearance) private var appearance = Appearance.system.rawValue

    // `-startTab books` opens straight to a tab. Used for screenshot passes,
    // since the simulator can't be tapped from the command line.
    @State private var tab: Tab = Tab(argument: UserDefaults.standard.string(forKey: "startTab")) ?? .stream

    /// Set by a `marginalia://note/11` link on a source line. The stream clears
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
    /// The first cross-tab route in the app. The map wants the same one, and so
    /// does a source line's book title.
    @State private var book: Book?

    /// Set by `[◇] connections` on a stream row or a review card: the map opens
    /// two hops out from that note rather than on the whole library.
    @State private var web: Int?

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
                        StreamView(focus: $focus, capturing: $capturing, onOpenWeb: openWeb,
                                   onSearch: { screen = .search },
                                   onSettings: { screen = .settings })
                    case .books: BooksView(open: $book)
                    case .map: MapView(note: $web, onOpenNote: open, onOpenBook: open)
                    case .review:
                        ReviewView(card: $card, onOpenBook: open, onOpenWeb: openWeb,
                                   onOpenNote: open)
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
        // Tapping a connection inside a source line, and arriving from outside
        // the app, are the same journey and take the same route.
        .environment(\.openURL, OpenURLAction { url in
            guard let target = NoteLink.target(from: url) else { return .systemAction }
            follow(target)
            return .handled
        })
        .onOpenURL { url in
            guard let shortID = NoteLink.shortID(from: url) else { return }
            open(shortID)
        }
    }

    /// Where a link in a source line goes. Both kinds arrive here.
    private func follow(_ target: NoteLink.Target) {
        switch target {
        case .note(let shortID):
            open(shortID)
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

    /// A note's own corner of the graph, from wherever the note is being read.
    /// The map has drawn this view since phase 7 and nothing outside the map
    /// could ask for it.
    private func openWeb(_ shortID: Int) {
        screen = nil
        web = shortID
        tab = .map
    }
}

/// `marginalia://note/11` — the scheme behind a `→ n.11` on a source line, and
/// `marginalia://book/11` behind the book title on the same line.
///
/// Both have to stay inline in a wrapping paragraph, so they're rendered as
/// links in an `AttributedString` rather than as buttons. This is the other half
/// of that.
///
/// **A book is addressed by one of its notes, not by an id of its own.** Books
/// have no `shortID` — only notes do — and giving them one to make a URL work
/// would be a schema change in the service of a link. `n.11`'s book is a thing
/// the store can already answer.
nonisolated enum NoteLink {
    static let scheme = "marginalia"

    enum Target: Equatable {
        case note(Int)
        /// The book that note was written from.
        case book(of: Int)
    }

    static func url(for shortID: Int) -> URL? {
        URL(string: "\(scheme)://note/\(shortID)")
    }

    static func url(forBookOf shortID: Int) -> URL? {
        URL(string: "\(scheme)://book/\(shortID)")
    }

    static func target(from url: URL) -> Target? {
        guard url.scheme == scheme, let shortID = Int(url.lastPathComponent) else { return nil }
        switch url.host {
        case "note": return .note(shortID)
        case "book": return .book(of: shortID)
        default: return nil
        }
    }

    static func shortID(from url: URL) -> Int? {
        guard case .note(let shortID) = target(from: url) else { return nil }
        return shortID
    }
}
