import SwiftUI

/// Tab bar: Home · Salons · Money · Requests · More.
struct MainTabView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        @Bindable var session = session
        TabView(selection: $session.selectedTab) {
            stack(.home) { HomeView() }
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppSession.Tab.home)

            stack(.salons) { SalonsView() }
                .tabItem { Label("Salons", systemImage: "scissors") }
                .tag(AppSession.Tab.salons)

            stack(.money) { MoneyView() }
                .tabItem { Label("Money", systemImage: "banknote") }
                .tag(AppSession.Tab.money)

            stack(.requests) { RequestsView() }
                .tabItem { Label("Requests", systemImage: "person.badge.plus") }
                .tag(AppSession.Tab.requests)

            stack(.more) { MoreView() }
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
                .tag(AppSession.Tab.more)
        }
        .task { await session.refreshMe() }
    }

    private func stack<Root: View>(_ tab: AppSession.Tab, @ViewBuilder root: () -> Root) -> some View {
        NavigationStack(path: Binding(get: { session.path(tab) }, set: { session.paths[tab] = $0 })) {
            root().appDestinations()
        }
    }
}
