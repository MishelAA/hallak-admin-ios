import SwiftUI
import UIKit

/// New salon (POST /admin/salons) or "Create salon from request" (POST /admin/leads/{id}/convert).
/// 3 steps: salon · owner · plan & features. Then the one-time login sheet.
struct NewSalonView: View {
    enum Mode: Hashable {
        case new
        case fromLead(Lead)
    }

    enum Step: Int, CaseIterable { case salon, owner, plan }

    let mode: Mode
    /// Called with the new salon id after the login sheet is closed.
    var created: (Int) -> Void = { _ in }

    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var runner = ActionRunner()
    @State private var step = Step.salon

    // Salon
    @State private var name = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var currency = "USD"
    @State private var language = "ar"
    @State private var notes = ""
    // Owner
    @State private var newOwner = true
    @State private var username = ""
    @State private var email = ""
    @State private var ownerName = ""
    @State private var ownerPhone = ""
    @State private var ownerPassword = ""
    @State private var existingOwner: Owner?
    @State private var pickOwner = false
    // Plan & features
    @State private var billed = false
    @State private var subscription = SubscriptionForm()
    @State private var features: [String: Bool] = [:]
    @State private var plans = ScreenLoader<ItemList<Plan>>(.plans(activeOnly: true))
    @State private var featureList = ScreenLoader<ItemList<Feature>>(.features)
    // Result
    @State private var result: CreatedSalon?

    private var isLead: Bool { if case .fromLead = mode { return true } else { return false } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $step) {
                        Text("Salon").tag(Step.salon)
                        Text("Owner").tag(Step.owner)
                        Text("Plan").tag(Step.plan)
                    } label: { EmptyView() }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                switch step {
                case .salon: salonStep
                case .owner: ownerStep
                case .plan: planStep
                }
                Section {
                    if step != .plan {
                        Button {
                            withAnimation { step = Step(rawValue: step.rawValue + 1) ?? .plan }
                        } label: {
                            Text("Next").bold().frame(maxWidth: .infinity, minHeight: Theme.minTouch)
                        }
                        .disabled(!stepValid(step))
                    }
                    ActionButton(title: isLead ? "Create salon from request" : "Create salon", runner: runner,
                                 enabled: Step.allCases.allSatisfy(stepValid)) {
                        await submit()
                    }
                } footer: {
                    if isLead { Text("Anything left empty is taken from the demo request.") }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(isLead ? "Create salon from request" : "New salon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .interactiveDismissDisabled(runner.isRunning)
            .actionErrorAlert(runner)
            .onChange(of: runner.error) { _, e in if let f = e?.field { step = Self.step(for: f) } }
            .sheet(isPresented: $pickOwner) {
                OwnerPickerView { existingOwner = $0; pickOwner = false }
            }
            .sheet(item: Binding(get: { result.flatMap(Created.init) }, set: { if $0 == nil { finish() } })) { r in
                NewLoginSheet(title: "Salon created", login: r.login, warnings: r.warnings) { finish() }
            }
            .task {
                await plans.load(session)
                await featureList.load(session)
                if features.isEmpty {
                    features = Dictionary((featureList.value?.items ?? []).map { ($0.slug, $0.isDefault ?? true) }, uniquingKeysWith: { a, _ in a })
                }
                prefill()
            }
        }
    }

    // MARK: Steps

