import Charts
import SwiftUI

/// More → Business plan (API 1.3): the plan 2027–2029 next to the real numbers. One request: GET /admin/plan.
struct BusinessPlanView: View {
    @Environment(AppSession.self) private var session
    @State private var loader = ScreenLoader<BusinessPlan>(.businessPlan)
    @State private var selectedYear: Int?
    @State private var editing = false

    var body: some View {
        Group {
            switch loader.state {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let error):
                ErrorView(error: error) { Task { await loader.refresh(session) } }
            case .loaded(let answer):
                content(answer.value)
            }
        }
        .background(Theme.background)
        .navigationTitle("Business plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                UpdatedLabel(generatedAt: loader.answer?.generatedAt, isLoading: loader.isLoading)
            }
            if session.canWrite, loader.value != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editing = true } label: { Image(systemName: "pencil") }
                        .accessibilityLabel(Text("Edit targets"))
                }
            }
        }
        .sheet(isPresented: $editing) {
            if let plan = loader.value {
                PlanEditView(plan: plan) { loader.set($0) }
            }
        }
        .refreshable { await loader.refresh(session) }
        .task { await loader.load(session) }
    }

    @ViewBuilder
    private func content(_ plan: BusinessPlan) -> some View {
        let year = plan.years?.first { $0.year == selectedYear } ?? plan.currentYear
        List {
            if loader.isOffline {
                OfflineBanner(time: Formatters.updatedTime(loader.answer?.generatedAt) ?? "–") {
                    Task { await loader.refresh(session) }
                }
                .listRowBackground(Color.clear)
            }

            header(plan)

            if let years = plan.years, years.count > 1 {
                Section {
                    Picker(selection: Binding(get: { year?.year ?? 0 }, set: { selectedYear = $0 })) {
                        ForEach(years) { y in Text(verbatim: String(y.year)).tag(y.year) }
                    } label: { Text("Year") }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }
            }

            if let year {
                PlanYearSections(year: year, renewalTarget: plan.renewalTarget)
            }

            if let kpis = plan.kpis, !kpis.isEmpty {
                Section("Key numbers") {
                    ForEach(kpis) { KPIRow(kpi: $0) }
                }
            }

            renewals(plan.renewalsDue ?? [])

            if let checklist = plan.checklist {
                PlanChecklistSection(initial: checklist)
            }

            if let roadmap = plan.roadmap, !roadmap.isEmpty {
                Section("Roadmap") {
                    ForEach(roadmap) { RoadmapRow(item: $0) }
                }
            }

            if let budget = plan.budget, let items = budget.items, !items.isEmpty {
                BudgetSection(budget: budget, items: items)
            }

            if let tiers = plan.tiers, let items = tiers.items, !items.isEmpty {
                Section {
                    ForEach(items) { t in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(verbatim: t.name).font(.headline)
                                Spacer()
                                MoneyText(money: t.price).font(.headline)
                            }
                            if let p = t.positioning, !p.isEmpty {
                                Text(verbatim: p).font(.footnote).foregroundStyle(Theme.inkSecondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("Pricing ideas")
                } footer: {
                    if let note = tiers.note, !note.isEmpty { Text(verbatim: note) }
                }
            }

            footer(plan)
        }
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func header(_ plan: BusinessPlan) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                if let t = plan.title { Text(verbatim: t).font(.title3.bold()) }
                if let s = plan.subtitle, !s.isEmpty { Text(verbatim: s).font(.subheadline).foregroundStyle(Theme.inkSecondary) }
                if let s = plan.summary, !s.isEmpty { Text(verbatim: s).font(.footnote) }
                if let t = plan.threeYear, let target = t.targetRevenue {
                    HStack(spacing: 4) {
                        Text("3 years:")
                        MoneyText(money: t.actualRevenue).bold()
                        Text("of")
                        MoneyText(money: target)
                    }
                    .font(.footnote)
                }
                if plan.billingActive == false {
                    Label("Billing is off: the real numbers stay at 0.", systemImage: "exclamationmark.triangle")
                        .font(.footnote).foregroundStyle(Theme.orange)
                }
                if plan.customized == true {
                    Label {
                        Text(changedText(plan.changed))
                    } icon: { Image(systemName: "pencil.circle") }
                    .font(.footnote).foregroundStyle(Theme.blue)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func changedText(_ c: BusinessPlan.Changed?) -> String {
        let at = c?.at.map { Formatters.show($0) }
        switch (at, c?.by) {
        case let (at?, by?): return String(localized: "Targets changed on \(at) by \(by)")
        case let (at?, nil): return String(localized: "Targets changed on \(at)")
        default: return String(localized: "Targets changed from the original plan")
        }
    }

    @ViewBuilder
    private func renewals(_ items: [RenewalDue]) -> some View {
        Section {
            if items.isEmpty {
                Text("No salon to renew in the next 60 days.").foregroundStyle(Theme.inkSecondary)
            }
            ForEach(items) { r in RenewalRow(renewal: r) }
        } header: {
            Text("Renew soon")
        } footer: {
            Text("Contact salons 60 days before their paid time ends.")
        }
    }

    @ViewBuilder
    private func footer(_ plan: BusinessPlan) -> some View {
        if let a = plan.assumptions, !a.isEmpty {
            Section("Assumptions") {
                ForEach(a, id: \.self) { Text(verbatim: $0).font(.footnote) }
            }
        }
        if let r = plan.recommendation, !r.isEmpty {
            Section("Recommendation") { Text(verbatim: r).font(.footnote) }
        }
        if let n = plan.note, !n.isEmpty {
            Section { Text(verbatim: n).font(.footnote).foregroundStyle(Theme.inkSecondary) }
        }
    }
}

// MARK: - Status

extension PlanStatus {
    var label: String {
        switch self {
        case .onTrack: return String(localized: "On track")
        case .behind: return String(localized: "Behind")
        case .reached: return String(localized: "Reached")
        case .missed: return String(localized: "Missed")
        case .notStarted: return String(localized: "Starts 1 Jan")
        case .noBilling: return String(localized: "Billing is off")
        case .unknown: return "–"
        }
    }

    var color: Color {
        switch self {
        case .onTrack, .reached: return Theme.green
        case .behind: return Theme.orange
        case .missed: return Theme.red
        case .notStarted, .noBilling, .unknown: return Theme.grey
        }
    }
}

/// The big ring: paying salons of the target, colored by status.
struct ProgressRing: View {
    let fraction: Double
    let color: Color
    let value: String
    let caption: LocalizedStringKey
    var size: CGFloat = 132
    var reached = false

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: 12)
            Circle()
                .trim(from: 0, to: max(0.001, fraction))
                .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                if reached {
                    Image(systemName: "checkmark").font(.headline.bold()).foregroundStyle(color)
                }
                Text(verbatim: value)
                    .font(.title2.bold().monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .environment(\.layoutDirection, .leftToRight)
                Text(caption).font(.caption).foregroundStyle(Theme.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
            }
            .padding(.horizontal, 18)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - One year

struct PlanYearSections: View {
    let year: PlanYear
    let renewalTarget: Int?

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                if let n = year.name { Text(verbatim: n).font(.headline) }
                if let o = year.objective, !o.isEmpty { Text(verbatim: o).font(.footnote).foregroundStyle(Theme.inkSecondary) }
                HStack {
                    Spacer()
                    ProgressRing(fraction: year.fraction, color: year.status.color,
                                 value: "\(year.actual?.totalPaying ?? 0) / \(year.targets?.total ?? 0)",
                                 caption: "paying salons", reached: year.status == .reached)
                    Spacer()
                }
                .padding(.vertical, 6)
                HStack {
                    Spacer()
                    StatusBadge(text: year.status.label, color: year.status.color)
                    if let e = year.progress?.expectedNow, year.status == .behind || year.status == .onTrack {
                        Text("Expected now: \(e)").font(.caption).foregroundStyle(Theme.inkSecondary)
                    }
                    Spacer()
                }
            }
            .padding(.vertical, 4)

            LabeledContent {
                HStack(spacing: 4) {
                    MoneyText(money: year.actual?.revenue).bold()
                    Text("of")
                    MoneyText(money: year.targets?.revenue)
                }
            } label: { Text("Revenue") }
            vs("New salons", year.actual?.new, year.targets?.new)
            vs("Renewed salons", year.actual?.renewed, year.targets?.renewed)
            LabeledContent {
                Text(verbatim: "\(year.actual?.renewalRate.map { "\($0)%" } ?? "–") / \(renewalTarget.map { "\($0)%" } ?? "–")")
                    .monospacedDigit()
                    .environment(\.layoutDirection, .leftToRight)
            } label: { Text("Renewal rate (goal)") }
        } header: {
            Text(verbatim: String(year.year))
        }

        if let quarters = year.quarters, !quarters.isEmpty {
            Section("Quarters") {
                QuarterChart(quarters: quarters)
                    .frame(height: 170)
                    .padding(.vertical, 6)
                ForEach(quarters) { q in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(verbatim: "Q\(q.q)").font(.subheadline.bold())
                            Spacer()
                            Text("New: \(q.new.map { String($0) } ?? "–") of \(q.newTarget ?? 0)")
                                .font(.subheadline).monospacedDigit()
                        }
                        if let a = q.actions, !a.isEmpty {
                            Text(verbatim: a).font(.footnote).foregroundStyle(Theme.inkSecondary)
                        }
                    }
                }
            }
        }

        if let p = year.priorities, !p.isEmpty {
            Section {
                ForEach(p, id: \.self) { Text(verbatim: $0).font(.subheadline) }
            } header: {
                Text("Priorities")
            } footer: {
                if let s = year.success, !s.isEmpty { Text("Success test: \(s)") }
            }
        }
    }

    private func vs(_ title: LocalizedStringKey, _ actual: Int?, _ target: Int?) -> some View {
        LabeledContent {
            Text(verbatim: "\(actual.map(String.init) ?? "–") / \(target.map(String.init) ?? "–")")
                .monospacedDigit()
                .environment(\.layoutDirection, .leftToRight)
        } label: { Text(title) }
    }
}

