import SwiftUI

/// GET /admin/health: problems first (with the fix text), then plugins, then the environment.
struct HealthView: View {
    @Environment(AppSession.self) private var session
    @State private var loader = ScreenLoader<Health>(.health)

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
                ErrorView(error: e) { Task { await loader.refresh(session) } }.listRowBackground(Color.clear)
            case .loaded(let a):
                content(a.value)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Health")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                UpdatedLabel(generatedAt: loader.answer?.generatedAt, isLoading: loader.isLoading)
            }
        }
        .refreshable { await loader.refresh(session) }
        .task { await loader.load(session) }
    }

    @ViewBuilder
    private func content(_ h: Health) -> some View {
        if h.available == false {
            EmptyState(title: "The Hallak check plugin is not active", image: "BarberBye").listRowBackground(Color.clear)
        } else {
            Section("Problems") {
                if h.sortedProblems.isEmpty {
                    Label("No problems", systemImage: "checkmark.seal.fill").foregroundStyle(Theme.green)
                } else {
                    ForEach(Array(h.sortedProblems.enumerated()), id: \.offset) { _, p in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: icon(p.level)).foregroundStyle(color(p.level)).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(levelName(p.level)).font(.caption.bold()).foregroundStyle(color(p.level))
                                Text(verbatim: p.text).font(.subheadline)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }

            if let plugins = h.plugins, !plugins.isEmpty {
                Section {
                    ForEach(plugins) { p in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: p.name ?? p.folder ?? "–").font(.subheadline.weight(.semibold))
                                HStack(spacing: 4) {
                                    Text(verbatim: p.installed ?? "–")
                                    if let latest = p.latest, latest != p.installed { Text(verbatim: "→ \(latest)") }
                                }
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Theme.inkSecondary)
                                .environment(\.layoutDirection, .leftToRight)
                            }
                            Spacer()
                            if p.active == false {
                                StatusBadge(text: String(localized: "Not active"), color: Theme.grey)
                            } else if p.upToDate == true {
                                StatusBadge(text: String(localized: "Up to date"), color: Theme.green)
                            } else if p.upToDate == false {
                                StatusBadge(text: String(localized: "Update"), color: Theme.orange)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                } header: {
                    Text("Plugins")
                } footer: {
                    if let v = h.checkVersion { Text("Hallak check \(v)") }
                }
            }

            if let env = h.environment, !env.isEmpty {
                Section("Environment") {
                    ForEach(env.keys.sorted(), id: \.self) { key in
                        LabeledContent {
                            Text(verbatim: env[key]?.value ?? "").monospacedDigit()
                        } label: {
                            Text(verbatim: Self.words(key))
                        }
                    }
                }
            }
        }
    }

    /// "memoryLimit" / "memory_limit" → "Memory limit"
    static func words(_ key: String) -> String {
        var out = ""
        for ch in key {
            if ch == "_" { out.append(" ") }
            else if ch.isUppercase, !out.isEmpty { out.append(" "); out.append(Character(ch.lowercased())) }
            else { out.append(ch) }
        }
        let known = ["wordpress": "WordPress", "php": "PHP", "https": "HTTPS", "mysql": "MySQL", "wp": "WP"]
        if let k = known[out.lowercased()] { return k }
        return out.prefix(1).uppercased() + out.dropFirst()
    }

    private func icon(_ l: Health.Level) -> String {
        switch l {
        case .error: return "xmark.octagon.fill"
        case .warn: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private func color(_ l: Health.Level) -> Color {
        switch l {
        case .error: return Theme.red
        case .warn: return Theme.orange
        case .info: return Theme.grey
        }
    }

    private func levelName(_ l: Health.Level) -> LocalizedStringKey {
        switch l {
        case .error: return "Error"
        case .warn: return "Warning"
        case .info: return "Info"
        }
    }
}

/// GET /admin/owners: owners and their salons (branches).
struct OwnersView: View {
    @Environment(AppSession.self) private var session
    @State private var loader = PagedLoader<Owner> { .owners($0) }
    @State private var search = ""

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
                    EmptyState(title: "No owners").listRowBackground(Color.clear)
                } else {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 120).listRowBackground(Color.clear)
                }
            }
            ForEach(loader.items) { owner in
                Section {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: owner.displayName).font(.headline)
                        HStack(spacing: 6) {
                            if let u = owner.username { Text(verbatim: u) }
                            if let e = owner.email, !e.isEmpty { Text(verbatim: "· \(e)") }
                        }
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                        Text(verbatim: owner.lastLogin.flatMap { Formatters.relative($0) } ?? String(localized: "Never logged in"))
                            .font(.caption)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    .task { await loader.loadMoreIfNeeded(after: owner, session) }
                    ForEach(owner.salons ?? []) { s in
                        NavigationLink(value: AppRoute.salon(id: s.id, name: s.name)) {
                            HStack {
                                Label { Text(verbatim: s.name ?? "#\(s.id)") } icon: { Image(systemName: "scissors") }
                                Spacer()
                                if s.status == .suspended { StatusBadge(text: String(localized: "Suspended"), color: Theme.grey) }
                            }
                        }
                    }
                    if (owner.salons ?? []).isEmpty {
                        Text("No salon").font(.footnote).foregroundStyle(Theme.inkSecondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Owners")
        .searchable(text: $search, prompt: Text("Name, login or email"))
        .refreshable { await loader.reload(session) }
        .task(id: search) {
            if loader.loadedOnce {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
            }
            let s = search.trimmingCharacters(in: .whitespaces)
            await loader.setFilters(s.isEmpty ? [:] : ["search": s], session)
        }
    }
}
