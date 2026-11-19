import SwiftUI

/// Tab bar: Home · Salons · Money · Requests · More.
struct MainTabView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        @Bindable var session = session
        TabView(selection: $session.selectedTab) {
            NavigationStack { HomeView().appDestinations() }
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppSession.Tab.home)

            NavigationStack { SalonsView().appDestinations() }
                .tabItem { Label("Salons", systemImage: "scissors") }
                .tag(AppSession.Tab.salons)

            NavigationStack { ComingSoonView(title: "Money", milestone: "M4").appDestinations() }
                .tabItem { Label("Money", systemImage: "banknote") }
                .tag(AppSession.Tab.money)

            NavigationStack { ComingSoonView(title: "Requests", milestone: "M4").appDestinations() }
                .tabItem { Label("Requests", systemImage: "person.badge.plus") }
                .tag(AppSession.Tab.requests)

            NavigationStack { MoreView().appDestinations() }
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
                .tag(AppSession.Tab.more)
        }
        .task { await session.refreshMe() }
    }
}