/// Paying salons at the end of each quarter: target outlined, real number filled (nothing for future quarters).
struct QuarterChart: View {
    let quarters: [PlanYear.Quarter]

    var body: some View {
        Chart {
            ForEach(quarters) { q in
                BarMark(x: .value("Quarter", "Q\(q.q)"), yStart: .value("Salons", 0),
                        yEnd: .value("Target", q.cumulativeTarget ?? 0), width: .ratio(0.6))
                    .foregroundStyle(Theme.navy.opacity(0.14))
                    .annotation(position: .top) {
                        Text(verbatim: String(q.cumulativeTarget ?? 0)).font(.caption2).foregroundStyle(Theme.inkSecondary)
                    }
                if let c = q.cumulative {
                    BarMark(x: .value("Quarter", "Q\(q.q)"), yStart: .value("Salons", 0),
                            yEnd: .value("Paying", c), width: .ratio(0.36))
                        .foregroundStyle(Theme.brandRed)
                }
            }
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityLabel(Text("Paying salons per quarter, target and real"))
    }
}

// MARK: - KPIs, renewals, roadmap, budget

struct KPIRow: View {
    let kpi: PlanKPI

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(verbatim: kpi.label ?? kpi.slug).font(.subheadline.weight(.semibold))
                Spacer()
                if kpi.value == nil {
                    StatusBadge(text: String(localized: "Track yourself"), color: Theme.grey)
                } else if case .number(let n)? = kpi.value {
                    Text(verbatim: kpi.slug == "renewal" ? "\(n)%" : String(n))
                        .font(.title3.bold().monospacedDigit())
                        .environment(\.layoutDirection, .leftToRight)
                }
            }
            switch kpi.value {
            case .new(let v)?:
                line("This month", v.month.map(String.init))
                line("This quarter", v.quarter.map(String.init))
            case .pipeline(let v)?:
                line("Contacted", v.contacted.map(String.init))
                line("Demos", v.demos.map(String.init))
                line("Offers", v.offers.map(String.init))
                line("Website requests", v.websiteRequests.map(String.init))
            case .cash(let v)?:
                line("This month", v.month?.display)
                line("This year", v.year?.display)
                if let u = v.unpaid { line("Unpaid: \(u.count ?? 0)", u.amount?.display) }
            default:
                EmptyView()
            }
            if let what = kpi.what, !what.isEmpty, kpi.value == nil || kpi.slug != "paying" {
                Text(verbatim: what).font(.caption).foregroundStyle(Theme.inkSecondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func line(_ title: LocalizedStringKey, _ value: String?) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(verbatim: value ?? "–").monospacedDigit().environment(\.layoutDirection, .leftToRight)
        }
        .font(.footnote)
    }
}

