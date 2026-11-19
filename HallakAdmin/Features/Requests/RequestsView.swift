import SwiftUI

/// Requests: demo requests from the website (GET /admin/leads). Read only in v1.
struct RequestsView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case new, done, all
        var id: String { rawValue }
        var label: LocalizedStringKey {
            switch self {
            case .new: return "New"
            case .done: return "Done"
            case .all: return "All"
            }
        }
    }

    struct Query: Hashable {
        var filter = Filter.new
        var search = ""
        var params: [String: String] {
            var p: [String: String] = filter == .all ? [:] : ["status": filter.rawValue]
            let s = search.trimmingCharacters(in: .whitespaces)
            if !s.isEmpty { p["search"] = s }
            return p
        }
    }

    @Environment(AppSession.self) private var session
    @State private var loader = PagedLoader<Lead>(filters: ["status": "new"]) { .leads($0) }
    @State private var query = Query()
    @State private var lastSearch = ""

    var body: some View {
        List {
            Section {
                Picker(selection: $query.filter) {
                    ForEach(Filter.allCases) { Text($0.label).tag($0) }
                } label: { EmptyView() }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            if loader.isOffline {
                OfflineBanner(time: Formatters.updatedTime(loader.generatedAt) ?? "–") { Task { await loader.reload(session) } }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            Section {
                if loader.items.isEmpty {
                    if let e = loader.error {
                        ErrorView(error: e) { Task { await loader.reload(session) } }.listRowBackground(Color.clear)
                    } else if loader.isEmpty {
                        EmptyState(title: query.filter == .new ? "No new requests" : "No requests",
                                   message: query.filter == .new ? "New “Book a free demo” requests from the website show here." : nil)
                            .listRowBackground(Color.clear)
                    } else {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 120).listRowBackground(Color.clear)
                    }
                }
                ForEach(loader.items) { lead in
                    NavigationLink(value: AppRoute.lead(lead)) { LeadRow(lead: lead) }
                        .task { await loader.loadMoreIfNeeded(after: lead, session) }
                }
                if loader.list.canLoadMore, !loader.items.isEmpty {
                    HStack { Spacer(); ProgressView(); Spacer() }.listRowBackground(Color.clear)
                }
            } header: {
                if loader.loadedOnce, !loader.items.isEmpty { Text("\(loader.list.total) requests") }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Requests")
        .searchable(text: $query.search, prompt: Text("Name, salon, phone or email"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                UpdatedLabel(generatedAt: loader.generatedAt, isLoading: loader.isLoading)
            }
        }
        .refreshable { await loader.reload(session) }
        .task(id: query) {
            if query.search != lastSearch {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                lastSearch = query.search
            }
            await loader.setFilters(query.params, session)
        }
    }
}

struct LeadRow: View {
    let lead: Lead

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(verbatim: lead.name ?? "–").font(.headline)
                    if lead.isNew { StatusBadge(text: String(localized: "New"), color: Theme.actionRed) }
                }
                if let s = lead.salon, !s.isEmpty { Text(verbatim: s).font(.subheadline) }
                HStack(spacing: 8) {
                    if let p = lead.phone, !p.isEmpty {
                        Text(verbatim: p).environment(\.layoutDirection, .leftToRight)
                    }
                    if let at = lead.createdAt { Text(verbatim: Formatters.relative(at) ?? Formatters.show(at)) }
                }
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// One demo request: all fields + WhatsApp (API link), call, email.
struct LeadDetailView: View {
    let lead: Lead

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(verbatim: lead.name ?? "–").font(.title2.bold())
                        Spacer()
                        StatusBadge(text: lead.isNew ? String(localized: "New") : String(localized: "Done"),
                                    color: lead.isNew ? Theme.actionRed : Theme.grey)
                    }
                    if let s = lead.salon, !s.isEmpty { Text(verbatim: s).foregroundStyle(Theme.inkSecondary) }
                    HStack(spacing: 24) {
                        ContactButton(title: "WhatsApp", systemImage: "message.fill", url: Contact.whatsappURL(lead.whatsapp), tint: Theme.green)
                        ContactButton(title: "Call", systemImage: "phone.fill", url: Contact.phoneURL(lead.phone))
                        ContactButton(title: "Email", systemImage: "envelope.fill", url: Contact.mailURL(lead.email))
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }
            Section {
                InfoRow(label: "Phone", value: lead.phone)
                InfoRow(label: "Email", value: lead.email)
                InfoRow(label: "Plan wanted", value: lead.plan)
                InfoRow(label: "Number of barbers", value: lead.barbers)
                InfoRow(label: "Sent", value: lead.createdAt.map { Formatters.show($0) })
            }
            if let m = lead.message, !m.isEmpty {
                Section("Message") { Text(verbatim: m) }
            }
            Section {
            } footer: {
                Text("Changing the status and “Create salon from request” come with the next API version.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Demo request")
        .navigationBarTitleDisplayMode(.inline)
    }
}
