import SwiftUI

/// More: Health, Activity, Owners, WhatsApp bot, AI assistant, Settings.
/// Screens whose plugin is off (from /admin/me site.plugins) are hidden.
struct MoreView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        List {
            Section {
                if session.me?.hasCheck ?? true { row(.health, "Health", "stethoscope") }
                if session.showsSecurity { row(.security, "Security", "lock.shield") }
                row(.activity(salonId: nil, salonName: nil), "Activity", "list.bullet.rectangle")
                row(.owners, "Owners", "person.2")
                if session.me?.canPlan == true { row(.businessPlan, "Business plan", "chart.line.uptrend.xyaxis") }
                if session.canDemos { row(.demos, "Demo salons", "play.rectangle.on.rectangle") }
            }
            Section {
                if session.me?.hasWhatsApp ?? true { row(.whatsapp, "WhatsApp bot", "message") }
                if session.me?.hasAI ?? true { row(.ai, "AI assistant", "sparkles") }
            }
            if session.me?.canOpenLinks ?? true {
                Section {
                    web("wp-admin", String(localized: "Open wp-admin"), "wrench.and.screwdriver")
                    web("salons", String(localized: "Salons in wp-admin"), "scissors")
                    if session.me?.hasBilling ?? true { web("billing", String(localized: "Billing in wp-admin"), "creditcard") }
                    if session.me?.hasCheck ?? true { web("check", String(localized: "Plugins check"), "checklist") }
                    web("site", String(localized: "Website"), "globe", fallback: session.credentials?.site)
                } header: {
                    Text("Open on the website")
                } footer: {
                    Text("Opens inside the app, signed in as you.")
                }
            }
            Section {
                row(.settings, "Settings", "gearshape")
            } footer: {
                if let host = session.credentials?.site.host, let user = session.credentials?.username {
                    Text(verbatim: "\(user) · \(host)")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("More")
    }

    /// A wp-admin / website page opened signed in (POST /admin/login-link, `to`).
    private func web(_ to: String, _ title: String, _ icon: String, fallback: URL? = nil) -> some View {
        NavigationLink(value: AppRoute.signedIn(.platform(to), title: title, fallback: fallback)) {
            Label { Text(verbatim: title) } icon: { Image(systemName: icon) }
        }
        .frame(minHeight: Theme.minTouch)
    }

    private func row(_ route: AppRoute, _ title: LocalizedStringKey, _ icon: String) -> some View {
        NavigationLink(value: route) {
            Label(title, systemImage: icon)
        }
        .frame(minHeight: Theme.minTouch)
    }
}

/// Settings: language, Face ID, connected site + user + versions, log out, lost phone.
struct SettingsView: View {
    @Environment(AppSession.self) private var session
    @State private var confirmLogout = false

    var body: some View {
        List {
            Section {
                Picker(selection: Binding(get: { session.languageSetting }, set: { session.languageSetting = $0 })) {
                    Text("Same as iPhone").tag(AppSession.LanguageSetting.system)
                    Text(verbatim: "English").tag(AppSession.LanguageSetting.en)
                    Text(verbatim: "العربية").tag(AppSession.LanguageSetting.ar)
                } label: {
                    Label("Language", systemImage: "globe")
                }
            } footer: {
                Text("Some texts change after you close and open the app again.")
            }

            if session.canUseBiometrics {
                Section {
                    Toggle(isOn: Binding(get: { session.faceIDEnabled }, set: { session.faceIDEnabled = $0 })) {
                        Label("Lock with \(session.biometryName)", systemImage: "faceid")
                    }
                } footer: {
                    Text("Asks again after 5 minutes in the background.")
                }
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
        .navigationTitle("Settings")
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

    private func row(_ label: LocalizedStringKey, _ value: String?) -> some View {
        LabeledContent {
            Text(verbatim: value ?? "–").monospacedDigit().environment(\.layoutDirection, .leftToRight)
        } label: {
            Text(label)
        }
    }
}
