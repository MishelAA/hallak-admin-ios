import SwiftUI

/// GET /admin/whatsapp: model, limit, key set (yes/no only), last error, totals, per-salon use.
struct WhatsAppView: View {
    @Environment(AppSession.self) private var session
    @State private var loader = ScreenLoader<WhatsAppReport>(.whatsapp)

    var body: some View {
        ReportScreen(title: "WhatsApp bot", loader: loader) { r in
            Section {
                InfoRow(label: "Month", value: r.month)
                InfoRow(label: "Model", value: r.model)
                InfoRow(label: "Monthly limit per salon", value: r.limit.map { $0 == 0 ? String(localized: "No limit") : String($0) })
                OnOffRow(label: "Key set", isOn: r.keySet)
                InfoRow(label: "Price in / out", value: priceText(r.prices))
            }
            if let e = r.lastError, let text = e.text, !text.isEmpty {
                Section("Last error") {
                    Label { Text(verbatim: text) } icon: { Image(systemName: "exclamationmark.triangle.fill") }
                        .foregroundStyle(Theme.orange)
                    InfoRow(label: "When", value: e.at.map { Formatters.show($0) })
                }
            }
            if let t = r.totals {
                Section("This month") {
                    InfoRow(label: "Replies", value: t.replies.map(fmt))
                    if let c = t.cost { LabeledContent { MoneyText(money: c) } label: { Text("Cost") } }
                }
            }
            if let salons = r.salons, !salons.isEmpty {
                Section("Salons") {
                    ForEach(salons) { s in
                        NavigationLink(value: AppRoute.salon(id: s.salonId, name: s.salonName)) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(verbatim: s.salonName ?? "#\(s.salonId)").font(.subheadline.weight(.semibold))
                                    Spacer()
                                    StatusBadge(text: s.botOn == true ? String(localized: "Bot on") : String(localized: "Bot off"),
                                                color: s.botOn == true ? Theme.green : Theme.grey)
                                }
                                UsageRow(label: "Replies", used: s.replies, limit: s.limit, ownLimit: s.ownLimit != nil)
                                HStack(spacing: 10) {
                                    if s.numberLinked == false {
                                        Label("Number not linked", systemImage: "link.badge.plus").foregroundStyle(Theme.orange)
                                    }
                                    if let w = s.chatsNeedTeam, w > 0 {
                                        Label("\(w) chats waiting", systemImage: "bubble.left.and.exclamationmark.bubble.right")
                                            .foregroundStyle(Theme.orange)
                                    }
                                    Spacer()
                                    MoneyText(money: s.cost)
                                }
                                .font(.caption)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
        .task { await loader.load(session) }
    }
}

/// GET /admin/ai: same layout as the WhatsApp bot.
struct AIView: View {
    @Environment(AppSession.self) private var session
    @State private var loader = ScreenLoader<AIReport>(.ai)

    var body: some View {
        ReportScreen(title: "AI assistant", loader: loader) { r in
            Section {
                InfoRow(label: "Month", value: r.month)
                InfoRow(label: "Model", value: r.model)
                InfoRow(label: "Limit per salon", value: r.limit.map { $0 == 0 ? String(localized: "No limit") : String($0) })
                if let weekly = r.weekly {
                    InfoRow(label: "Limit counted", value: weekly ? String(localized: "Every week") : String(localized: "Every month"))
                }
                OnOffRow(label: "Key set", isOn: r.keySet)
                InfoRow(label: "Price in / out", value: priceText(r.prices))
            }
            if let t = r.totals {
                Section("This month") {
                    InfoRow(label: "Questions", value: t.questions.map(fmt))
                    if let c = t.cost { LabeledContent { MoneyText(money: c) } label: { Text("Cost") } }
                }
            }
            if let salons = r.salons, !salons.isEmpty {
                Section("Salons") {
                    ForEach(salons) { s in
                        NavigationLink(value: AppRoute.salon(id: s.salonId, name: s.salonName)) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(verbatim: s.salonName ?? "#\(s.salonId)").font(.subheadline.weight(.semibold))
                                    Spacer()
                                    StatusBadge(text: s.featureOn == true ? String(localized: "On") : String(localized: "Off"),
                                                color: s.featureOn == true ? Theme.green : Theme.grey)
                                }
                                UsageRow(label: "Questions", used: s.questions, limit: s.limit, ownLimit: s.ownLimit != nil)
                                HStack {
                                    if let sum = s.summaries { Text("\(sum) summaries") }
                                    Spacer()
                                    MoneyText(money: s.cost)
                                }
                                .font(.caption)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
        .task { await loader.load(session) }
    }
}

/// Shared frame of the WhatsApp / AI screens: loading, plugin off, error, offline, pull to refresh.
struct ReportScreen<T: Decodable, Content: View>: View {
    let title: LocalizedStringKey
    let loader: ScreenLoader<T>
    @ViewBuilder var content: (T) -> Content
    @Environment(AppSession.self) private var session

    var body: some View {
        List {
            if loader.isOffline {
                OfflineBanner(time: Formatters.updatedTime(loader.answer?.generatedAt) ?? "–") { Task { await loader.refresh(session) } }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            switch loader.state {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, minHeight: 120).listRowBackground(Color.clear)
            case .failed(let e):
                if e.behaviour == .pluginOff {
                    EmptyState(title: "This plugin is off", message: "Turn it on in wp-admin to see it here.", image: "BarberBye")
                        .listRowBackground(Color.clear)
                } else {
                    ErrorView(error: e) { Task { await loader.refresh(session) } }.listRowBackground(Color.clear)
                }
            case .loaded(let a):
                content(a.value)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                UpdatedLabel(generatedAt: loader.answer?.generatedAt, isLoading: loader.isLoading)
            }
        }
        .refreshable { await loader.refresh(session) }
    }
}

private func fmt(_ n: Int) -> String { n.formatted(.number.locale(Locale(identifier: "en_US"))) }

private func priceText(_ p: TokenPrices?) -> String? {
    guard let p, p.input != nil || p.output != nil else { return nil }
    let f = { (d: Double?) in d.map { "$" + $0.formatted(.number.precision(.fractionLength(0...4)).locale(Locale(identifier: "en_US"))) } ?? "–" }
    return "\(f(p.input)) / \(f(p.output))"
}