    private var salonStep: some View {
        Group {
            Section {
                field("Salon name", $name, "name")
                field("Phone", $phone, "phone", keyboard: .phonePad)
                field("Address", $address, "address")
                Picker("Currency", selection: $currency) {
                    Text(verbatim: "USD").tag("USD")
                    Text(verbatim: "LBP").tag("LBP")
                }
                FieldError(runner: runner, field: "currency")
                Picker("Language", selection: $language) {
                    Text(verbatim: "العربية").tag("ar")
                    Text(verbatim: "English").tag("en")
                }
            } header: {
                Text("Salon")
            }
            Section("Notes") {
                TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...5)
            }
        }
    }

    private var ownerStep: some View {
        Group {
            Section {
                Picker(selection: $newOwner) {
                    Text("New owner").tag(true)
                    Text("Existing owner (branch)").tag(false)
                } label: { EmptyView() }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            if newOwner {
                Section {
                    field("Username", $username, "owner.username", lowercase: true)
                    field("Email", $email, "owner.email", keyboard: .emailAddress, lowercase: true)
                    field("Shown name", $ownerName, "owner.name")
                    field("WhatsApp number for the login (optional)", $ownerPhone, "owner.phone", keyboard: .phonePad)
                    SecureField(text: $ownerPassword) { Text("Password (optional, 8+ characters)") }
                        .frame(minHeight: Theme.minTouch)
                    FieldError(runner: runner, field: "owner.password")
                } header: {
                    Text("Owner login")
                } footer: {
                    Text("Leave the password empty and a 12-character password is made. It is shown once, with a WhatsApp button.")
                }
            } else {
                Section {
                    Button {
                        pickOwner = true
                    } label: {
                        LabeledContent {
                            Text(verbatim: existingOwner?.displayName ?? String(localized: "Choose"))
                        } label: {
                            Label("Owner", systemImage: "person.crop.circle")
                        }
                    }
                    FieldError(runner: runner, field: "owner_id")
                } footer: {
                    Text("The salon becomes a branch of this owner: same login for all branches.")
                }
            }
        }
    }

    private var planStep: some View {
        Group {
            Section {
                Toggle("Billed (has a plan)", isOn: $billed)
                if billed {
                    Picker("Plan", selection: $subscription.planId) {
                        Text("Choose").tag(0)
                        ForEach(plans.value?.items ?? []) { p in
                            Text(verbatim: "\(p.name ?? "#\(p.id)") · \(p.priceMonth?.display ?? "")").tag(p.id)
                        }
                    }
                    FieldError(runner: runner, field: "plan_id")
                    Picker("Cycle", selection: $subscription.cycle) {
                        Text("Monthly").tag("month")
                        Text("Yearly").tag("year")
                    }
                    DatePicker("Paid until", selection: $subscription.until, displayedComponents: .date)
                    FieldError(runner: runner, field: "until")
                    Toggle("Trial", isOn: $subscription.trial)
                    Toggle("Switch on the plan features", isOn: $subscription.applyFeatures)
                }
            } header: {
                Text("Plan")
            }
            if !(billed && subscription.applyFeatures), let list = featureList.value?.items, !list.isEmpty {
                Section("Features") {
                    ForEach(list) { f in
                        Toggle(isOn: Binding(get: { features[f.slug] ?? false }, set: { features[f.slug] = $0 })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: f.label ?? f.slug)
                                if let h = f.help, !h.isEmpty { Text(verbatim: h).font(.caption).foregroundStyle(Theme.inkSecondary) }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private func field(_ label: LocalizedStringKey, _ text: Binding<String>, _ key: String,
                       keyboard: UIKeyboardType = .default, lowercase: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(text: text) { Text(label) }
                .keyboardType(keyboard)
                .textInputAutocapitalization(lowercase ? .never : .words)
                .autocorrectionDisabled(lowercase)
                .frame(minHeight: Theme.minTouch)
            FieldError(runner: runner, field: key)
        }
        .listRowBackground(
            RoundedRectangle(cornerRadius: 10).fill(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.red, lineWidth: runner.error?.field == key ? 2 : 0))
        )
    }

    private func stepValid(_ s: Step) -> Bool {
        switch s {
        case .salon: return isLead || !name.trimmingCharacters(in: .whitespaces).isEmpty
        case .owner:
            if newOwner { return isLead || (!username.trimmingCharacters(in: .whitespaces).isEmpty && email.contains("@")) }
            return existingOwner != nil
        case .plan: return !billed || subscription.planId != 0
        }
    }

    static func step(for field: String) -> Step {
        if field.hasPrefix("owner") { return .owner }
        if ["plan_id", "until", "cycle", "price", "features"].contains(field) || field.hasPrefix("subscription") { return .plan }
        return .salon
    }

    private func prefill() {
        guard case .fromLead(let lead) = mode, name.isEmpty else { return }
        name = lead.salon ?? ""
        phone = lead.phone ?? ""
        ownerName = lead.name ?? ""
        email = lead.email ?? ""
        ownerPhone = lead.phone ?? ""
        if let wanted = lead.plan?.lowercased(), let p = plans.value?.items.first(where: { $0.name?.lowercased() == wanted }) {
            billed = true
            subscription.planId = p.id
        }
    }

    /// Only the fields with something in them are sent (the server fills the rest for a demo request).
    var body_: JSONBody {
        var b: JSONBody = ["currency": currency, "language": language]
        func put(_ key: String, _ value: String, into d: inout JSONBody) {
            let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !v.isEmpty { d[key] = v }
        }
        put("name", name, into: &b)
        put("phone", phone, into: &b)
        put("address", address, into: &b)
        put("notes", notes, into: &b)
        if newOwner {
            var o: JSONBody = [:]
            put("username", username, into: &o)
            put("email", email, into: &o)
            put("name", ownerName, into: &o)
            put("phone", ownerPhone, into: &o)
            if !ownerPassword.isEmpty { o["password"] = ownerPassword }
            if !o.isEmpty { b["owner"] = o }
        } else if let id = existingOwner?.id {
            b["owner_id"] = id
        }
        if billed { b["subscription"] = subscription.body }
        if !(billed && subscription.applyFeatures), !features.isEmpty { b["features"] = features }
        return b
    }

    private func submit() async {
        let body = body_
        let answer = await runner.run(session) { () -> CreatedSalon in
            let client = try ActionRunner.client(session)
            switch mode {
            case .new: return try await client.send(.createSalon(body), as: CreatedSalon.self)
            case .fromLead(let lead): return try await client.send(.convertLead(lead.id, body), as: CreatedSalon.self)
            }
        }
        guard let answer else { return }
        ownerPassword = ""
        if answer.login == nil {
            session.showToast(String(localized: "Salon created"))
            created(answer.detail.salon.id)
            dismiss()
        } else {
            result = answer
        }
    }

    private func finish() {
        guard let r = result else { return }
        result = nil
        session.showToast(String(localized: "Salon created"))
        created(r.detail.salon.id)
        dismiss()
    }

    /// The login sheet's item (the password lives only here, in memory).
    private struct Created: Identifiable {
        let id: Int
        let login: NewLogin
        let warnings: [String]
        init?(_ c: CreatedSalon) {
            guard let l = c.login else { return nil }
            id = c.detail.salon.id
            login = l
            warnings = c.warnings ?? []
        }
    }
}

/// Pick an owner (for a new branch or "Move to another owner").
struct OwnerPickerView: View {
    var exclude: Int?
    let picked: (Owner) -> Void

    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var loader = PagedLoader<Owner> { .owners($0) }
    @State private var search = ""

    var body: some View {
        NavigationStack {
            List {
                if loader.items.isEmpty {
                    if let e = loader.error {
                        ErrorView(error: e) { Task { await loader.reload(session) } }
                    } else if loader.isEmpty {
                        EmptyState(title: "No owners")
                    } else {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                }
                ForEach(loader.items.filter { $0.id != exclude }) { owner in
                    Button {
                        picked(owner)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: owner.displayName).foregroundStyle(Theme.ink)
                            Text(verbatim: (owner.salons ?? []).compactMap(\.name).joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(Theme.inkSecondary)
                        }
                        .frame(minHeight: Theme.minTouch)
                    }
                    .task { await loader.loadMoreIfNeeded(after: owner, session) }
                }
            }
            .navigationTitle("Choose the owner")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: Text("Name, login or email"))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .task(id: search) {
                if loader.loadedOnce {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { return }
                }
                let s = search.trimmingCharacters(in: .whitespaces)
                await loader.setFilters(s.isEmpty ? [:] : ["search": s], session)
            }
        }
    }
}
