import SwiftUI

@main
struct MarginaliaApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    // `-startTab books` opens straight to a tab. Used for screenshot passes,
    // since the simulator can't be tapped from the command line.
    @State private var tab: Tab = Tab(argument: UserDefaults.standard.string(forKey: "startTab")) ?? .stream

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case .stream: StreamView()
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
    }
}
