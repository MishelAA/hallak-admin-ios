import SwiftUI
import UIKit

/// More → Demo salons (API 1.4, /admin/me can.demos): list, max, + New demo.
struct DemoListView: View {
    @Environment(AppSession.self) private var session
    @State private var loader = ScreenLoader<DemoList>(.demos)
    @State private var showNew = false

    var body: some View {
        Group {
            switch loader.state {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let error):
                ErrorView(error: error) { Task { await loader.refresh(session) } }
            case .loaded(let answer):
                list(answer.value)
            }
        }
        .background(Theme.background)
        .navigationTitle("Demo salons")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                UpdatedLabel(generatedAt: loader.answer?.generatedAt, isLoading: loader.isLoading)
            }
            if session.canWrite, loader.value?.canAdd == true {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNew = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel(Text("New demo"))
                }
            }
        }
        .sheet(isPresented: $showNew) {
            NewDemoView(languages: loader.value?.languages ?? ["en", "ar"]) { demo in
                session.push(.demo(demo))
            }
        }
        .refreshable { await loader.refresh(session) }
        .task { await loader.load(session) }
        .onChange(of: session.dataVersion) { _, _ in Task { await loader.refresh(session) } }
    }

    private func list(_ d: DemoList) -> some View {
        List {
            if let missing = d.missing, !missing.isEmpty {
                Section {
                    Label {
                        Text("Modules the demo needs are off: \(missing.joined(separator: ", "))")
                    } icon: { Image(systemName: "exclamationmark.triangle") }
                    .font(.footnote)
                    .foregroundStyle(Theme.orange)
                }
            }
            Section {
                if d.items.isEmpty {
                    Text("No demo salon yet.").foregroundStyle(Theme.inkSecondary)
                }
                ForEach(d.items) { demo in
                    NavigationLink(value: AppRoute.demo(demo)) { DemoRow(demo: demo) }
                }
            } header: {
                if let max = d.max { Text("\(d.items.count) of \(max)") }
            } footer: {
                if d.canAdd == false, let max = d.max {
                    Text("There are already \(max) demo salons: delete one to add another.")
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

struct DemoRow: View {
    let demo: DemoSalon

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(verbatim: demo.flag).accessibilityHidden(true)
                Text(verbatim: demo.name ?? "#\(demo.key)").font(.headline).lineLimit(1)
            }
            DemoChips(demo: demo)
            if demo.built == false {
                Text("Not built yet").font(.caption).foregroundStyle(Theme.orange)
            } else if let at = demo.builtAt {
                Text("Built \(Formatters.show(at))").font(.caption).foregroundStyle(Theme.inkSecondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct DemoChips: View {
    let demo: DemoSalon

    var body: some View {
        HStack(spacing: 6) {
            if demo.isPublic { StatusBadge(text: String(localized: "Open to everyone"), color: Theme.green) }
            if demo.nightly == true { StatusBadge(text: String(localized: "Resets nightly"), color: Theme.blue) }
            if demo.main == true { StatusBadge(text: String(localized: "Home page"), color: Theme.purple) }
        }
    }
}

/// One demo: logins (public by design), share links, Open dashboard, switches, home-page demo, reset, delete.
struct DemoDetailView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var demo: DemoSalon
    @State private var runner = ActionRunner()
    @State private var resetLanguage: String?
    @State private var confirmReset = false
    @State private var confirmDelete = false
    @State private var building = false

    init(demo: DemoSalon) { _demo = State(initialValue: demo) }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(verbatim: demo.flag)
                        Text(verbatim: demo.name ?? "#\(demo.key)").font(.title3.bold())
                    }
                    DemoChips(demo: demo)
                    if let at = demo.builtAt {
                        Text("Built \(Formatters.show(at))").font(.caption).foregroundStyle(Theme.inkSecondary)
                    }
                }
                .padding(.vertical, 4)
                if let id = demo.salonId {
                    NavigationLink(value: AppRoute.signedIn(.salon(id: id), title: demo.name ?? String(localized: "Demo"), fallback: nil)) {
                        Label("Open dashboard", systemImage: "rectangle.portrait.and.arrow.forward")
                    }
                    NavigationLink(value: AppRoute.salon(id: id, name: demo.name)) {
                        Label("Salon in the app", systemImage: "scissors")
                    }
                }
            }

            Section {
                login("Owner", demo.ownerLogin, demo.password)
                login("Barber", demo.barberLogin, demo.barberPassword)
            } header: {
                Text("Logins")
            } footer: {
                Text("Demo logins are public on purpose: share them with the salon you visit.")
            }

            if demo.isPublic, let links = demo.links {
                Section {
                    shareRow("Owner link", links.owner)
                    shareRow("Barber link", links.barber)
                } header: {
                    Text("Share links")
                } footer: {
                    Text("Open the demo without a password.")
                }
            }

            if session.canWrite {
                Section {
                    Toggle(isOn: Binding(get: { demo.isPublic }, set: { v in Task { await change(.updateDemo(demo.key, isPublic: v)) } })) {
                        Text("Open to everyone")
                    }
                    Toggle(isOn: Binding(get: { demo.nightly ?? false }, set: { v in Task { await change(.updateDemo(demo.key, nightly: v)) } })) {
                        Text("Resets nightly at 03:00")
                    }
                    if demo.main == true {
                        Label("Used for the home page", systemImage: "house.fill").foregroundStyle(Theme.purple)
                    } else {
                        Button {
                            Task { await change(.updateDemo(demo.key, main: true), toast: String(localized: "Home page demo changed")) }
                        } label: {
                            Label("Use for the home page", systemImage: "house")
                        }
                    }
                } footer: {
                    Text("The home-page “Try the demo” button opens this one.")
                }
                .disabled(runner.isRunning)

                Section {
                    Menu {
                        Button { resetLanguage = "en"; confirmReset = true } label: { Text(verbatim: "English") }
                        Button { resetLanguage = "ar"; confirmReset = true } label: { Text(verbatim: "العربية") }
                        Button("Same language") { resetLanguage = nil; confirmReset = true }
                    } label: {
                        Label("Reset to the start", systemImage: "arrow.counterclockwise")
                    }
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("Delete demo", systemImage: "trash")
                    }
                }
                .disabled(runner.isRunning)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle(demo.name ?? String(localized: "Demo"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(Text("Reset this demo to the start?"), isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset") { Task { await reset() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Everything visitors did is removed. This takes 5 to 20 seconds.")
        }
        .confirmationDialog(Text("Delete this demo salon?"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete demo", role: .destructive) { Task { await delete() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The demo salon, its data and its two logins are deleted.")
        }
        .actionErrorAlert(runner)
        .buildingOverlay(building)
    }

    private func login(_ role: LocalizedStringKey, _ user: String?, _ password: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(role).font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSecondary)
            copyLine(user, icon: "person")
            copyLine(password, icon: "key")
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func copyLine(_ value: String?, icon: String) -> some View {
        if let value, !value.isEmpty {
            HStack {
                Label { Text(verbatim: value).font(.body.monospaced()) } icon: { Image(systemName: icon) }
                    .environment(\.layoutDirection, .leftToRight)
                Spacer()
                Button {
                    UIPasteboard.general.string = value
                    Haptics.tap()
                    session.showToast(String(localized: "Copied"))
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Copy"))
            }
        }
    }

    @ViewBuilder
    private func shareRow(_ title: LocalizedStringKey, _ link: String?) -> some View {
        if let url = Contact.webURL(link) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(verbatim: url.absoluteString).font(.caption).foregroundStyle(Theme.inkSecondary).lineLimit(1)
                }
                Spacer()
                ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("Share"))
                if let wa = Contact.whatsappShare(text: shareText(url)) {
                    Button { openURL(wa) } label: {
                        Image(systemName: "message.fill")
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Theme.green))
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("Send on WhatsApp"))
                }
            }
        }
    }

    private func shareText(_ url: URL) -> String {
        let name = demo.name ?? "Hallak"
        return "\(name)\n\(url.absoluteString)"
    }

    private func change(_ endpoint: Endpoint, toast: String? = nil) async {
        if let a = await runner.run(session, success: toast, {
            try await ActionRunner.client(session).send(endpoint, as: DemoOne.self)
        }) {
            demo = a.demo
        }
    }

    private func reset() async {
        building = true
        defer { building = false }
        let lang = resetLanguage
        if let a = await runner.run(session, success: String(localized: "Demo back to the start"), {
            try await ActionRunner.client(session).send(.resetDemo(demo.key, lang: lang), as: DemoOne.self)
        }) {
            demo = a.demo
        }
    }

    private func delete() async {
        if await runner.run(session, success: String(localized: "Demo deleted"), {
            try await ActionRunner.client(session).send(.deleteDemo(demo.key), as: DemoList.self)
        }) != nil {
            dismiss()
        }
    }
}

