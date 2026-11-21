import SwiftUI
import UIKit

/// Edit a salon: PATCH /admin/salons/{id} with only the fields that changed.
struct EditSalonView: View {
    let detail: SalonDetail
    let saved: (SalonDetail) -> Void

    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var runner = ActionRunner()
    @State private var name = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var currency = "USD"
    @State private var language = "ar"
    @State private var notes = ""
    @State private var ownerName = ""
    @State private var ownerEmail = ""
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Salon") {
                    row("Salon name", $name, "name")
                    row("Phone", $phone, "phone", keyboard: .phonePad)
                    row("Address", $address, "address")
                    Picker("Currency", selection: $currency) {
                        Text(verbatim: "USD").tag("USD")
                        Text(verbatim: "LBP").tag("LBP")
                    }
                    FieldError(runner: runner, field: "currency")
                    Picker("Language", selection: $language) {
                        Text(verbatim: "العربية").tag("ar")
                        Text(verbatim: "English").tag("en")
                    }
                }
                if detail.salon.owner != nil {
                    Section("Owner") {
                        row("Shown name", $ownerName, "owner.name")
                        row("Email", $ownerEmail, "owner.email", keyboard: .emailAddress, lowercase: true)
                    }
                }
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...6)
                }
                Section {
                    ActionButton(title: "Save", runner: runner, enabled: !changes.isEmpty && !name.trimmingCharacters(in: .whitespaces).isEmpty) {
                        await save()
                    }
                } footer: {
                    Text("The currency cannot change once the salon has money data.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Edit salon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .interactiveDismissDisabled(runner.isRunning)
            .actionErrorAlert(runner)
            .onAppear(perform: fill)
        }
    }

    private func fill() {
        guard !loaded else { return }
        loaded = true
        let s = detail.salon
        name = s.name
        phone = s.phone ?? ""
        address = s.address ?? ""
        currency = s.currency ?? "USD"
        language = s.language ?? "ar"
        notes = s.notes ?? ""
        ownerName = s.owner?.name ?? ""
        ownerEmail = s.owner?.email ?? ""
    }

    /// Only what changed.
    var changes: JSONBody {
        let s = detail.salon
        var b: JSONBody = [:]
        func diff(_ key: String, _ new: String, _ old: String?) {
            let v = new.trimmingCharacters(in: .whitespacesAndNewlines)
            if v != (old ?? "") { b[key] = v }
        }
        diff("name", name, s.name)
        diff("phone", phone, s.phone)
        diff("address", address, s.address)
        diff("notes", notes, s.notes)
        if currency != (s.currency ?? "USD") { b["currency"] = currency }
        if language != (s.language ?? "ar") { b["language"] = language }
        var o: JSONBody = [:]
        if ownerName.trimmingCharacters(in: .whitespaces) != (s.owner?.name ?? "") { o["name"] = ownerName.trimmingCharacters(in: .whitespaces) }
        if ownerEmail.trimmingCharacters(in: .whitespaces) != (s.owner?.email ?? "") { o["email"] = ownerEmail.trimmingCharacters(in: .whitespaces) }
        if !o.isEmpty { b["owner"] = o }
        return b
    }

    private func save() async {
        let body = changes
        if let d = await runner.run(session, success: String(localized: "Saved"), {
            try await ActionRunner.client(session).send(.updateSalon(detail.salon.id, body), as: SalonDetail.self)
        }) {
            saved(d)
            dismiss()
        }
    }

    private func row(_ label: LocalizedStringKey, _ text: Binding<String>, _ key: String,
                     keyboard: UIKeyboardType = .default, lowercase: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(text: text) { Text(label) }
                .keyboardType(keyboard)
                .textInputAutocapitalization(lowercase ? .never : .words)
                .frame(minHeight: Theme.minTouch)
            FieldError(runner: runner, field: key)
        }
    }
}

