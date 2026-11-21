import SwiftUI

/// Filter chips of the Salons list → `status` / `billing` parameters.
enum SalonFilter: String, CaseIterable, Identifiable, Hashable {
    case all, active, suspended, trial, paid, due, overdue, notBilled
    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .all: return "All"
        case .active: return "Active"
        case .suspended: return "Suspended"
        case .trial: return "Trial"
        case .paid: return "Paid"
        case .due: return "Payment due"
        case .overdue: return "Overdue"
        case .notBilled: return "Not billed"
        }
    }

    var query: [String: String] {
        switch self {
        case .all: return [:]
        case .active: return ["status": "active"]
        case .suspended: return ["status": "suspended"]
        case .trial: return ["billing": "trial"]
        case .paid: return ["billing": "active"]
        case .due: return ["billing": "grace"]
        case .overdue: return ["billing": "overdue"]
        case .notBilled: return ["billing": "free"]
        }
    }

    init(billing: BillingStatus?) {
        switch billing {
        case .trial: self = .trial
        case .active: self = .paid
        case .grace: self = .due
        case .overdue: self = .overdue
        case .free: self = .notBilled
        case .demo, .unknown, .none: self = .all
        }
    }
}

enum SalonSort: String, CaseIterable, Identifiable, Hashable {
    case new, name, until, activity
    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .new: return "Newest"
        case .name: return "Name"
        case .until: return "Paid until"
        case .activity: return "Last activity"
        }
    }
}

/// What the Salons list asks the API for.
struct SalonQuery: Hashable {
    var search = ""
    var filter = SalonFilter.all
    var sort = SalonSort.new
    /// API 1.4: account type filter (nil = all).
    var type: AccountType?

    var params: [String: String] {
        var p = filter.query
        if let type { p["type"] = type.rawValue }
        let s = search.trimmingCharacters(in: .whitespaces)
        if !s.isEmpty { p["search"] = s }
        if sort != .new { p["sort"] = sort.rawValue }
        return p
    }
}

/// GET /admin/salons: search, filter chips, sort, infinite scroll.
struct SalonsView: View {
    @Environment(AppSession.self) private var session
    @State private var loader = PagedLoader<Salon> { .salons($0) }
    @State private var query = SalonQuery()
    @State private var lastSearch = ""
    @State private var showNew = false

