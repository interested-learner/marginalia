import SwiftUI
import SwiftData

@main
struct MarginaliaApp: App {
    private let container: ModelContainer

    init() {
        // A store that won't open would otherwise take the whole app down. In
        // development that's usually a schema change, and an in-memory library
        // is a far more useful thing to land in than a crash log.
        let container = (try? ModelContainer.marginalia())
            ?? (try? ModelContainer.marginalia(inMemory: true))
        guard let container else { fatalError("could not open the library") }
        self.container = container

        try? Library.prepare(container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
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

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case .stream: StreamView(focus: $focus)
                case .books: BooksView()
                case .map: MapView()
                case .review: ReviewView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            TabBar(selection: $tab)
        }
        .background(Theme.canvas)
        .ignoresSafeArea(.container, edges: [.top, .bottom])
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
