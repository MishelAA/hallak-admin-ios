import SwiftUI

/// More. M2: settings (connected site, versions, Face ID, log out). Health, Activity, Owners,
/// WhatsApp and AI come in M5.
struct MoreView: View {
    @Environment(AppSession.self) private var session
    @State private var confirmLogout = false

    var body: some View {
        @Bindable var session = session
        List {
            Section("Coming next") {
                comingRow("Health", "stethoscope", show: session.me?.hasCheck ?? true)
                comingRow("Activity", "list.bullet.rectangle", show: true)
                comingRow("Owners", "person.2", show: true)
                comingRow("WhatsApp bot", "message", show: session.me?.hasWhatsApp ?? true)
                comingRow("AI assistant", "sparkles", show: session.me?.hasAI ?? true)
            }

            Section("Connected") {
                row("Site", session.credentials?.site.host)
                row("User", session.credentials?.username)
                row("WordPress", session.ping?.wordpress ?? session.me?.site?.wordpress)
                row("Hallak core", session.ping?.hallakCore ?? session.me?.site?.hallakCore)
                row("API", session.ping?.api ?? session.me?.site?.api)
                row("App", Self.appVersion)
            }

            Section {
                if session.canUseBiometrics {
                    Toggle(isOn: Binding(
                        get: { session.faceIDEnabled },
                        set: { session.faceIDEnabled = $0 }
                    )) {
                        Label("Lock with \(session.biometryName)", systemImage: "faceid")
                    }
                }
            } footer: {
                Text("Asks again after 5 minutes in the background.")
            }

            Section {
                Button(role: .destructive) {
                    confirmLogout = true
                } label: {
                    Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .frame(minHeight: Theme.minTouch)
            } footer: {
                Text("Lost phone? In wp-admin → Users → Profile → Application Passwords, revoke “Hallak iPhone”. The app stops working at once.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("More")
        .confirmationDialog("Log out of Hallak Admin?", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("Log out", role: .destructive) { Task { await session.logout() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The login and the saved data are removed from this iPhone.")
        }
    }

    static var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }

    @ViewBuilder
    private func comingRow(_ title: LocalizedStringKey, _ icon: String, show: Bool) -> some View {
        if show {
            Label(title, systemImage: icon)
                .foregroundStyle(Theme.inkSecondary)
                .badge(Text("M5"))
        }
    }

    private func row(_ label: LocalizedStringKey, _ value: String?) -> some View {
        LabeledContent {
            Text(verbatim: value ?? "–").monospacedDigit().environment(\.layoutDirection, .leftToRight)
        } label: {
            Text(label)
        }
    }
}