    var body: some View {
        List {
            Section {
                chips
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                if session.hasAccountTypes {
                    typeChips
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
                        .listRowBackground(Color.clear)
                }
            }

            if loader.isOffline {
                OfflineBanner(time: Formatters.updatedTime(loader.generatedAt) ?? "–") {
                    Task { await loader.reload(session) }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                if loader.items.isEmpty {
                    if let error = loader.error {
                        ErrorView(error: error) { Task { await loader.reload(session) } }
                            .listRowBackground(Color.clear)
                    } else if loader.isEmpty {
                        EmptyState(title: query.params.isEmpty ? "No salons yet" : "No salon matches",
                                   message: query.params.isEmpty ? nil : "Try another search or filter.")
                            .listRowBackground(Color.clear)
                    } else {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 120).listRowBackground(Color.clear)
                    }
                } else {
                    ForEach(loader.items) { salon in
                        NavigationLink(value: AppRoute.salon(id: salon.id, name: salon.name)) {
                            SalonRow(salon: salon)
                        }
                        .task { await loader.loadMoreIfNeeded(after: salon, session) }
                    }
                    if loader.list.canLoadMore {
                        HStack { Spacer(); ProgressView(); Spacer() }.listRowBackground(Color.clear)
                    }
                }
            } header: {
                if loader.loadedOnce, !loader.items.isEmpty {
                    HStack {
                        Text("\(loader.list.total) salons")
                        Spacer()
                        UpdatedLabel(generatedAt: loader.generatedAt, isLoading: loader.isLoading)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Salons")
        .searchable(text: $query.search, prompt: Text("Name, phone or owner"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker(selection: $query.sort) {
                        ForEach(SalonSort.allCases) { Text($0.label).tag($0) }
                    } label: { Text("Sort") }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
            }
            if session.canWrite {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNew = true } label: { Label("New salon", systemImage: "plus") }
                }
            }
        }
        .sheet(isPresented: $showNew) {
            NewSalonView(mode: .new) { id in session.push(.salon(id: id, name: nil)) }
        }
        .onChange(of: session.dataVersion) { _, _ in Task { await loader.reload(session) } }
        .refreshable { await loader.reload(session) }
        .task(id: query) {
            // Search waits 400 ms after the last key; chips and sort apply at once.
            if query.search != lastSearch {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                lastSearch = query.search
            }
            await loader.setFilters(query.params, session)
        }
        .onAppear(perform: takeHomeFilter)
        .onChange(of: session.pendingDestination) { _, _ in takeHomeFilter() }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SalonFilter.allCases) { f in
                    Button {
                        Haptics.tap()
                        query.filter = f
                    } label: {
                        Text(f.label)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .foregroundStyle(query.filter == f ? Color.white : Theme.ink)
                            .background(Capsule().fill(query.filter == f ? Theme.navy : Theme.card))
                            .overlay(Capsule().stroke(Theme.inkSecondary.opacity(0.2)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(query.filter == f ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
        }
    }

    /// API 1.4: All · Paid · Trial · Free · Demo → ?type=
    private var typeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("Account").font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSecondary)
                typeChip(nil, String(localized: "All"))
                ForEach(AccountType.choices) { t in typeChip(t, t.label) }
            }
            .padding(.horizontal, 16)
        }
    }

    private func typeChip(_ t: AccountType?, _ label: String) -> some View {
        let on = query.type == t
        return Button {
            Haptics.tap()
            query.type = t
        } label: {
            Text(verbatim: label)
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 12)
                .frame(minHeight: 32)
                .foregroundStyle(on ? Color.white : (t?.color ?? Theme.ink))
                .background(Capsule().fill(on ? (t?.color ?? Theme.navy) : Theme.card))
                .overlay(Capsule().stroke((t?.color ?? Theme.inkSecondary).opacity(0.3)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// A Home card asked for a billing or account type filter.
    private func takeHomeFilter() {
        switch session.pendingDestination {
        case .salons(let billing)?:
            session.pendingDestination = nil
            query.filter = SalonFilter(billing: billing)
            query.type = nil
        case .salonsType(let t)?:
            session.pendingDestination = nil
            query.filter = .all
            query.type = t
        default:
            return
        }
    }
}

/// One salon in the list.
struct SalonRow: View {
    let salon: Salon

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: salon.name)
                    .font(.headline)
                    .foregroundStyle(salon.isSuspended ? Theme.inkSecondary : Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if salon.isSuspended {
                    StatusBadge(text: String(localized: "Suspended"), color: Theme.grey)
                } else if let label = salon.billing?.statusLabel {
                    StatusBadge(text: label, color: Theme.color(for: salon.billing?.status))
                }
                TypeChip(billing: salon.billing)
            }
            HStack(spacing: 4) {
                if let owner = salon.owner?.name, !owner.isEmpty { Text(verbatim: owner) }
                if let owner = salon.owner?.name, !owner.isEmpty, salon.billing?.plan != nil { Text(verbatim: "·") }
                if let plan = salon.billing?.plan { Text(verbatim: plan) }
            }
            .font(.subheadline)
            .foregroundStyle(Theme.inkSecondary)
            .lineLimit(1)

            HStack(spacing: 10) {
                if let until = salon.billing?.until {
                    Label {
                        Text(verbatim: [Formatters.show(until, .day), Formatters.daysLeft(salon.billing?.daysLeft)]
                            .compactMap { $0 }.joined(separator: " · "))
                    } icon: {
                        Image(systemName: "calendar")
                    }
                    .foregroundStyle((salon.billing?.daysLeft ?? 0) < 0 ? Theme.red : Theme.inkSecondary)
                }
                Spacer(minLength: 0)
                if let ago = Formatters.relative(salon.lastActivity) {
                    Label { Text(verbatim: ago) } icon: { Image(systemName: "clock") }
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
            .font(.caption)
            .labelStyle(.titleAndIcon)
        }
        .padding(.vertical, 4)
        .opacity(salon.isSuspended ? 0.65 : 1)
        .accessibilityElement(children: .combine)
    }
}
