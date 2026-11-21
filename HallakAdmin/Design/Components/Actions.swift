import SwiftUI
import UIKit

/// Runs one change (API 1.2): one at a time (the button is disabled meanwhile, so no double taps),
/// never retried, success → haptic + toast + lists refresh, error → kept for the alert and the field to highlight.
@Observable
@MainActor
final class ActionRunner {
    private(set) var isRunning = false
    var error: APIError?

    /// The field the server named (`data.field`), e.g. "owner.username".
    var errorField: String? { error?.field }

    @discardableResult
    func run<T>(_ session: AppSession, success: String? = nil, refreshLists: Bool = true, _ work: () async throws -> T) async -> T? {
        guard !isRunning else { return nil }
        isRunning = true
        error = nil
        defer { isRunning = false }
        do {
            let result = try await work()
            Haptics.success()
            if refreshLists { session.dataChanged() }
            if let success { session.showToast(success) }
            return result
        } catch let e as APIError {
            if await session.handleSessionError(e) { return nil }
            error = e
            Haptics.error()
            return nil
        } catch {
            self.error = .offline
            Haptics.error()
            return nil
        }
    }

    /// The client of a logged-in session (actions need one).
    static func client(_ session: AppSession) throws -> APIClient {
        guard let c = session.client else { throw APIError(code: "smapi_login", message: String(localized: "Log in again."), status: 401) }
        return c
    }
}

extension View {
    /// Shows the error of an action (the server message is already in the app language).
    func actionErrorAlert(_ runner: ActionRunner) -> some View {
        alert(
            Text("It did not work"),
            isPresented: Binding(get: { runner.error != nil && runner.error?.field == nil }, set: { if !$0 { runner.error = nil } }),
            actions: { Button("OK", role: .cancel) { runner.error = nil } },
            message: { Text(verbatim: runner.error?.userMessage ?? "") }
        )
    }

    /// The short "Saved" message at the bottom of the screen.
    func toastOverlay(_ text: String?) -> some View {
        overlay(alignment: .bottom) {
            if let text {
                Label { Text(verbatim: text) } icon: { Image(systemName: "checkmark.circle.fill") }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Theme.navy))
                    .padding(.bottom, 96)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .animation(.spring(duration: 0.3), value: text)
    }
}

/// An error under a form field when the server named it.
struct FieldError: View {
    let runner: ActionRunner
    let field: String

    var body: some View {
        if runner.error?.field == field, let message = runner.error?.userMessage {
            Text(verbatim: message)
                .font(.footnote)
                .foregroundStyle(Theme.red)
        }
    }
}

/// The main button of a form: disabled while running, with a spinner.
struct ActionButton: View {
    let title: LocalizedStringKey
    var role: ButtonRole?
    let runner: ActionRunner
    var enabled = true
    let action: () async -> Void

    var body: some View {
        Button(role: role) {
            Task { await action() }
        } label: {
            HStack {
                Spacer()
                if runner.isRunning { ProgressView().tint(.white) }
                Text(title).bold()
                Spacer()
            }
            .frame(minHeight: Theme.minTouch)
        }
        .foregroundStyle(.white)
        .listRowBackground(enabled && !runner.isRunning ? (role == .destructive ? Theme.red : Theme.actionRed) : Theme.grey.opacity(0.5))
        .disabled(!enabled || runner.isRunning)
    }
}

/// Shown ONCE after a new salon, a converted demo request or a new password: username, password,
/// copy, and "Send on WhatsApp" (the API's wa.me link with the login message). Never stored.
struct NewLoginSheet: View {
    let title: LocalizedStringKey
    let login: NewLogin
    var warnings: [String] = []
    var done: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var copied = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 10) {
                        Image("BarberHappy").resizable().scaledToFit().frame(height: 120).accessibilityHidden(true)
                        Text("Write it down or send it now: it is shown only once.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
                Section {
                    if let u = login.username { InfoRow(label: "Username", value: u) }
                    LabeledContent {
                        Text(verbatim: login.password)
                            .font(.body.monospaced().bold())
                            .textSelection(.enabled)
                            .environment(\.layoutDirection, .leftToRight)
                    } label: {
                        Text("Password")
                    }
                    Button {
                        UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: login.password]],
                                                      options: [.expirationDate: Date().addingTimeInterval(120), .localOnly: true])
                        copied = true
                        Haptics.tap()
                    } label: {
                        Label(copied ? "Copied" : "Copy password", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    if let u = login.loginUrl { InfoRow(label: "Login page", value: u) }
                }
                if let link = Contact.whatsappURL(login.whatsappLink) {
                    Section {
                        Button {
                            openURL(link)
                        } label: {
                            Label("Send on WhatsApp", systemImage: "message.fill")
                                .bold()
                                .frame(maxWidth: .infinity, minHeight: Theme.minTouch)
                        }
                        .foregroundStyle(.white)
                        .listRowBackground(Theme.green)
                    }
                }
                if !warnings.isEmpty {
                    Section("To check") {
                        ForEach(warnings, id: \.self) { w in
                            Label { Text(verbatim: w) } icon: { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.orange) }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done", action: done) } }
            .interactiveDismissDisabled()
        }
    }
}
