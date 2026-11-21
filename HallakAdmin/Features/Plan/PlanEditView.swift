import SwiftUI

/// Edit targets (pencil): per year, budget shares (must add up to 100), checklist goals, renewal target.
/// Saves only the parts that changed (PATCH /admin/plan). "Back to the original plan" = {"reset": true}.
struct PlanEditView: View {
    let plan: BusinessPlan
    let saved: (BusinessPlan) -> Void

    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var runner = ActionRunner()
    @State private var form: PlanTargetsForm
    @State private var year: Int
    @State private var confirmReset = false
    private let original: PlanTargetsForm

    init(plan: BusinessPlan, saved: @escaping (BusinessPlan) -> Void) {
        self.plan = plan
        self.saved = saved
        let f = PlanTargetsForm(from: plan)
        original = f
        _form = State(initialValue: f)
        _year = State(initialValue: plan.currentYear?.year ?? f.years.keys.min() ?? 0)
    }

    private var changes: JSONBody { form.body(comparedTo: original) }

    var body: some View {
        NavigationStack {
            Form {
                if plan.customized == true {
                    Section {
                        Label {
                            if let at = plan.changed?.at, let by = plan.changed?.by {
                                Text("Targets changed on \(Formatters.show(at)) by \(by)")
                            } else {
                                Text("Targets changed from the original plan")
                            }
                        } icon: { Image(systemName: "pencil.circle") }
                        .font(.footnote)
                    }
                }

                if let e = runner.error, e.field != nil {
                    Section { Text(verbatim: e.userMessage).foregroundStyle(Theme.red) }
                }

                yearSection
                budgetSection
                goalsSection

                Section {
                    numberField("Renewal target", $form.renewal, suffix: "%")
                } footer: {
                    Text("Of last year's paying salons, how many should pay again.")
                }

                Section {
                    ActionButton(title: "Save", runner: runner, enabled: !changes.isEmpty && form.budgetOK) { await save() }
                }

                if plan.customized == true {
                    Section {
                        Button(role: .destructive) { confirmReset = true } label: {
                            Label("Back to the original plan", systemImage: "arrow.uturn.backward")
                        }
                        .disabled(runner.isRunning)
                    }
                }
            }
            .navigationTitle("Edit targets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .confirmationDialog(Text("Go back to the original plan?"), isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Back to the original plan", role: .destructive) { Task { await reset() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All your changes to the targets, budget and goals are removed.")
            }
            .actionErrorAlert(runner)
            .interactiveDismissDisabled(runner.isRunning)
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var yearSection: some View {
        let years = form.years.keys.sorted()
        Section {
            if years.count > 1 {
                Picker(selection: $year) {
                    ForEach(years, id: \.self) { Text(verbatim: String($0)).tag($0) }
                } label: { Text("Year") }
                .pickerStyle(.segmented)
            }
            numberField("New salons", yearBinding.new)
            numberField("Renewed salons", yearBinding.renewed)
            numberField("Paying salons at the end of the year", yearBinding.total)
            LabeledContent {
                TextField("", value: yearBinding.price, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 110)
            } label: { Text("Price per salon a year") }
        } header: {
            Text(verbatim: String(year))
        }

        Section {
            ForEach(0..<4, id: \.self) { i in
                HStack {
                    Text(verbatim: "Q\(i + 1)").bold().frame(width: 32, alignment: .leading)
                    Text("New").foregroundStyle(Theme.inkSecondary)
                    intBox(quarter(\.quarters, i))
                    Spacer()
                    Text("Paying").foregroundStyle(Theme.inkSecondary)
                    intBox(quarter(\.cumulative, i))
                }
            }
        } header: {
            Text("Quarters")
        } footer: {
            Text("New = new salons in the quarter. Paying = paying salons at the end of the quarter (milestone).")
        }
    }

    @ViewBuilder
    private var budgetSection: some View {
        if !form.budget.isEmpty {
            Section {
                ForEach(PlanTargetsForm.budgetSlugs.filter { form.budget[$0] != nil }, id: \.self) { slug in
                    numberFieldVerbatim(budgetLabel(slug), Binding(get: { form.budget[slug] ?? 0 }, set: { form.budget[slug] = $0 }), suffix: "%")
                }
                LabeledContent {
                    Text(verbatim: "\(form.budgetSum)%")
                        .bold().monospacedDigit()
                        .foregroundStyle(form.budgetOK ? Theme.green : Theme.red)
                } label: { Text("Total") }
            } header: {
                Text("Budget shares")
            } footer: {
                if !form.budgetOK { Text("The shares must add up to 100.").foregroundStyle(Theme.red) }
            }
        }
    }

    @ViewBuilder
    private var goalsSection: some View {
        let slugs = PlanTargetsForm.goalSlugs.filter { form.goals[$0] != nil }
        if !slugs.isEmpty {
            Section("Monthly checklist goals") {
                ForEach(slugs, id: \.self) { slug in
                    numberFieldVerbatim(goalLabel(slug), Binding(get: { form.goals[slug] ?? 0 }, set: { form.goals[slug] = $0 }))
                }
            }
        }
    }

    // MARK: Fields

    private var yearBinding: Binding<PlanTargetsForm.Year> {
        let y = year
        return Binding(get: { form.years[y] ?? PlanTargetsForm.Year() }, set: { form.years[y] = $0 })
    }

    private func quarter(_ path: WritableKeyPath<PlanTargetsForm.Year, [Int]>, _ i: Int) -> Binding<Int> {
        let y = year
        return Binding(
            get: { (form.years[y]?[keyPath: path] ?? []).indices.contains(i) ? form.years[y]![keyPath: path][i] : 0 },
            set: { v in
                var f = form.years[y] ?? PlanTargetsForm.Year()
                var list = f[keyPath: path]
                while list.count < 4 { list.append(0) }
                list[i] = max(0, v)
                f[keyPath: path] = list
                form.years[y] = f
            }
        )
    }

    private func numberField(_ title: LocalizedStringKey, _ value: Binding<Int>, suffix: String = "") -> some View {
        LabeledContent {
            HStack(spacing: 2) {
                intBox(value)
                if !suffix.isEmpty { Text(verbatim: suffix).foregroundStyle(Theme.inkSecondary) }
            }
        } label: { Text(title) }
    }

    private func numberFieldVerbatim(_ title: String, _ value: Binding<Int>, suffix: String = "") -> some View {
        LabeledContent {
            HStack(spacing: 2) {
                intBox(value)
                if !suffix.isEmpty { Text(verbatim: suffix).foregroundStyle(Theme.inkSecondary) }
            }
        } label: { Text(verbatim: title) }
    }

    private func intBox(_ value: Binding<Int>) -> some View {
        TextField("", value: value, format: .number)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .frame(width: 64)
            .environment(\.layoutDirection, .leftToRight)
    }

    private func budgetLabel(_ slug: String) -> String {
        plan.budget?.items?.first { $0.slug == slug }?.label ?? slug
    }

    private func goalLabel(_ slug: String) -> String {
        plan.checklist?.items.first { $0.slug == slug }?.label ?? slug
    }

    // MARK: Actions

    private func save() async {
        let body = changes
        guard !body.isEmpty else { return }
        let answer = await runner.run(session, success: String(localized: "Plan saved")) {
            try await ActionRunner.client(session).send(.updateBusinessPlan(body), as: BusinessPlan.self)
        }
        if let answer {
            saved(answer)
            dismiss()
        }
    }

    private func reset() async {
        let answer = await runner.run(session, success: String(localized: "Back to the original plan")) {
            try await ActionRunner.client(session).send(.resetBusinessPlan, as: BusinessPlan.self)
        }
        if let answer {
            saved(answer)
            dismiss()
        }
    }
}