/// + New demo: name (optional), language, public, nightly. Building takes 5–20 s: full-screen progress, no retry.
struct NewDemoView: View {
    let languages: [String]
    let created: (DemoSalon) -> Void

    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var runner = ActionRunner()
    @State private var name = ""
    @State private var lang = "ar"
    @State private var isPublic = true
    @State private var nightly = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(text: $name) { Text("Name (optional)") }
                        .textInputAutocapitalization(.words)
                    FieldError(runner: runner, field: "name")
                } footer: {
                    Text("For example the salon you are visiting: “Karim Barber Shop”.")
                }
                Section {
                    Picker("Language", selection: $lang) {
                        if languages.contains("ar") || languages.isEmpty { Text(verbatim: "العربية").tag("ar") }
                        if languages.contains("en") || languages.isEmpty { Text(verbatim: "English").tag("en") }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Open to everyone (share links)", isOn: $isPublic)
                    Toggle("Resets nightly at 03:00", isOn: $nightly)
                }
                Section {
                    ActionButton(title: "Build the demo", runner: runner) { await create() }
                } footer: {
                    Text("Building takes 5 to 20 seconds. If it stops with an error, refresh the list before trying again: the demo may already be there.")
                }
            }
            .navigationTitle("New demo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(runner.isRunning) } }
            .interactiveDismissDisabled(runner.isRunning)
            .actionErrorAlert(runner)
            .buildingOverlay(runner.isRunning)
        }
    }

    private func create() async {
        let body = Endpoint.createDemo(name: name, lang: lang, isPublic: isPublic, nightly: nightly)
        if let a = await runner.run(session, success: String(localized: "Demo salon ready"), {
            try await ActionRunner.client(session).send(body, as: DemoOne.self)
        }) {
            dismiss()
            created(a.demo)
        }
    }
}

extension View {
    /// Full-screen "Building the demo salon…" while a demo is built or reset (5–20 s).
    func buildingOverlay(_ on: Bool) -> some View {
        overlay {
            if on {
                ZStack {
                    Color.black.opacity(0.45).ignoresSafeArea()
                    VStack(spacing: 14) {
                        ProgressView().controlSize(.large).tint(.white)
                        Text("Building the demo salon…").font(.headline).foregroundStyle(.white)
                        Text("This takes 5 to 20 seconds.").font(.footnote).foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(28)
                    .background(RoundedRectangle(cornerRadius: Theme.cardRadius).fill(Theme.navy))
                }
                .transition(.opacity)
                .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: on)
    }
}

extension Contact {
    /// Share a text on WhatsApp (the user picks the chat): https://wa.me/?text=…
    static func whatsappShare(text: String) -> URL? {
        // Strict escaping: & = ? # + inside the text must not cut the message.
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        guard let t = text.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "https://wa.me/?text=" + t)
    }
}
