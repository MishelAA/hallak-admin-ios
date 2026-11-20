import SwiftUI
import UIKit

/// Mark an unpaid invoice paid (method + note): POST /admin/invoices/{id}/pay. Moves paid-until forward.
struct PayInvoiceView: View {
    let invoice: Invoice
    var methods: [BillingSummary.Method] = []
    let saved: (InvoiceChange) -> Void

    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var runner = ActionRunner()
    @State private var method = PaymentMethod.cash
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    InfoRow(label: "Invoice", value: invoice.title)
                    InfoRow(label: "Salon", value: invoice.salonName)
                    if let a = invoice.amount { LabeledContent { MoneyText(money: a).bold() } label: { Text("Amount") } }
                }
                Section("Payment") {
                    MethodPicker(method: $method, methods: methods.isEmpty ? loadedMethods : methods)
                    FieldError(runner: runner, field: "method")
                    TextField("Note", text: $note, axis: .vertical).lineLimit(1...4)
                }
                Section {
                    ActionButton(title: "Mark paid", runner: runner) { await pay() }
                } footer: {
                    Text("The salon's paid-until date moves forward.")
                }
            }
            .navigationTitle("Mark paid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .interactiveDismissDisabled(runner.isRunning)
            .actionErrorAlert(runner)
            .task {
                guard methods.isEmpty, let c = session.client,
                      let s = try? await c.fetch(.billingSummary, as: BillingSummary.self) else { return }
                loadedMethods = s.value.methods ?? []
            }
        }
        .presentationDetents([.medium, .large])
    }

    @State private var loadedMethods: [BillingSummary.Method] = []

    private func pay() async {
        let m = method, n = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let r = await runner.run(session, success: String(localized: "Payment recorded"), {
            try await ActionRunner.client(session).send(.payInvoice(invoice.id, method: m, note: n), as: InvoiceChange.self)
        }) {
            saved(r)
            dismiss()
        }
    }
}

/// Cancel an unpaid invoice (after a confirmation): POST /admin/invoices/{id}/void.
@MainActor
func voidInvoice(_ invoice: Invoice, runner: ActionRunner, session: AppSession) async -> InvoiceChange? {
    await runner.run(session, success: String(localized: "Invoice cancelled")) {
        try await ActionRunner.client(session).send(.voidInvoice(invoice.id), as: InvoiceChange.self)
    }
}

/// New plan (POST /admin/plans) or change a plan (PATCH /admin/plans/{id}).
struct PlanEditorView: View {
    var plan: Plan?
    let features: [Feature]
    let saved: (Plan) -> Void

    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var runner = ActionRunner()
    @State private var form = PlanForm()
    @State private var filled = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(text: $form.name) { Text("Plan name") }.frame(minHeight: Theme.minTouch)
                    FieldError(runner: runner, field: "name")
                    price("Price per month", $form.priceMonth, "price_month")
                    price("Price per year", $form.priceYear, "price_year")
                    Toggle("Active (can be chosen for new subscriptions)", isOn: $form.active)
                }
                if !features.isEmpty {
                    Section("Features in this plan") {
                        ForEach(features) { f in
                            Toggle(isOn: Binding(get: { form.features.contains(f.slug) },
                                                 set: { on in if on { form.features.insert(f.slug) } else { form.features.remove(f.slug) } })) {
                                Text(verbatim: f.label ?? f.slug)
                            }
                        }
                    }
                }
                Section("Note") {
                    TextField("Note", text: $form.note, axis: .vertical).lineLimit(1...4)
                }
                Section {
                    ActionButton(title: plan == nil ? "Create the plan" : "Save", runner: runner,
                                 enabled: !form.name.trimmingCharacters(in: .whitespaces).isEmpty) { await save() }
                }
            }
            .navigationTitle(plan == nil ? "New plan" : "Edit plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .interactiveDismissDisabled(runner.isRunning)
            .actionErrorAlert(runner)
            .onAppear {
                if !filled, let plan { form = PlanForm(from: plan) }
                filled = true
            }
        }
    }

    private func price(_ label: LocalizedStringKey, _ value: Binding<Double>, _ key: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent {
                TextField("", value: value, format: .number.precision(.fractionLength(0...2)).locale(Locale(identifier: "en_US")))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            } label: {
                Text(label)
            }
            FieldError(runner: runner, field: key)
        }
    }

    private func save() async {
        let f = form
        if let r = await runner.run(session, success: String(localized: "Saved"), {
            let c = try ActionRunner.client(session)
            if let plan { return try await c.send(.updatePlan(plan.id, f), as: PlanChange.self) }
            return try await c.send(.createPlan(f), as: PlanChange.self)
        }) {
            saved(r.plan)
            dismiss()
        }
    }
}
