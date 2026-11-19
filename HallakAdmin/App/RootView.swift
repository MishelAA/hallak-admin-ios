import SwiftUI

/// Login gate → welcome (versions + Face ID) → tabs. Face ID lock on top, blur in the app switcher.
struct RootView: View {
    @State private var session: AppSession
    @Environment(\.scenePhase) private var scenePhase

    init(session: AppSession = AppSession()) {
        _session = State(initialValue: session)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch session.phase {
            case .loggedOut:
                LoginView()
            case .welcome(let ping):
                WelcomeView(ping: ping)
            case .ready:
                MainTabView()
            }
            if session.isLocked {
                LockView().transition(.opacity)
            }
        }
        .animation(.default, value: session.isLocked)
        // Hide content in the app switcher.
        .blur(radius: scenePhase == .active ? 0 : 24)
        .environment(session)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: session.didEnterBackground()
            case .active: session.didBecomeActive()
            default: break
            }
        }
    }
}

#if DEBUG
#Preview("Login") { RootView(session: AppSession(keychain: Keychain(service: "preview"))) }
#Preview("Login, Arabic") {
    RootView(session: AppSession(keychain: Keychain(service: "preview")))
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
}
#endif
