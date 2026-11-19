import SwiftUI

/// What the Activity list asks for: salon, type, date range, search.
struct ActivityQuery: Hashable {
    enum Kind: String, CaseIterable, Identifiable {
        case all, appointment, visit, customer, billing
        var id: String { rawValue }
        var label: LocalizedStringKey {
            switch self {
            case .all: return "All types"
            case .appointment: return "Appointments"
            case .visit: return "Visits"
            case .customer: return "Customers"
            case .billing: return "Billing"
            }
        }
    }

    enum Range: String, CaseIterable, Identifiable {
        case any, today, week, month
        var id: String { rawValue }
        var label: LocalizedStringKey {
            switch self {
            case .any: return "Any time"
            case .today: return "Today"
            case .week: return "Last 7 days"
            case .month: return "This month"
            }
        }
    }

    var salonId: Int?
    var kind = Kind.all
    var range = Range.any
    var search = ""

    /// Days in Lebanon time, "yyyy-MM-dd".
    func params(now: Date = Date()) -> [String: String] {
        var p: [String: String] = [:]
        if let salonId { p["salon_id"] = String(salonId) }
        if kind != .all { p["type"] = kind.rawValue }
        let s = search.trimmingCharacters(in: .whitespaces)
        if !s.isEmpty { p["search"] = s }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = Formatters.lebanon
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.timeZone = Formatters.lebanon
        day.dateFormat = "yyyy-MM-dd"
        let today = day.string(from: now)
        switch range {
        case .any: break
        case .today:
            p["from"] = today; p["to"] = today
        case .week:
            p["from"] = day.string(from: cal.date(byAdding: .day, value: -6, to: now) ?? now); p["to"] = today
        case .month:
            let start = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
            p["from"] = day.string(from: start); p["to"] = today
        }
        return p
    }

    var isFiltered: Bool { kind != .all || range != .any }
}

/// GET /admin/activity: newest first, infinite scroll, filters salon / type / dates / search.
struct ActivityListView: View {
    var salonId: Int?
    var salonName: String?
    @Environment(AppSession.self) private var session
    @State private var loader: PagedLoader<Activity>
    @State private var query: ActivityQuery
    @State private var lastSearch = ""

    init(salonId: Int? = nil, salonName: String? = nil) {
        self.salonId = salonId
        self.salonName = salonName
        let q = ActivityQuery(salonId: salonId)
        _query = State(initialValue: q)
        _loader = State(initialValue: PagedLoader(filters: q.params()) { .activity($0) })
    }

    var body: some View {
        List {
            if loader.isOffline {
                OfflineBanner(time: Formatters.updatedTime(loader.generatedAt) ?? "–") { Task { await loader.reload(session) } }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            if loader.items.isEmpty {
                if let e = loader.error {
                    ErrorView(error: e) { Task { await loader.reload(session) } }.listRowBackground(Color.clear)
                } else if loader.isEmpty {
                    EmptyState(title: "No activity yet", message: query.isFiltered ? "Try another filter." : nil)
                        .listRowBackground(Color.clear)
                } else {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 120).listRowBackground(Color.clear)
                }
            }
            ForEach(loader.items) { item in
                Group {
                    if salonId == nil, let sid = item.salonId {
                        NavigationLink(value: AppRoute.salon(id: sid, name: item.salonName)) { ActivityRow(item: item, showSalon: true) }
                    } else {
                        ActivityRow(item: item, showSalon: salonId == nil)
                    }
                }
                .task { await loader.loadMoreIfNeeded(after: item, session) }
            }
            if loader.list.canLoadMore, !loader.items.isEmpty {
                HStack { Spacer(); ProgressView(); Spacer() }.listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle(salonName.map { Text(verbatim: $0) } ?? Text("Activity"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query.search, prompt: Text("Search the activity"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker(selection: $query.kind) {
                        ForEach(ActivityQuery.Kind.allCases) { Text($0.label).tag($0) }
                    } label: { Text("Type") }
                    Picker(selection: $query.range) {
                        ForEach(ActivityQuery.Range.allCases) { Text($0.label).tag($0) }
                    } label: { Text("When") }
                } label: {
                    Label("Filter", systemImage: query.isFiltered ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
            }
        }
        .refreshable { await loader.reload(session) }
        .task(id: query) {
            if query.search != lastSearch {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                lastSearch = query.search
            }
            await loader.setFilters(query.params(), session)
        }
    }
}

struct ActivityRow: View {
    let item: Activity
    var showSalon = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: item.summary ?? item.action ?? "–").font(.subheadline)
            HStack(spacing: 6) {
                if showSalon, let s = item.salonName { Text(verbatim: s).fontWeight(.medium) }
                if let by = item.by?.name { Text(verbatim: "· \(by)") }
                Spacer()
                if let at = item.at { Text(verbatim: Formatters.relative(at) ?? Formatters.show(at)) }
            }
            .font(.caption)
            .foregroundStyle(Theme.inkSecondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
