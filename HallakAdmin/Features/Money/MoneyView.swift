import SwiftUI

/// Money: GET /admin/billing/summary, /admin/invoices, /admin/plans.
struct MoneyView: View {
    enum Part: Hashable { case invoices, plans }
    enum InvoiceFilter: String, CaseIterable, Identifiable {
        case unpaid, paid, void, all
        var id: String { rawValue }
        var label: LocalizedStringKey {
            switch self {
            case .unpaid: return "Unpaid"
            case .paid: return "Paid"
            case .void: return "Cancelled"
            case .all: return "All"
            }
        }
        var query: [String: String] { self == .all ? [:] : ["status": rawValue] }
    }

    @Environment(AppSession.self) private var session
    @State private var summary = ScreenLoader<BillingSummary>(.billingSummary)
    @State private var invoices = PagedLoader<Invoice>(filters: ["status": "unpaid"]) { .invoices($0) }
    @State private var plans = ScreenLoader<ItemList<Plan>>(.plans())
    @State private var features = ScreenLoader<ItemList<Feature>>(.features)
    @State private var part = Part.invoices
    @State private var filter = InvoiceFilter.unpaid
    @State private var runner = ActionRunner()
    @State private var paying: Invoice?
    @State private var cancelling: Invoice?
    @State private var editingPlan: Plan?
    @State private var newPlan = false

