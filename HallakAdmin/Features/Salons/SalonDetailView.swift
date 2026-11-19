import SwiftUI

/// GET /admin/salons/{id} (+ /users, /subscription): everything about one salon.
struct SalonDetailView: View {
    let salonId: Int
    var initialName: String?

    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var detail: ScreenLoader<SalonDetail>
    @State private var users: ScreenLoader<ItemList<UserShort>>
    @State private var subscription: ScreenLoader<SubscriptionAnswer>

    init(salonId: Int, initialName: String? = nil) {
        self.salonId = salonId
        self.initialName = initialName
        _detail = State(initialValue: ScreenLoader(.salon(salonId)))
        _users = State(initialValue: ScreenLoader(.salonUsers(salonId)))
        _subscription = State(initialValue: ScreenLoader(.subscription(salonId)))
    }

    var body: some View {
        Group {
            switch detail.state {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let error):
                ScrollView { ErrorView(error: error) { Task { await reload() } } }
            case .loaded(let answer):
                content(answer.value)
            }
        }
        .background(Theme.background)
        .navigationTitle(Text(verbatim: detail.value?.salon.name ?? initialName ?? ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                UpdatedLabel(generatedAt: detail.answer?.generatedAt, isLoading: detail.isLoading)
            }
        }
        .refreshable { await reload() }
        .task { await load() }
        .onChange(of: detail.error) { _, e in
            if e?.behaviour == .notFound, detail.value == nil { dismiss() }
        }
    }

    private func load() async {
        let (d, u, s, sess) = (detail, users, subscription, session)
        async let a: Void = d.load(sess)
        async let b: Void = u.load(sess)
        async let c: Void = s.load(sess)
        _ = await (a, b, c)
    }

    private func reload() async {
        let (d, u, s, sess) = (detail, users, subscription, session)
        async let a: Void = d.refresh(sess)
        async let b: Void = u.refresh(sess)
        async let c: Void = s.refresh(sess)
        _ = await (a, b, c)
    }

    // MARK: Sections

    private func content(_ d: SalonDetail) -> some View {
        List {
            if detail.isOffline {
                OfflineBanner(time: Formatters.updatedTime(detail.answer?.generatedAt) ?? "–") { Task { await reload() } }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            header(d)
            ownerSection(d)
            subscriptionSection
            monthSection(d.month)
            featuresSection(d.features)
            whatsappSection(d.whatsapp)
            aiSection(d.ai)
            invoicesSection(d.invoices)
            teamSection
            linksSection(d)
            if let notes = d.salon.notes, !notes.isEmpty {
                Section("Notes") { Text(verbatim: notes) }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func header(_ d: SalonDetail) -> some View {
        let s = d.salon
        return Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: s.name).font(.title2.bold()).foregroundStyle(Theme.ink)
                if let address = s.address, !address.isEmpty {
                    Label { Text(verbatim: address) } icon: { Image(systemName: "mappin.and.ellipse") }
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                }
                HStack(spacing: 6) {
                    if s.isSuspended {
                        StatusBadge(text: String(localized: "Suspended"), color: Theme.grey)
                    } else {
                        StatusBadge(text: String(localized: "Active"), color: Theme.green)
                    }
                    if let label = s.billing?.statusLabel {
                        StatusBadge(text: label, color: Theme.color(for: s.billing?.status))
                    }
                }
                HStack(spacing: 24) {
                    ContactButton(title: "Call", systemImage: "phone.fill", url: Contact.phoneURL(s.phone))
                    ContactButton(title: "WhatsApp", systemImage: "message.fill", url: Contact.whatsappURL(d.links?.whatsapp), tint: Theme.green)
                    ContactButton(title: "Email", systemImage: "envelope.fill", url: Contact.mailURL(s.owner?.email))
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 4)

            InfoRow(label: "Phone", value: s.phone)
            InfoRow(label: "Language", value: languageName(s.language))
            InfoRow(label: "Currency", value: currencyText(s))
            InfoRow(label: "Created", value: s.createdAt.map { Formatters.show($0) })
            InfoRow(label: "Last activity", value: s.lastActivity.map { Formatters.show($0) })
        }
    }

    @ViewBuilder
    private func ownerSection(_ d: SalonDetail) -> some View {
        if let o = d.salon.owner {
            let login = users.value?.items.first(where: { $0.id == o.id || $0.role == "owner" })?.lastLogin
            Section("Owner") {
                InfoRow(label: "Name", value: o.name)
                InfoRow(label: "Username", value: o.username)
                if let email = o.email, !email.isEmpty {
                    if let url = Contact.mailURL(email) {
                        Link(destination: url) {
                            LabeledContent {
                                Text(verbatim: email).foregroundStyle(Theme.actionRed)
                            } label: {
                                Text("Email").foregroundStyle(Theme.ink)
                            }
                        }
                    }
                }
                InfoRow(label: "Last login", value: login.map { Formatters.show($0) } ?? (users.value == nil ? nil : String(localized: "Never")))
            }
        }
    }

    @ViewBuilder
    private var subscriptionSection: some View {
        if subscription.error?.behaviour != .pluginOff, let answer = subscription.value {
            Section("Subscription") {
                if let b = answer.subscription {
                    if let label = b.statusLabel {
                        LabeledContent { StatusBadge(text: label, color: Theme.color(for: b.status)) } label: { Text("Status") }
                    }
                    InfoRow(label: "Plan", value: b.plan)
                    InfoRow(label: "Cycle", value: cycleName(b.cycle))
                    InfoRow(label: "Price", value: b.price?.display.appending(b.ownPrice == true ? " ★" : ""))
                    InfoRow(label: "Per month", value: b.monthly?.display)
                    InfoRow(label: "Paid until", value: b.until.map { Formatters.show($0, .day) })
                    InfoRow(label: "Days left", value: Formatters.daysLeft(b.daysLeft),
                            valueColor: (b.daysLeft ?? 0) < 0 ? Theme.red : Theme.ink)
                    InfoRow(label: "Payment due until", value: b.graceEnd.map { Formatters.show($0, .day) })
                    if b.trial == true { InfoRow(label: "Trial", value: String(localized: "Yes")) }
                } else {
                    Text("Not billed").foregroundStyle(Theme.inkSecondary)
                }
                if let inv = answer.openInvoice {
                    NavigationLink(value: AppRoute.invoice(id: inv.id)) {
                        LabeledContent {
                            MoneyText(money: inv.amount).foregroundStyle(Theme.orange)
                        } label: {
                            VStack(alignment: .leading) {
                                Text("Open invoice")
                                Text(verbatim: inv.title).font(.caption).foregroundStyle(Theme.inkSecondary)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func monthSection(_ m: SalonDetail.Month?) -> some View {
        if let m {
            Section("This month") {
                InfoRow(label: "Visits", value: m.visits.map(String.init))
                if let r = m.revenue { LabeledContent { MoneyText(money: r) } label: { Text("Revenue") } }
                InfoRow(label: "Customers", value: m.customers.map(String.init))
            }
        }
    }

    @ViewBuilder
    private func featuresSection(_ f: [SalonDetail.FeatureState]?) -> some View {
        if let f, !f.isEmpty {
            Section {
                ForEach(f) { feature in
                    OnOffRow(label: LocalizedStringKey(feature.label ?? feature.slug), isOn: feature.on ?? false)
                }
            } header: {
                Text("Features")
            } footer: {
                if session.me?.canWrite != true { Text("Read only in this version.") }
            }
        }
    }

    @ViewBuilder
    private func whatsappSection(_ w: SalonDetail.WhatsApp?) -> some View {
        if let w, session.me?.hasWhatsApp ?? true {
            Section("WhatsApp bot") {
                OnOffRow(label: "Feature", isOn: w.featureOn)
                OnOffRow(label: "Bot", isOn: w.botOn)
                OnOffRow(label: "Number linked", isOn: w.numberLinked)
                UsageRow(label: "Replies this month", used: w.repliesMonth, limit: w.limit, ownLimit: w.ownLimit)
                if let waiting = w.chatsNeedTeam, waiting > 0 {
                    InfoRow(label: "Chats waiting for the team", value: String(waiting), valueColor: Theme.orange)
                }
                if let c = w.costMonth { LabeledContent { MoneyText(money: c) } label: { Text("Cost this month") } }
            }
        }
    }

    @ViewBuilder
    private func aiSection(_ a: SalonDetail.AI?) -> some View {
        if let a, session.me?.hasAI ?? true {
            Section("AI assistant") {
                OnOffRow(label: "Feature", isOn: a.featureOn)
                UsageRow(label: "Questions this month", used: a.questionsMonth, limit: a.limit, ownLimit: a.ownLimit)
                if let c = a.costMonth { LabeledContent { MoneyText(money: c) } label: { Text("Cost this month") } }
            }
        }
    }

    @ViewBuilder
    private func invoicesSection(_ invoices: [Invoice]?) -> some View {
        if let invoices, !invoices.isEmpty {
            Section("Last invoices") {
                ForEach(invoices.prefix(5)) { inv in
                    NavigationLink(value: AppRoute.invoice(id: inv.id)) { InvoiceRow(invoice: inv, showSalon: false) }
                }
            }
        }
    }

    @ViewBuilder
    private var teamSection: some View {
        if let team = users.value?.items, !team.isEmpty {
            Section {
                ForEach(team.prefix(4)) { UserRow(user: $0) }
                if team.count > 4 {
                    NavigationLink(value: AppRoute.salonUsers(id: salonId, name: detail.value?.salon.name)) {
                        Text("All \(team.count) logins")
                    }
                }
            } header: {
                Text("Team logins")
            }
        }
    }

    private func linksSection(_ d: SalonDetail) -> some View {
        Section("Links") {
            dashboardRow(d)
            linkRow(String(localized: "Salon page"), "globe", d.links?.page)
            linkRow(String(localized: "Booking page"), "calendar.badge.plus", d.links?.booking)
            NavigationLink(value: AppRoute.activity(salonId: salonId, salonName: d.salon.name)) {
                Label("Activity", systemImage: "list.bullet.rectangle")
            }
        }
    }

    /// The salon's dashboard, opened inside the app and signed in as you (one-time link).
    @ViewBuilder
    private func dashboardRow(_ d: SalonDetail) -> some View {
        let fallback = Contact.webURL(d.links?.dashboard)
            ?? d.salon.slug.flatMap { slug in session.credentials.map { $0.site.appendingPathComponent("salon/\(slug)/") } }
        if let url = fallback {
            NavigationLink(value: AppRoute.dashboard(salonId: salonId, url: url, title: d.salon.name)) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dashboard")
                        Text("Opens signed in as you").font(.caption).foregroundStyle(Theme.inkSecondary)
                    }
                } icon: {
                    Image(systemName: "rectangle.grid.2x2")
                }
            }
            .frame(minHeight: Theme.minTouch)
        }
    }

    @ViewBuilder
    /// Opens the page inside the app (pushed like any screen), not in Safari.
    private func linkRow(_ title: String, _ icon: String, _ link: String?) -> some View {
        if let url = Contact.webURL(link) {
            NavigationLink(value: AppRoute.web(url: url, title: title)) {
                Label { Text(verbatim: title) } icon: { Image(systemName: icon) }
            }
            .frame(minHeight: Theme.minTouch)
        }
    }

    // MARK: Text helpers

    private func languageName(_ code: String?) -> String? {
        switch code {
        case "ar": return String(localized: "Arabic")
        case "en": return String(localized: "English")
        default: return code
        }
    }

    private func cycleName(_ cycle: String?) -> String? {
        switch cycle {
        case "month": return String(localized: "Monthly")
        case "year": return String(localized: "Yearly")
        default: return cycle
        }
    }

    private func currencyText(_ s: Salon) -> String? {
        guard let c = s.currency else { return nil }
        guard let fx = s.fx, let second = fx.second, let rate = fx.rate, rate > 0 else { return c }
        let r = rate.formatted(.number.precision(.fractionLength(0...2)).locale(Locale(identifier: "en_US")))
        return "\(c) · 1 \(c) = \(r) \(second)"
    }
}

/// "640 / 1,000" with a bar. limit 0 = no limit.
struct UsageRow: View {
    let label: LocalizedStringKey
    let used: Int?
    let limit: Int?
    var ownLimit: Bool?

    var body: some View {
        if let used {
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent {
                    if let limit, limit > 0 {
                        Text(verbatim: "\(fmt(used)) / \(fmt(limit))").monospacedDigit()
                    } else {
                        Text(verbatim: fmt(used)).monospacedDigit()
                    }
                } label: {
                    Text(label)
                }
                if let limit, limit > 0 {
                    ProgressView(value: Double(min(used, limit)), total: Double(limit))
                        .tint(Double(used) / Double(limit) >= 0.9 ? Theme.red : Theme.navy)
                    if ownLimit == true {
                        Text("This salon has its own limit.").font(.caption).foregroundStyle(Theme.inkSecondary)
                    }
                } else {
                    Text("No limit").font(.caption).foregroundStyle(Theme.inkSecondary)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func fmt(_ n: Int) -> String { n.formatted(.number.locale(Locale(identifier: "en_US"))) }
}

/// One login of a salon team.
struct UserRow: View {
    let user: UserShort

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: user.displayName)
                if let u = user.username { Text(verbatim: u).font(.caption).foregroundStyle(Theme.inkSecondary) }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                StatusBadge(text: roleName, color: user.role == "owner" ? Theme.navy : Theme.grey)
                Text(verbatim: user.lastLogin.flatMap { Formatters.relative($0) } ?? String(localized: "Never logged in"))
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var roleName: String {
        switch user.role {
        case "owner": return String(localized: "Owner")
        case "staff": return String(localized: "Staff")
        default: return String(localized: "Other")
        }
    }
}

/// GET /admin/salons/{id}/users: all logins.
struct SalonUsersView: View {
    let salonId: Int
    var salonName: String?
    @Environment(AppSession.self) private var session
    @State private var loader: ScreenLoader<ItemList<UserShort>>

    init(salonId: Int, salonName: String?) {
        self.salonId = salonId
        self.salonName = salonName
        _loader = State(initialValue: ScreenLoader(.salonUsers(salonId)))
    }

    var body: some View {
        List {
            switch loader.state {
            case .loading: ProgressView()
            case .failed(let e): ErrorView(error: e) { Task { await loader.refresh(session) } }
            case .loaded(let a): ForEach(a.value.items) { UserRow(user: $0) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Team logins")
        .refreshable { await loader.refresh(session) }
        .task { await loader.load(session) }
    }
}
