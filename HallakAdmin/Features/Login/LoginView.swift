import SwiftUI

/// What the login screen shows after a failed "Connect".
struct LoginFailure: Equatable {
    enum Field { case site, username, password }

    let message: String
    var field: Field?
    var showHelp = false
    var details: [String: String] = [:]

    init(_ error: APIError) {
        message = error.userMessage
        details = error.check ?? [:]
        switch error.behaviour {
        case .wrongUsername:
            field = .username
        case .wrongPassword:
            field = .password
            showHelp = true
        case .logOut where error.code == "smapi_https":
            field = .site
        case .loginMessage:
            showHelp = error.code == "smapi_app_passwords_off"
        default:
            if error.code == "bad_answer" || error.status == 404 { field = .site }
        }
    }
}

@Observable
@MainActor
final class LoginModel {
    var site = "https://hallak.online"
    var username = ""
    var password = ""
    private(set) var isConnecting = false
    private(set) var failure: LoginFailure?

    var canConnect: Bool {
        !isConnecting && !username.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty && !site.isEmpty
    }

    func connect(_ session: AppSession) async {
        guard canConnect else { return }
        isConnecting = true
        failure = nil
        defer { isConnecting = false }
        do {
            try await session.connect(site: site, username: username, password: password)
            password = ""
            Haptics.success()
        } catch let e as APIError {
            failure = LoginFailure(e)
            Haptics.error()
        } catch {
            failure = LoginFailure(.offline)
            Haptics.error()
        }
    }
}

struct LoginView: View {
    @Environment(AppSession.self) private var session
    @State private var model = LoginModel()
    @State private var showHelp = false
    @FocusState private var focus: LoginFailure.Field?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 14) {
                        Image("LogoPlaque")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 240)
                            .accessibilityLabel(Text("Hallak"))
                        BarberStripe(height: 5).frame(maxWidth: 180).clipShape(Capsule())
                        Text("Super admin")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                if let notice = session.loginNotice {
                    Section {
                        Label { Text(verbatim: notice) } icon: { Image(systemName: "exclamationmark.triangle.fill") }
                            .foregroundStyle(Theme.orange)
                    }
                }

                Section {
                    field("Site address", text: $model.site, kind: .site) {
                        TextField(text: $model.site, prompt: Text(verbatim: "https://hallak.online")) { Text("Site address") }
                            .keyboardType(.URL)
                            .textContentType(.URL)
                    }
                    field("Username", text: $model.username, kind: .username) {
                        TextField(text: $model.username) { Text("Username") }
                            .textContentType(.username)
                    }
                    field("Application Password", text: $model.password, kind: .password) {
                        SecureField(text: $model.password) { Text("Application Password") }
                            .textContentType(.password)
                    }
                } footer: {
                    Button {
                        showHelp = true
                    } label: {
                        Label("How do I get an Application Password?", systemImage: "questionmark.circle")
                            .font(.footnote)
                    }
                    .frame(minHeight: Theme.minTouch)
                }

                if let f = model.failure {
                    Section {
                        Text(verbatim: f.message)
                            .foregroundStyle(Theme.red)
                            .font(.subheadline.weight(.medium))
                        if f.showHelp {
                            Button("How do I get an Application Password?") { showHelp = true }
                        }
                        if !f.details.isEmpty {
                            DisclosureGroup("Details") {
                                ForEach(f.details.sorted(by: { $0.key < $1.key }), id: \.key) { item in
                                    LabeledContent {
                                        Text(verbatim: item.value)
                                    } label: {
                                        Text(verbatim: item.key.replacingOccurrences(of: "_", with: " "))
                                    }
                                    .font(.footnote)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button {
                        Task { await model.connect(session) }
                    } label: {
                        HStack {
                            Spacer()
                            if model.isConnecting { ProgressView().tint(.white) }
                            Text(model.isConnecting ? "Connecting…" : "Connect").bold()
                            Spacer()
                        }
                        .frame(minHeight: Theme.minTouch)
                    }
                    .listRowBackground(model.canConnect ? Theme.actionRed : Theme.grey.opacity(0.5))
                    .foregroundStyle(.white)
                    .disabled(!model.canConnect)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onSubmit {
                switch focus {
                case .site: focus = .username
                case .username: focus = .password
                default: Task { await model.connect(session) }
                }
            }
            .onChange(of: model.failure) { _, f in if let field = f?.field { focus = field } }
            .sheet(isPresented: $showHelp) { AppPasswordHelp() }
        }
    }

    /// A field with a red outline when the error is about it.
    private func field<F: View>(_ label: LocalizedStringKey, text: Binding<String>, kind: LoginFailure.Field, @ViewBuilder _ content: () -> F) -> some View {
        content()
            .focused($focus, equals: kind)
            .submitLabel(kind == .password ? .go : .next)
            .frame(minHeight: Theme.minTouch)
            .listRowBackground(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.red, lineWidth: model.failure?.field == kind ? 2 : 0))
            )
            .accessibilityHint(model.failure?.field == kind ? Text(verbatim: model.failure?.message ?? "") : Text(verbatim: ""))
    }
}

