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
    // Actions (API 1.2)
    @State private var runner = ActionRunner()
    @State private var sheet: SheetKind?
    @State private var confirmSuspend = false
    @State private var resetUser: UserShort?
    @State private var moveTo: Owner?
    @State private var pendingFeatures: Set<String> = []
    @State private var methods: [BillingSummary.Method] = []

    /// Sheets opened from this screen.
    enum SheetKind: Hashable, Identifiable {
        case edit, subscription, delete, pickOwner
        case limit(LimitEditorView.Kind)
        case invoice(payment: Bool)
        case login(NewLogin)
        var id: Self { self }
    }

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
                UpdatedLabel(generatedAt: detail.answer?.generatedAt, isLoading: detail.isLoading || runner.isRunning)
            }
            if session.canWrite, let d = detail.value {
                ToolbarItem(placement: .topBarTrailing) { actionsMenu(d) }
            }
        }
        .refreshable { await reload() }
        .task { await load() }
        .onChange(of: detail.error) { _, e in
            if e?.behaviour == .notFound, detail.value == nil { dismiss() }
        }
        .actionErrorAlert(runner)
        .sheet(item: $sheet) { which in sheetView(which) }
        .confirmationDialog(detail.value?.salon.isSuspended == true ? Text("Activate this salon?") : Text("Suspend this salon?"),
                            isPresented: $confirmSuspend, titleVisibility: .visible) {
            if detail.value?.salon.isSuspended == true {
                Button("Activate") { Task { await suspend(false) } }
            } else {
                Button("Suspend", role: .destructive) { Task { await suspend(true) } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            detail.value?.salon.isSuspended == true ? Text("The team can log in again.") : Text("The owner and the team can no longer log in. Nothing is deleted.")
        }
        .confirmationDialog("Make a new password?", isPresented: Binding(get: { resetUser != nil }, set: { if !$0 { resetUser = nil } }),
                            titleVisibility: .visible, presenting: resetUser) { u in
            Button("New password for \(u.displayName)", role: .destructive) { Task { await resetPassword(u) } }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("The old password stops working and the login is signed out everywhere.")
        }
        .confirmationDialog("Move this salon?", isPresented: Binding(get: { moveTo != nil }, set: { if !$0 { moveTo = nil } }),
                            titleVisibility: .visible, presenting: moveTo) { o in
            Button("Move to \(o.displayName)") { Task { await move(to: o) } }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("The salon becomes a branch of this owner.")
        }
    }

    // MARK: Actions (API 1.2)

    private func actionsMenu(_ d: SalonDetail) -> some View {
        Menu {
            Button { sheet = .edit } label: { Label("Edit", systemImage: "pencil") }
            if d.salon.isSuspended {
                Button { confirmSuspend = true } label: { Label("Activate", systemImage: "play.circle") }
            } else {
                Button { confirmSuspend = true } label: { Label("Suspend", systemImage: "pause.circle") }
            }
            Button { sheet = .pickOwner } label: { Label("Move to another owner", systemImage: "arrow.left.arrow.right") }
            Divider()
            Button(role: .destructive) { sheet = .delete } label: { Label("Delete salon", systemImage: "trash") }
        } label: {
            Label("Actions", systemImage: "ellipsis.circle")
        }
        .disabled(runner.isRunning)
    }

    @ViewBuilder
    private func sheetView(_ which: SheetKind) -> some View {
        if let d = detail.value {
            switch which {
            case .edit:
                EditSalonView(detail: d) { detail.set($0) }
            case .limit(let kind):
                LimitEditorView(salonId: salonId, kind: kind,
                                current: kind == .whatsapp ? d.whatsapp?.limit : d.ai?.limit,
                                ownLimit: (kind == .whatsapp ? d.whatsapp?.ownLimit : d.ai?.ownLimit) ?? false) { detail.set($0) }
            case .subscription:
                SubscriptionEditorView(salonId: salonId, current: subscription.value?.subscription) { a in
                    subscription.set(a)
                    Task { await detail.refresh(session) }
                }
            case .invoice(let payment):
                InvoiceEditorView(salonId: salonId, recordPayment: payment, methods: methods) { _ in
                    Task { await reload() }
                }
            case .delete:
                DeleteSalonView(salon: d.salon) { dismiss() }
            case .pickOwner:
                OwnerPickerView(exclude: d.salon.owner?.id) { o in
                    sheet = nil
                    moveTo = o
                }
            case .login(let login):
                NewLoginSheet(title: "New password", login: login) { sheet = nil }
            }
        }
    }

    private func suspend(_ on: Bool) async {
        if let d = await runner.run(session, success: on ? String(localized: "Salon suspended") : String(localized: "Salon active again"), {
            try await ActionRunner.client(session).send(on ? .suspendSalon(salonId) : .activateSalon(salonId), as: SalonDetail.self)
        }) { detail.set(d) }
    }

    private func move(to owner: Owner) async {
        moveTo = nil
        if let d = await runner.run(session, success: String(localized: "Salon moved"), {
            try await ActionRunner.client(session).send(.moveSalon(salonId, ownerId: owner.id), as: SalonDetail.self)
        }) {
            detail.set(d)
            await users.refresh(session)
        }
    }

    /// Instant switch. On error the switch goes back: it always shows what the server has.
    private func setFeature(_ slug: String, _ on: Bool) async {
        pendingFeatures.insert(slug)
        defer { pendingFeatures.remove(slug) }
        if let d = await runner.run(session, {
            try await ActionRunner.client(session).send(.setFeatures(salonId, [slug: on]), as: SalonDetail.self)
        }) { detail.set(d) }
    }

    private func resetPassword(_ user: UserShort) async {
        resetUser = nil
        if let r = await runner.run(session, {
            try await ActionRunner.client(session).send(.resetPassword(userId: user.id), as: PasswordReset.self)
        }) {
            sheet = .login(r.login)
        }
    }

    private func loadMethods() async {
        guard methods.isEmpty, let client = session.client,
              let s = try? await client.fetch(.billingSummary, as: BillingSummary.self) else { return }
        methods = s.value.methods ?? []
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
                    TypeChip(billing: s.billing)
                }
                if let n = s.billing?.trialEndsSoon {
                    Label {
                        Text(n == 0 ? String(localized: "Trial ends today") : String(localized: "Trial ends in \(n) days"))
                    } icon: { Image(systemName: "hourglass") }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.orange)
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
                if session.canWrite {
                    Button { sheet = .subscription } label: { Label("Change plan", systemImage: "slider.horizontal.3") }
                    Button { sheet = .invoice(payment: false) } label: { Label("New invoice", systemImage: "doc.badge.plus") }
                    Button {
                        Task { await loadMethods() }
                        sheet = .invoice(payment: true)
                    } label: { Label("Record a payment", systemImage: "banknote") }
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
                    if session.canWrite {
                        Toggle(isOn: Binding(get: { feature.on ?? false },
                                             set: { on in Task { await setFeature(feature.slug, on) } })) {
                            HStack {
                                Text(verbatim: feature.label ?? feature.slug)
                                if pendingFeatures.contains(feature.slug) { ProgressView().controlSize(.small) }
                            }
                        }
                        .disabled(pendingFeatures.contains(feature.slug))
                    } else {
                        OnOffRow(label: LocalizedStringKey(feature.label ?? feature.slug), isOn: feature.on ?? false)
                    }
                }
            } header: {
                Text("Features")
            } footer: {
                if session.canWrite { Text("Changes apply at once, like the boxes in wp-admin.") }
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
                if session.canWrite {
                    Button { sheet = .limit(.whatsapp) } label: { Label("Change monthly limit", systemImage: "gauge.with.dots.needle.50percent") }
                }
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
                if session.canWrite {
                    Button { sheet = .limit(.ai) } label: { Label("Change monthly limit", systemImage: "gauge.with.dots.needle.50percent") }
                }
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
                ForEach(team.prefix(4)) { u in
                    UserRow(user: u)
                        .swipeActions {
                            if session.canWrite, u.role == "owner" || u.role == "staff" {
                                Button("New password") { resetUser = u }.tint(Theme.orange)
                            }
                        }
                        .contextMenu {
                            if session.canWrite, u.role == "owner" || u.role == "staff" {
                                Button { resetUser = u } label: { Label("New password", systemImage: "key") }
                            }
                        }
                }
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

    /// Open the salon's own dashboard inside the app, signed in as you (API 1.1 one-time links):
    /// "Open dashboard", "Appointments", "Visits", "Customers", then the salon page and booking page.
    private func linksSection(_ d: SalonDetail) -> some View {
        let dashboard = Contact.webURL(d.links?.dashboard)
            ?? d.salon.slug.flatMap { slug in session.credentials.map { $0.site.appendingPathComponent("salon/\(slug)/") } }
        let name = d.salon.name
        let signedIn = session.me?.canOpenLinks ?? true
        return Section {
            if signedIn {
                dashboardButton(String(localized: "Open dashboard"), "rectangle.grid.2x2", tab: "", fallback: dashboard, name: name, prominent: true)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                    dashboardButton(String(localized: "Appointments"), "calendar", tab: "appointments", fallback: dashboard, name: name)
                    dashboardButton(String(localized: "Visits"), "scissors", tab: "visits", fallback: dashboard, name: name)
                    dashboardButton(String(localized: "Customers"), "person.2", tab: "customers", fallback: dashboard, name: name)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                pageRow(String(localized: "Salon page"), "globe", to: "page", link: d.links?.page)
                pageRow(String(localized: "Booking page"), "calendar.badge.plus", to: "booking", link: d.links?.booking)
            } else {
                linkRow(String(localized: "Open dashboard"), "rectangle.grid.2x2", d.links?.dashboard)
                linkRow(String(localized: "Salon page"), "globe", d.links?.page)
                linkRow(String(localized: "Booking page"), "calendar.badge.plus", d.links?.booking)
            }
            NavigationLink(value: AppRoute.activity(salonId: salonId, salonName: name)) {
                Label("Activity", systemImage: "list.bullet.rectangle")
            }
        } header: {
            Text("Dashboard")
        } footer: {
            if signedIn { Text("Opens inside the app, signed in as you.") }
        }
    }

    /// One dashboard tab, opened signed in. A new one-time link is asked for on every tap.
    @ViewBuilder
    private func dashboardButton(_ title: String, _ icon: String, tab: String, fallback: URL?, name: String, prominent: Bool = false) -> some View {
        let route = AppRoute.signedIn(.salon(id: salonId, tab: tab, to: "dashboard"),
                                      title: tab.isEmpty ? name : "\(name) · \(title)", fallback: fallback)
        if prominent {
            NavigationLink(value: route) {
                Label { Text(verbatim: title).bold() } icon: { Image(systemName: icon) }
            }
            .frame(minHeight: Theme.minTouch)
        } else {
            // Several buttons share one row: plain buttons (not links) so each opens only its own page.
            Button {
                Haptics.tap()
                session.push(route)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: icon).font(.title3)
                    Text(verbatim: title).font(.caption).lineLimit(1).minimumScaleFactor(0.8)
                }
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.background))
            }
        }
    }

    /// Salon page / booking page through the sign-in link (to: page / booking).
    @ViewBuilder
    private func pageRow(_ title: String, _ icon: String, to: String, link: String?) -> some View {
        NavigationLink(value: AppRoute.signedIn(.salon(id: salonId, to: to), title: title, fallback: Contact.webURL(link))) {
            Label { Text(verbatim: title) } icon: { Image(systemName: icon) }
        }
        .frame(minHeight: Theme.minTouch)
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
    @State private var runner = ActionRunner()
    @State private var resetUser: UserShort?
    @State private var newLogin: NewLogin?

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
            case .loaded(let a):
                ForEach(a.value.items) { u in
                    UserRow(user: u)
                        .swipeActions {
                            if session.canWrite, u.role == "owner" || u.role == "staff" {
                                Button("New password") { resetUser = u }.tint(Theme.orange)
                            }
                        }
                        .contextMenu {
                            if session.canWrite, u.role == "owner" || u.role == "staff" {
                                Button { resetUser = u } label: { Label("New password", systemImage: "key") }
                            }
                        }
                }
            }
        }
        .actionErrorAlert(runner)
        .confirmationDialog("Make a new password?", isPresented: Binding(get: { resetUser != nil }, set: { if !$0 { resetUser = nil } }),
                            titleVisibility: .visible, presenting: resetUser) { u in
            Button("New password for \(u.displayName)", role: .destructive) {
                Task {
                    resetUser = nil
                    if let r = await runner.run(session, {
                        try await ActionRunner.client(session).send(.resetPassword(userId: u.id), as: PasswordReset.self)
                    }) { newLogin = r.login }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("The old password stops working and the login is signed out everywhere.")
        }
        .sheet(item: Binding(get: { newLogin.map(LoginItem.init) }, set: { if $0 == nil { newLogin = nil } })) { item in
            NewLoginSheet(title: "New password", login: item.login) { newLogin = nil }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Team logins")
        .refreshable { await loader.refresh(session) }
        .task { await loader.load(session) }
    }
}

/// Wraps a one-time login for `.sheet(item:)`.
struct LoginItem: Identifiable {
    let login: NewLogin
    var id: String { login.password }
}