/// Monthly limit of the WhatsApp bot or the AI assistant: PATCH /admin/salons/{id}/limits.
struct LimitEditorView: View {
    enum Kind { case whatsapp, ai }
    let salonId: Int
    let kind: Kind
    /// Current limit (0 = no limit) and whether it is the salon's own.
    let current: Int?
    let ownLimit: Bool
    let saved: (SalonDetail) -> Void

    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var runner = ActionRunner()
    @State private var choice = 0 // 0 default, 1 no limit, 2 number
    @State private var number = 500

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $choice) {
                        Text("Platform default").tag(0)
                        Text("No limit").tag(1)
                        Text("A number").tag(2)
                    } label: { EmptyView() }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    if choice == 2 {
                        Stepper(value: $number, in: 0...100_000, step: 50) {
                            LabeledContent {
                                TextField("", value: $number, format: .number.locale(Locale(identifier: "en_US")))
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: 100)
                            } label: {
                                Text(kind == .whatsapp ? "Replies a month" : "Questions a month")
                            }
                        }
                    }
                } footer: {
                    Text("The platform default is set in More → WhatsApp bot / AI assistant on the website.")
                }
                Section {
                    ActionButton(title: "Save", runner: runner) { await save() }
                }
            }
            .navigationTitle(kind == .whatsapp ? "WhatsApp monthly limit" : "AI monthly limit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .actionErrorAlert(runner)
            .onAppear {
                if !ownLimit { choice = 0 } else if current == 0 { choice = 1 } else { choice = 2; number = current ?? 500 }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() async {
        let value: LimitChoice = choice == 0 ? .platformDefault : (choice == 1 ? .noLimit : .number(number))
        let ep: Endpoint = kind == .whatsapp ? .setLimits(salonId, whatsapp: value) : .setLimits(salonId, ai: value)
        if let d = await runner.run(session, success: String(localized: "Saved"), {
            try await ActionRunner.client(session).send(ep, as: SalonDetail.self)
        }) {
            saved(d)
            dismiss()
        }
    }
}

/// Change plan / cycle / paid until / own price / trial: PUT /admin/salons/{id}/subscription.
struct SubscriptionEditorView: View {
    let salonId: Int
    let current: Billing?
    let saved: (SubscriptionAnswer) -> Void

    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var runner = ActionRunner()
    @State private var form = SubscriptionForm()
    @State private var hasOwnPrice = false
    @State private var price: Double = 0
    @State private var plans = ScreenLoader<ItemList<Plan>>(.plans())
    @State private var filled = false

    var body: some View {
        NavigationStack {
            Form {
                if session.hasAccountTypes {
                    AccountTypeSection(form: $form, plans: plans.value?.items ?? [], runner: runner)
                    if form.type == .paid {
                        Section {
                            Toggle("Own price", isOn: $hasOwnPrice)
                            if hasOwnPrice {
                                LabeledContent("Price per cycle") {
                                    TextField("", value: $price, format: .number.precision(.fractionLength(0...2)).locale(Locale(identifier: "en_US")))
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                }
                                FieldError(runner: runner, field: "price")
                            }
                        }
                    }
                    Section {
                        ActionButton(title: "Save", runner: runner, enabled: form.isComplete) { await save() }
                    }
                } else {
                    legacySections
                }
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .interactiveDismissDisabled(runner.isRunning)
            .actionErrorAlert(runner)
            .task {
                if !filled {
                    filled = true
                    form = SubscriptionForm(from: current)
                    if session.hasAccountTypes { form.guessType() } else { form.type = nil }
                    hasOwnPrice = form.ownPrice != nil
                    price = form.ownPrice ?? current?.price?.amount ?? 0
                }
                await plans.load(session)
            }
        }
    }

    /// Before API 1.4: plan (0 = not billed), cycle, paid until, own price, trial.
    @ViewBuilder
    private var legacySections: some View {
                Section {
                    Picker("Plan", selection: $form.planId) {
                        Text("Not billed").tag(0)
                        ForEach(plans.value?.items ?? []) { p in
                            Text(verbatim: "\(p.name ?? "#\(p.id)") · \(p.priceMonth?.display ?? "")").tag(p.id)
                        }
                    }
                    FieldError(runner: runner, field: "plan_id")
                    if form.planId != 0 {
                        Picker("Cycle", selection: $form.cycle) {
                            Text("Monthly").tag("month")
                            Text("Yearly").tag("year")
                        }
                        DatePicker("Paid until", selection: $form.until, displayedComponents: .date)
                        FieldError(runner: runner, field: "until")
                        Toggle("Own price", isOn: $hasOwnPrice)
                        if hasOwnPrice {
                            LabeledContent("Price per cycle") {
                                TextField("", value: $price, format: .number.precision(.fractionLength(0...2)).locale(Locale(identifier: "en_US")))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                            }
                            FieldError(runner: runner, field: "price")
                        }
                        Toggle("Trial", isOn: $form.trial)
                        Toggle("Switch on the plan features", isOn: $form.applyFeatures)
                    }
                }
                Section {
                    ActionButton(title: "Save", runner: runner) { await save() }
                }
    }

    private func save() async {
        var f = form
        let priced = f.type.map { $0 == .paid } ?? (f.planId != 0)
        f.ownPrice = (hasOwnPrice && priced) ? price : nil
        if let a = await runner.run(session, success: String(localized: "Saved"), {
            try await ActionRunner.client(session).send(.setSubscription(salonId, f), as: SubscriptionAnswer.self)
        }) {
            saved(a)
            dismiss()
        }
    }
}

/// New invoice, or "Record a payment" (paid at once, moves paid-until): POST /admin/salons/{id}/invoices.
struct InvoiceEditorView: View {
    let salonId: Int
    let recordPayment: Bool
    var methods: [BillingSummary.Method] = []
    let saved: (InvoiceChange) -> Void

    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var runner = ActionRunner()
    @State private var form = InvoiceForm()
    @State private var ownAmount = false
    @State private var amount: Double = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $form.months, in: 1...36) {
                        LabeledContent("Months") { Text(verbatim: "\(form.months)").monospacedDigit() }
                    }
                    FieldError(runner: runner, field: "months")
                    Toggle("Own amount", isOn: $ownAmount)
                    if ownAmount {
                        LabeledContent("Amount") {
                            TextField("", value: $amount, format: .number.precision(.fractionLength(0...2)).locale(Locale(identifier: "en_US")))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        FieldError(runner: runner, field: "amount")
                    }
                } footer: {
                    if !ownAmount { Text("The amount comes from the salon's plan.") }
                }
                if recordPayment {
                    Section("Payment") {
                        MethodPicker(method: $form.method, methods: methods)
                        FieldError(runner: runner, field: "method")
                    }
                }
                Section("Note") {
                    TextField("Note", text: $form.note, axis: .vertical).lineLimit(1...4)
                }
                Section {
                    ActionButton(title: recordPayment ? "Record the payment" : "Create the invoice", runner: runner) { await save() }
                } footer: {
                    if recordPayment { Text("The salon's paid-until date moves forward.") }
                }
            }
            .navigationTitle(recordPayment ? "Record a payment" : "New invoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .interactiveDismissDisabled(runner.isRunning)
            .actionErrorAlert(runner)
        }
    }

    private func save() async {
        var f = form
        f.paid = recordPayment
        f.amount = ownAmount ? amount : nil
        if let a = await runner.run(session, success: recordPayment ? String(localized: "Payment recorded") : String(localized: "Invoice created"), {
            try await ActionRunner.client(session).send(.createInvoice(salonId: salonId, f), as: InvoiceChange.self)
        }) {
            saved(a)
            dismiss()
        }
    }
}