/// The 3 steps to make an Application Password.
struct AppPasswordHelp: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    step(1, "In wp-admin, open Users → Profile.")
                    step(2, "Under Application Passwords, type the name “Hallak iPhone” and press Add.")
                    step(3, "Copy the password that appears (spaces are fine) and paste it in the app.")
                } footer: {
                    Text("Your normal wp-admin password does not work here. If you lose the phone, revoke this Application Password in the same place: the app stops working at once.")
                }
            }
            .navigationTitle("Application Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func step(_ n: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(verbatim: "\(n)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.brandRed))
                .accessibilityHidden(true)
            Text(text)
        }
        .padding(.vertical, 4)
    }
}

/// After connecting: versions, then "Use Face ID?".
struct WelcomeView: View {
    @Environment(AppSession.self) private var session
    let ping: Ping
    @State private var busy = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image("BarberHappy")
                .resizable()
                .scaledToFit()
                .frame(height: 170)
                .accessibilityHidden(true)
            Text("Connected").font(.title.bold()).foregroundStyle(Theme.ink)
            if let name = session.me?.user?.name ?? ping.user {
                Text(verbatim: name).foregroundStyle(Theme.inkSecondary)
            }
            VStack(spacing: 0) {
                versionRow("Site", ping.site ?? session.credentials?.site.host ?? "")
                Divider()
                versionRow("WordPress", ping.wordpress)
                Divider()
                versionRow("Hallak core", ping.hallakCore)
                Divider()
                versionRow("API", ping.api)
            }
            .background(RoundedRectangle(cornerRadius: Theme.cardRadius).fill(Theme.card))
            .padding(.horizontal)

            Spacer()

            if session.canUseBiometrics {
                Text("Lock the app with \(session.biometryName)? It asks again after 5 minutes in the background.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.inkSecondary)
                    .padding(.horizontal, 24)
                Button {
                    finish(faceID: true)
                } label: {
                    Text("Use \(session.biometryName)").bold().frame(maxWidth: .infinity, minHeight: Theme.minTouch)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.actionRed)
                .padding(.horizontal)
                Button("Not now") { finish(faceID: false) }
                    .frame(minHeight: Theme.minTouch)
            } else {
                Button {
                    finish(faceID: false)
                } label: {
                    Text("Open Hallak Admin").bold().frame(maxWidth: .infinity, minHeight: Theme.minTouch)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.actionRed)
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 24)
        .disabled(busy)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    private func finish(faceID: Bool) {
        busy = true
        Task { await session.finishWelcome(enableFaceID: faceID) }
    }

    private func versionRow(_ label: LocalizedStringKey, _ value: String?) -> some View {
        LabeledContent {
            Text(verbatim: value ?? "–").monospacedDigit().environment(\.layoutDirection, .leftToRight)
        } label: {
            Text(label)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

/// Covers the app until Face ID / passcode says yes.
struct LockView: View {
    @Environment(AppSession.self) private var session
    @State private var askedOnce = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image("LogoPlaque")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 240)
                .accessibilityLabel(Text("Hallak"))
            Text("Hallak Admin is locked").font(.headline).foregroundStyle(Theme.ink)
            Button {
                Task { await session.unlock() }
            } label: {
                Label("Unlock with \(session.biometryName)", systemImage: "faceid")
                    .bold()
                    .frame(maxWidth: .infinity, minHeight: Theme.minTouch)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.actionRed)
            .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .task {
            guard !askedOnce else { return }
            askedOnce = true
            await session.unlock()
        }
    }
}
