import SwiftUI

/// The account type chip (API 1.4) on salon rows and the salon header, next to the billing status.
struct TypeChip: View {
    let billing: Billing?

    var body: some View {
        if let t = billing?.type, t != .unknown {
            StatusBadge(text: billing?.typeLabel ?? t.label, color: t.color)
        }
    }
}

/// "Account" in New salon and Subscription: Paid · Free trial · Free · Demo, and only the fields that type needs.
struct AccountTypeSection: View {
    @Binding var form: SubscriptionForm
    let plans: [Plan]
    let runner: ActionRunner

    private var type: AccountType { form.type ?? .paid }

    var body: some View {
        Section {
            Picker(selection: Binding(get: { type }, set: { form.type = $0 })) {
                ForEach(AccountType.choices) { Text(verbatim: $0.label).tag($0) }
            } label: { Text("Account") }
            .pickerStyle(.segmented)

            switch type {
            case .paid:
                planPicker("Plan", none: "Choose")
                AccountError(runner: runner, code: "smb_plan", field: "plan_id", text: String(localized: "A paid salon needs a plan"))
                Picker("Cycle", selection: $form.cycle) {
                    Text("Monthly").tag("month")
                    Text("Yearly").tag("year")
                }
                DatePicker("Paid until", selection: $form.until, displayedComponents: .date)
                FieldError(runner: runner, field: "until")
                Toggle("Switch on the plan features", isOn: $form.applyFeatures)
            case .trial:
                Picker("Trial length", selection: $form.trialLength) {
                    ForEach(TrialLength.allCases) { Text(verbatim: $0.label).tag($0.rawValue) }
                }
                AccountError(runner: runner, code: "smb_trial", field: "trial_length",
                             text: String(localized: "Choose how long the free trial lasts"))
                planPicker("Plan after the trial", none: "None")
                if form.planId != 0 {
                    Toggle("Switch on the plan features", isOn: $form.applyFeatures)
                }
            case .free, .demo, .unknown:
                EmptyView()
            }
            AccountError(runner: runner, code: "smb_type", field: "type", text: nil)
        } header: {
            Text("Account")
        } footer: {
            Text(Self.explain(type))
        }
    }

    private func planPicker(_ title: LocalizedStringKey, none: LocalizedStringKey) -> some View {
        Picker(selection: $form.planId) {
            Text(none).tag(0)
            ForEach(plans) { p in
                Text(verbatim: "\(p.name ?? "#\(p.id)") · \(p.priceMonth?.display ?? "")").tag(p.id)
            }
        } label: { Text(title) }
    }

    static func explain(_ t: AccountType) -> String {
        switch t {
        case .paid: return String(localized: "Billed on its plan.")
        case .trial: return String(localized: "Free until the end of the trial, then billed on the plan. The first payment makes it paid.")
        case .free: return String(localized: "Never billed, never suspended.")
        case .demo: return String(localized: "Never billed, and left out of the business numbers.")
        case .unknown: return ""
        }
    }
}

/// Error under an Account field: our own words for a known code, else the server message for that field.
struct AccountError: View {
    let runner: ActionRunner
    let code: String
    let field: String
    let text: String?

    var body: some View {
        if let e = runner.error, e.code == code || e.field == field {
            Text(verbatim: e.code == code ? (text ?? e.userMessage) : e.userMessage)
                .font(.footnote)
                .foregroundStyle(Theme.red)
        }
    }
}

/// Home: a small row of the 4 account type counts (overview.types). Each opens Salons filtered by that type.
struct AccountTypesRow: View {
    let types: Overview.Types
    var open: (AccountType) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "person.crop.rectangle.stack").foregroundStyle(Theme.brandRed).accessibilityHidden(true)
                Text("Account types").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.inkSecondary)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: typeSize.isAccessibilitySize ? 2 : 4), spacing: 6) {
                cell(.paid, types.paid)
                cell(.trial, types.trial)
                cell(.free, types.free)
                cell(.demo, types.demo)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).fill(Theme.card))
    }

    private func cell(_ t: AccountType, _ value: Int?) -> some View {
        Button {
            Haptics.tap()
            open(t)
        } label: {
            VStack(spacing: 2) {
                Text(verbatim: "\(value ?? 0)")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(t.color)
                Text(verbatim: t.label)
                    .font(.caption2)
                    .foregroundStyle(Theme.inkSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: Theme.minTouch)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 10).fill(t.color.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