/// Cash · Whish · OMT · Bank transfer · Other (labels from the API when known).
struct MethodPicker: View {
    @Binding var method: PaymentMethod
    var methods: [BillingSummary.Method] = []

    var body: some View {
        Picker("Method", selection: $method) {
            ForEach(PaymentMethod.allCases, id: \.self) { m in
                Text(verbatim: methods.first(where: { $0.slug == m.rawValue })?.label ?? m.label).tag(m)
            }
        }
    }
}

extension PaymentMethod {
    var label: String {
        switch self {
        case .cash: return String(localized: "Cash")
        case .whish: return "Whish"
        case .omt: return "OMT"
        case .bank: return String(localized: "Bank transfer")
        case .other: return String(localized: "Other")
        }
    }
}

/// Delete a salon and ALL its data: a red screen, the user types the salon name, then holds the button.
struct DeleteSalonView: View {
    let salon: Salon
    let deleted: () -> Void

    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var runner = ActionRunner()
    @State private var typed = ""
    @State private var holding = false
    @State private var progress: CGFloat = 0

    private var matches: Bool {
        typed.trimmingCharacters(in: .whitespaces).lowercased() == salon.name.trimmingCharacters(in: .whitespaces).lowercased()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label("This cannot be undone", systemImage: "exclamationmark.octagon.fill")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text("Deleting “\(salon.name)” removes the salon and all its data: visits, customers, appointments, money. The owner account is deleted too, unless the owner has other branches.")
                        .foregroundStyle(.white.opacity(0.92))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Type the salon name to confirm:").font(.subheadline.bold()).foregroundStyle(.white)
                        Text(verbatim: salon.name).font(.headline.monospaced()).foregroundStyle(.white)
                        TextField("", text: $typed, prompt: Text(verbatim: salon.name).foregroundStyle(.white.opacity(0.5)))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.15)))
                            .foregroundStyle(.white)
                        if runner.error?.field == "confirm" || runner.error?.code == "smapi_confirm" {
                            Text(verbatim: runner.error?.userMessage ?? "").font(.footnote.bold()).foregroundStyle(.white)
                        }
                    }
                    holdButton
                        .padding(.top, 8)
                    Text("Keep your finger on the button for 2 seconds.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(24)
            }
            .background(Color(red: 0.62, green: 0.08, blue: 0.11).ignoresSafeArea())
            .navigationTitle("Delete salon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.tint(.white) } }
            .interactiveDismissDisabled(runner.isRunning)
            .alert(Text("It did not work"),
                   isPresented: Binding(get: { runner.error != nil && runner.error?.code != "smapi_confirm" }, set: { if !$0 { runner.error = nil } }),
                   actions: { Button("OK", role: .cancel) { runner.error = nil } },
                   message: { Text(verbatim: runner.error?.userMessage ?? "") })
        }
    }

    private var holdButton: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 14).fill(.white.opacity(matches ? 1 : 0.35))
            RoundedRectangle(cornerRadius: 14).fill(Theme.red.opacity(0.35))
                .frame(maxWidth: .infinity)
                .scaleEffect(x: progress, y: 1, anchor: .leading)
            HStack {
                Spacer()
                if runner.isRunning { ProgressView().tint(Theme.red) }
                Text("Hold to delete").bold().foregroundStyle(Theme.red)
                Spacer()
            }
        }
        .frame(height: 56)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 2, maximumDistance: 40) {
            Task { await delete() }
        } onPressingChanged: { pressing in
            guard matches, !runner.isRunning else { return }
            withAnimation(pressing ? .linear(duration: 2) : .easeOut(duration: 0.2)) { progress = pressing ? 1 : 0 }
        }
        .disabled(!matches || runner.isRunning)
        .accessibilityLabel(Text("Hold to delete"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { Task { await delete() } }
    }

    private func delete() async {
        guard matches else { return }
        let name = typed.trimmingCharacters(in: .whitespaces)
        if let r = await runner.run(session, success: String(localized: "Salon deleted"), {
            try await ActionRunner.client(session).send(.deleteSalon(salon.id, confirm: name), as: DeletedSalon.self)
        }), r.deleted {
            dismiss()
            deleted()
        } else {
            progress = 0
        }
    }
}
