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
    /// The first cross-tab route in the app. The map will want the same one, and
    /// so will a source line's book title — see `docs/planning.md`.
    @State private var book: Book?

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case .stream: StreamView(focus: $focus)
                case .books: BooksView(open: $book)
                case .map: MapView(onOpenNote: open, onOpenBook: open)
                case .review: ReviewView(onOpenBook: open)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            TabBar(selection: $tab)
        }
        .background(Theme.canvas)
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        // Notes connect themselves. Nothing below this line knows it happens,
        // and nothing asks the reader to confirm a connection.
        .linking()
        // Tapping a connection inside a source line, and arriving from outside
        // the app, are the same journey and take the same route.
        .environment(\.openURL, OpenURLAction { url in
            guard let shortID = NoteLink.shortID(from: url) else { return .systemAction }
            open(shortID)
            return .handled
        })
        .onOpenURL { url in
            guard let shortID = NoteLink.shortID(from: url) else { return }
            open(shortID)
        }
    }

    private func open(_ shortID: Int) {
        tab = .stream
        focus = shortID
    }

    private func open(_ book: Book) {
        self.book = book
        tab = .books
    }
}

/// `marginalia://note/11` — the scheme behind a `→ n.11` on a source line.
///
/// Connections have to stay inline in a wrapping paragraph, so they're rendered
/// as links in an `AttributedString` rather than as buttons. This is the other
/// half of that.
nonisolated enum NoteLink {
    static let scheme = "marginalia"

    static func url(for shortID: Int) -> URL? {
        URL(string: "\(scheme)://note/\(shortID)")
    }

    static func shortID(from url: URL) -> Int? {
        guard url.scheme == scheme, url.host == "note" else { return nil }
        return Int(url.lastPathComponent)
    }
}
