import SwiftUI

/// GET /admin/activity: newest first, infinite scroll. M3: optional salon filter; M5 adds the other filters.
struct ActivityListView: View {
    var salonId: Int?
    var salonName: String?
    @Environment(AppSession.self) private var session
    @State private var loader: PagedLoader<Activity>
    @State private var search = ""

    init(salonId: Int? = nil, salonName: String? = nil) {
        self.salonId = salonId
        self.salonName = salonName
        let filters = salonId.map { ["salon_id": String($0)] } ?? [:]
        _loader = State(initialValue: PagedLoader(filters: filters) { .activity($0) })
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
                    EmptyState(title: "No activity yet").listRowBackground(Color.clear)
                } else {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 120).listRowBackground(Color.clear)
                }
            }
            ForEach(loader.items) { item in
                ActivityRow(item: item, showSalon: salonId == nil)
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
        .searchable(text: $search, prompt: Text("Search the activity"))
        .refreshable { await loader.reload(session) }
        .task(id: search) {
            if !search.isEmpty || loader.loadedOnce {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
            }
            var f = loader.filters
            f["search"] = search.trimmingCharacters(in: .whitespaces)
            await loader.setFilters(f.filter { !$0.value.isEmpty }, session)
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
