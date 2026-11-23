import SwiftUI

/// Home: tappable cards from GET /admin/overview. A card whose section is missing is hidden.
struct HomeView: View {
    @Environment(AppSession.self) private var session
    @State private var loader = ScreenLoader<Overview>(.overview)
    /// API 1.3: the Plan card (only when /admin/me can.plan).
    @State private var planLoader = ScreenLoader<BusinessPlan>(.businessPlan)
    /// API 1.5: the Security card (only when the plugin is on).
    @State private var securityLoader = ScreenLoader<Security>(.security)

    @Environment(\.dynamicTypeSize) private var typeSize

    /// Two cards per row; one per row with the biggest text sizes.
    private var columns: [GridItem] {
        typeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 160), spacing: 12)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                BarberStripe(height: 4)
                    .clipShape(Capsule())
                    .padding(.bottom, 2)

                if loader.isOffline {
                    OfflineBanner(time: offlineTime) { Task { await loader.refresh(session) } }
                }

                switch loader.state {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 240)
                case .failed(let error):
                    ErrorView(error: error) { Task { await loader.refresh(session) } }
                case .loaded(let answer):
                    cards(answer.value)
                }
            }
            .padding(16)
        }
        .background(Theme.background)
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                UpdatedLabel(generatedAt: loader.answer?.generatedAt, isLoading: loader.isLoading)
            }
        }
        .refreshable { await loader.refresh(session) }
        .task { await loader.load(session) }
        .task(id: session.showsSecurity) {
            if session.showsSecurity { await securityLoader.load(session) }
        }
        .onChange(of: securityLoader.error?.code) { _, code in
            if code == "smapi_no_security" { session.securityOff = true }
        }
        .task(id: session.me?.canPlan ?? false) {
            if session.me?.canPlan == true { await planLoader.load(session) }
        }
        .onChange(of: session.dataVersion) { _, _ in
            Task {
                await loader.refresh(session)
                if session.me?.canPlan == true { await planLoader.refresh(session) }
                if session.showsSecurity { await securityLoader.refresh(session) }
            }
        }
    }

    private var offlineTime: String {
        if let t = Formatters.updatedTime(loader.answer?.generatedAt) { return t }
        let f = DateFormatter()
        f.timeZone = Formatters.lebanon
        f.dateFormat = "HH:mm"
        return f.string(from: loader.answer?.savedAt ?? Date())
    }

    @ViewBuilder
    private func cards(_ o: Overview) -> some View {
        LazyVGrid(columns: columns, spacing: 12) {
            if let s = o.salons {
                StatCard(title: "Salons", systemImage: "scissors", value: number(s.total), action: { session.open(.salons) }) {
                    Text("\(s.active ?? 0) active · \(s.suspended ?? 0) suspended")
                }
            }

            if let l = o.leads {
                StatCard(title: "Demo requests", systemImage: "person.badge.plus", value: number(l.new),
                         tint: (l.new ?? 0) > 0 ? Theme.actionRed : Theme.ink,
                         badge: l.new, action: { session.open(.requests) }) {
                    Text((l.new ?? 0) == 1 ? LocalizedStringKey("new request") : LocalizedStringKey("new requests"))
                }
            }
        }

        if session.me?.canPlan == true, let plan = planLoader.value, let year = plan.currentYear {
            BusinessPlanCard(year: year, renewals: plan.renewalsDue?.count ?? 0) { session.open(.more, .route(.businessPlan)) }
        }

        if session.showsSecurity, let s = securityLoader.value {
            SecurityCard(security: s) { session.open(.more, .route(.security)) }
        }

        if let b = o.billing {
            BillingCard(counts: b) { status in session.open(.salons, .salons(billing: status)) }
        }

        if session.hasAccountTypes, let t = o.types {
            AccountTypesRow(types: t) { type in session.open(.salons, .salonsType(type)) }
        }

        if let m = o.money {
            StatCard(title: "Money this month", systemImage: "banknote", value: m.mrr?.display, action: { session.open(.money) }) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Expected every month (MRR)")
                    HStack {
                        Text("Paid this month")
                        Spacer()
                        MoneyText(money: m.paidThisMonth).foregroundStyle(Theme.green)
                    }
                    if let u = m.unpaid {
                        HStack {
                            Text("Unpaid: \(u.count ?? 0)")
                            Spacer()
                            MoneyText(money: u.amount).foregroundStyle((u.count ?? 0) > 0 ? Theme.red : Theme.inkSecondary)
                        }
                    }
                }
            }
        }

        LazyVGrid(columns: columns, spacing: 12) {
            if let w = o.whatsapp {
                StatCard(title: "WhatsApp bot", systemImage: "message", value: number(w.repliesMonth),
                         badge: w.chatsNeedTeam, action: { session.open(.more, .route(.whatsapp)) }) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("replies this month")
                        HStack(spacing: 4) { Text("Cost"); MoneyText(money: w.costMonth) }
                        if let waiting = w.chatsNeedTeam, waiting > 0 {
                            Text("\(waiting) chats wait for a salon team").foregroundStyle(Theme.orange)
                        }
                    }
                }
            }

            if let a = o.ai {
                StatCard(title: "AI assistant", systemImage: "sparkles", value: number(a.questionsMonth),
                         action: { session.open(.more, .route(.ai)) }) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("questions this month")
                        HStack(spacing: 4) { Text("Cost"); MoneyText(money: a.costMonth) }
                    }
                }
            }

            if let h = o.health {
                StatCard(title: "Health", systemImage: h.isClean ? "checkmark.seal.fill" : "stethoscope",
                         value: h.isClean ? "✓" : number((h.errors ?? 0) + (h.warnings ?? 0)),
                         tint: h.isClean ? Theme.green : ((h.errors ?? 0) > 0 ? Theme.red : Theme.orange),
                         action: { session.open(.more, .route(.health)) }) {
                    if h.isClean {
                        Text("All plugins OK")
                    } else {
                        Text("\(h.errors ?? 0) errors · \(h.warnings ?? 0) warnings")
                    }
                }
            }

            if let count = o.activityToday {
                StatCard(title: "Activity today", systemImage: "list.bullet.rectangle", value: number(count),
                         action: { session.open(.more, .route(.activity(salonId: nil, salonName: nil))) }) {
                    Text("changes in all salons")
                }
            }
        }
    }

    private func number(_ n: Int?) -> String? {
        guard let n else { return nil }
        return n.formatted(.number.locale(Locale(identifier: "en_US")))
    }
}

#if DEBUG
#Preview("Home") {
    NavigationStack { HomeView() }.environment(AppSession())
}
#endif