    var body: some View {
        Group {
            if session.me?.hasBilling == false || summary.error?.behaviour == .pluginOff {
                ScrollView {
                    EmptyState(title: "Billing is off", message: "The Hallak Billing plugin is not active on the site.", image: "BarberBye")
                }
            } else {
                list
            }
        }
        .background(Theme.background)
        .navigationTitle("Money")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                UpdatedLabel(generatedAt: summary.answer?.generatedAt, isLoading: summary.isLoading || invoices.isLoading)
            }
        }
        .refreshable { await refresh() }
        .task { await summary.load(session) }
        .onChange(of: session.dataVersion) { _, _ in Task { await refresh() } }
        .actionErrorAlert(runner)
        .sheet(item: $paying) { inv in PayInvoiceView(invoice: inv, methods: summary.value?.methods ?? []) { _ in } }
        .sheet(item: $editingPlan) { p in PlanEditorView(plan: p, features: features.value?.items ?? []) { _ in Task { await plans.refresh(session) } } }
        .sheet(isPresented: $newPlan) { PlanEditorView(plan: nil, features: features.value?.items ?? []) { _ in Task { await plans.refresh(session) } } }
        .confirmationDialog("Cancel this invoice?", isPresented: Binding(get: { cancelling != nil }, set: { if !$0 { cancelling = nil } }),
                            titleVisibility: .visible, presenting: cancelling) { inv in
            Button("Cancel invoice \(inv.title)", role: .destructive) { Task { _ = await voidInvoice(inv, runner: runner, session: session); cancelling = nil } }
            Button("Keep it", role: .cancel) {}
        } message: { _ in
            Text("The invoice stays in the list as cancelled.")
        }
        .task(id: filter) { await invoices.setFilters(filter.query, session) }
        .task(id: part) {
            if part == .plans {
                await plans.load(session)
                await features.load(session)
            }
        }
    }

    private func refresh() async {
        await summary.refresh(session)
        if part == .invoices { await invoices.reload(session) } else { await plans.refresh(session) }
    }

    private var list: some View {
        List {
            if summary.isOffline || invoices.isOffline {
                OfflineBanner(time: Formatters.updatedTime(summary.answer?.generatedAt) ?? "–") { Task { await refresh() } }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            topCards
            dueSoon
            Section {
                Picker(selection: $part) {
                    Text("Invoices").tag(Part.invoices)
                    Text("Plans").tag(Part.plans)
                } label: { EmptyView() }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            if part == .invoices { invoiceSection } else { planSection }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var topCards: some View {
        switch summary.state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, minHeight: 100).listRowBackground(Color.clear)
        case .failed(let e):
            ErrorView(error: e) { Task { await summary.refresh(session) } }.listRowBackground(Color.clear)
        case .loaded(let a):
            let s = a.value
            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    StatCard(title: "Expected every month (MRR)", systemImage: "chart.line.uptrend.xyaxis", value: s.mrr?.display)
                    StatCard(title: "Paid this month", systemImage: "checkmark.circle", value: s.paidThisMonth?.display, tint: Theme.green)
                    StatCard(title: "Unpaid", systemImage: "exclamationmark.circle", value: s.unpaid?.amount?.display,
                             tint: (s.unpaid?.count ?? 0) > 0 ? Theme.red : Theme.ink,
                             action: { filter = .unpaid; part = .invoices }) {
                        Text("\(s.unpaid?.count ?? 0) invoices")
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
    }

    @ViewBuilder
    private var dueSoon: some View {
        if let due = summary.value?.dueSoon, !due.isEmpty {
            Section {
                ForEach(due) { d in
                    NavigationLink(value: AppRoute.salon(id: d.salonId, name: d.salonName)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: d.salonName ?? "#\(d.salonId)").font(.subheadline.weight(.semibold))
                                if let until = d.until {
                                    Text(verbatim: Formatters.show(until, .day)).font(.caption).foregroundStyle(Theme.inkSecondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                StatusBadge(text: d.status?.label ?? "–", color: Theme.color(for: d.status))
                                if let left = Formatters.daysLeft(d.daysLeft) {
                                    Text(verbatim: left)
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle((d.daysLeft ?? 0) < 0 ? Theme.red : Theme.inkSecondary)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            } header: {
                Text("Due soon / late")
            } footer: {
                if let g = summary.value?.graceDays { Text("Salons keep working \(g) days after the date.") }
            }
        }
    }

    @ViewBuilder
    private var invoiceSection: some View {
        Section {
            Picker(selection: $filter) {
                ForEach(InvoiceFilter.allCases) { Text($0.label).tag($0) }
            } label: { Text("Show") }
            .pickerStyle(.menu)

            if invoices.items.isEmpty {
                if let e = invoices.error {
                    ErrorView(error: e) { Task { await invoices.reload(session) } }
                } else if invoices.isEmpty {
                    EmptyState(title: filter == .unpaid ? "Nothing unpaid" : "No invoices", image: filter == .unpaid ? "BarberHappy" : "BarberWave")
                } else {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 80)
                }
            }
            ForEach(invoices.items) { inv in
                NavigationLink(value: AppRoute.invoice(id: inv.id)) { InvoiceRow(invoice: inv) }
                    .task { await invoices.loadMoreIfNeeded(after: inv, session) }
                    .swipeActions {
                        if session.canWrite, inv.status == .unpaid {
                            Button("Paid") { paying = inv }.tint(Theme.green)
                            Button("Cancel") { cancelling = inv }.tint(Theme.red)
                        }
                    }
            }
            if invoices.list.canLoadMore, !invoices.items.isEmpty {
                HStack { Spacer(); ProgressView(); Spacer() }
            }
        } header: {
            if invoices.loadedOnce, !invoices.items.isEmpty { Text("\(invoices.list.total) invoices") }
        }
    }

    @ViewBuilder
    private var planSection: some View {
        switch plans.state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, minHeight: 80).listRowBackground(Color.clear)
        case .failed(let e):
            ErrorView(error: e) { Task { await plans.refresh(session) } }.listRowBackground(Color.clear)
        case .loaded(let a):
            if session.canWrite {
                Section { Button { newPlan = true } label: { Label("New plan", systemImage: "plus.circle") } }
            }
            ForEach(a.value.items) { plan in
                Section {
                    if session.canWrite {
                        Button { editingPlan = plan } label: { PlanCard(plan: plan, featureNames: featureNames) }
                            .buttonStyle(.plain)
                    } else {
                        PlanCard(plan: plan, featureNames: featureNames)
                    }
                }
            }
        }
    }

    private var featureNames: [String: String] {
        Dictionary((features.value?.items ?? []).map { ($0.slug, $0.label ?? $0.slug) }, uniquingKeysWith: { a, _ in a })
    }
}

extension BillingStatus {
    /// Plain words (the API's status_label is used when it is there).
    var label: String {
        switch self {
        case .free: return String(localized: "Not billed")
        case .trial: return String(localized: "Trial")
        case .active: return String(localized: "Paid")
        case .grace: return String(localized: "Payment due")
        case .overdue: return String(localized: "Overdue")
        case .unknown: return String(localized: "Other")
        }
    }
}

/// One plan: name, monthly and yearly price, features, active.
struct PlanCard: View {
    let plan: Plan
    var featureNames: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(verbatim: plan.name ?? "#\(plan.id)").font(.headline)
                Spacer()
                StatusBadge(text: plan.active == false ? String(localized: "Not active") : String(localized: "Active"),
                            color: plan.active == false ? Theme.grey : Theme.green)
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Monthly").font(.caption).foregroundStyle(Theme.inkSecondary)
                    MoneyText(money: plan.priceMonth).font(.title3.bold())
                }
                VStack(alignment: .leading) {
                    Text("Yearly").font(.caption).foregroundStyle(Theme.inkSecondary)
                    MoneyText(money: plan.priceYear).font(.title3.bold())
                }
            }
            if let f = plan.features, !f.isEmpty {
                Text(verbatim: f.map { featureNames[$0] ?? $0 }.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
            }
            if let note = plan.note, !note.isEmpty {
                Text(verbatim: note).font(.footnote).italic().foregroundStyle(Theme.inkSecondary)
            }
        }
        .padding(.vertical, 4)
        .opacity(plan.active == false ? 0.6 : 1)
        .accessibilityElement(children: .combine)
    }
}