struct RenewalRow: View {
    let renewal: RenewalDue
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink(value: AppRoute.salon(id: renewal.salonId, name: renewal.salonName)) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: renewal.salonName ?? "#\(renewal.salonId)").font(.subheadline.weight(.semibold))
                    HStack(spacing: 6) {
                        Text(verbatim: Formatters.show(renewal.until, .day))
                        if let d = Formatters.daysLeft(renewal.daysLeft) {
                            Text(verbatim: d).foregroundStyle((renewal.daysLeft ?? 0) < 0 ? Theme.red : Theme.inkSecondary)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
                    MoneyText(money: renewal.amount).font(.caption)
                }
            }
            if let url = Contact.whatsappURL(renewal.whatsappLink) {
                Button {
                    openURL(url)
                } label: {
                    Image(systemName: "message.fill")
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Theme.green))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Send on WhatsApp"))
            }
        }
    }
}

struct RoadmapRow: View {
    let item: RoadmapItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: item.capability).font(.subheadline)
                Spacer()
                statusChip
            }
            HStack(spacing: 6) {
                priorityTag
                if let t = item.timing {
                    Text(verbatim: String(t)).font(.caption).foregroundStyle(Theme.inkSecondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var statusChip: some View {
        switch item.status {
        case "ready": return StatusBadge(text: String(localized: "Ready ✓"), color: Theme.green)
        case "partial": return StatusBadge(text: String(localized: "Partial"), color: Theme.orange)
        default: return StatusBadge(text: String(localized: "Planned"), color: Theme.grey)
        }
    }

    private var priorityTag: some View {
        switch item.priority {
        case "critical": return StatusBadge(text: String(localized: "Critical"), color: Theme.red)
        case "high": return StatusBadge(text: String(localized: "High"), color: Theme.orange)
        default: return StatusBadge(text: String(localized: "Medium"), color: Theme.blue)
        }
    }
}

struct BudgetSection: View {
    let budget: PlanBudget
    let items: [PlanBudget.Item]

    static func color(_ slug: String) -> Color {
        switch slug {
        case "hosting": return Theme.navy
        case "marketing": return Theme.brandRed
        case "development": return Theme.blue
        case "unexpected": return Theme.orange
        default: return Theme.green
        }
    }

    var body: some View {
        Section {
            GeometryReader { geo in
                let total = max(1, items.reduce(0) { $0 + ($1.share ?? 0) })
                HStack(spacing: 2) {
                    ForEach(items) { i in
                        Rectangle()
                            .fill(Self.color(i.slug))
                            .frame(width: max(0, geo.size.width - CGFloat(items.count - 1) * 2) * CGFloat(i.share ?? 0) / CGFloat(total))
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 14)
            .padding(.vertical, 6)
            .accessibilityHidden(true)

            ForEach(items) { i in
                HStack(spacing: 8) {
                    Circle().fill(Self.color(i.slug)).frame(width: 10, height: 10)
                    Text(verbatim: i.label ?? i.slug)
                    Text(verbatim: "\(i.share ?? 0)%").foregroundStyle(Theme.inkSecondary).monospacedDigit()
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        MoneyText(money: i.amount).font(.subheadline.bold())
                        HStack(spacing: 3) {
                            Text("goal")
                            MoneyText(money: i.amountTarget)
                        }
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                    }
                }
            }
        } header: {
            if let y = budget.year { Text("Budget \(String(y))") } else { Text("Budget") }
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("Cash collected this year:")
                    MoneyText(money: budget.base)
                    Text("· goal")
                    MoneyText(money: budget.baseTarget)
                }
                if let n = budget.note, !n.isEmpty { Text(verbatim: n) }
            }
        }
    }
}
