import SwiftUI

/// Milestone 1: a branded start screen only.
/// M2 turns this into the login gate, the Face ID lock and the five tabs.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Image("LogoPlaque")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280)
                    .accessibilityLabel(Text("Hallak"))
                BarberStripe()
                    .frame(maxWidth: 220)
                    .clipShape(Capsule())
                Text("Hallak Admin")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.ink)
                Text("Version 1 is on its way. Login and the Home screen come in the next build.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.inkSecondary)
                    .padding(.horizontal, 32)
                Spacer()
                Image("BarberWave")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 180)
                    .accessibilityHidden(true)
                Text(verbatim: "API \(Self.apiVersion) · app \(Self.appVersion)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Theme.inkSecondary)
                    .padding(.bottom, 12)
            }
        }
        // Hide content in the app switcher.
        .blur(radius: scenePhase == .active ? 0 : 20)
    }

    static let apiVersion = "1.0.1"
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}

#Preview("English") { RootView() }
#Preview("Arabic") {
    RootView()
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
}
#Preview("Dark") { RootView().preferredColorScheme(.dark) }
