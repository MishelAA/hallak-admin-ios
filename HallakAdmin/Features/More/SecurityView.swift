import SwiftUI

/// More → Security (API 1.5): one request, GET /admin/security. Read only: fixes and "These changes are mine"
/// happen in wp-admin (button at the bottom, one-time sign-in link).
struct SecurityView: View {
    @Environment(AppSession.self) private var session
    @State private var loader = ScreenLoader<Security>(.security)
    @State private var showOK = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            switch loader.state {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let error):
                if error.code == "smapi_no_security" {
                    EmptyState(title: "Security is off", message: "The Security plugin is not active on the site.")
                } else {
                    ErrorView(error: error) { Task { await loader.refresh(session) } }
                }
            case .loaded(let answer):
                content(answer.value)
            }
        }
        .background(Theme.background)
        .navigationTitle("Security")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                UpdatedLabel(generatedAt: loader.answer?.generatedAt, isLoading: loader.isLoading)
            }
        }
        .refreshable { await loader.refresh(session) }
        .task { await loader.load(session) }
        .onChange(of: loader.error?.code) { _, code in
            if code == "smapi_no_security" { session.securityOff = true }
        }
    }

    private func content(_ s: Security) -> some View {
        List {
            if loader.isOffline {
                OfflineBanner(time: Formatters.updatedTime(loader.answer?.generatedAt) ?? "–") {
                    Task { await loader.refresh(session) }
                }
                .listRowBackground(Color.clear)
            }

            header(s)
            checks(s)
            files(s.files)
            logins(s.logins)
            twoStep(s.twoStep)

            if session.me?.canOpenLinks ?? true {
                Section {
                    NavigationLink(value: AppRoute.signedIn(.platform("wp-admin"), title: String(localized: "Security in wp-admin"), fallback: nil)) {
                        Label("Open Security in wp-admin", systemImage: "wrench.and.screwdriver")
                    }
                } footer: {
                    Text("Fixes and “These changes are mine” are done in wp-admin → Salons → Security. The app only shows the report.")
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: Header

    private func header(_ s: Security) -> some View {
        Section {
            // Biggest text sizes: the counts go under the ring.
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
                : AnyLayout(HStackLayout(spacing: 18))
            layout {
                let score = s.score ?? 0
                ProgressRing(fraction: Double(score) / 100, color: Security.scoreColor(score),
                             value: String(score), caption: "of 100", size: 112)
                VStack(alignment: .leading, spacing: 8) {
                    count(s.summary?.bad ?? s.badCount, "Fix now", .bad)
                    count(s.summary?.warn ?? s.warnCount, "Should be fixed", .warn)
                    count(s.summary?.ok ?? 0, "Passed", .ok)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .accessibilityElement(children: .combine)
        }
    }

    private func count(_ n: Int, _ title: LocalizedStringKey, _ state: Security.State) -> some View {
        HStack(spacing: 8) {
            Circle().fill(state.color).frame(width: 10, height: 10).accessibilityHidden(true)
            Text(verbatim: String(n)).font(.headline.monospacedDigit()).foregroundStyle(state.color)
            Text(title).font(.subheadline).foregroundStyle(Theme.inkSecondary)
        }
    }

    // MARK: Checks

    @ViewBuilder
    private func checks(_ s: Security) -> some View {
        let all = s.sortedChecks
        let open = all.filter { $0.state != .ok }
        let ok = all.filter { $0.state == .ok }
        if !all.isEmpty {
            Section("Checks") {
                ForEach(open) { CheckRow(check: $0) }
                if !ok.isEmpty {
                    DisclosureGroup(isExpanded: $showOK) {
                        ForEach(ok) { CheckRow(check: $0) }
                    } label: {
                        Label {
                            Text("\(ok.count) checks are OK")
                        } icon: {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green)
                        }
                    }
                }
            }
        }
    }

    // MARK: Files

    @ViewBuilder
    private func files(_ f: Security.Files?) -> some View {
        Section {
            LabeledContent {
                Text(verbatim: f?.lastCheck.map { Formatters.show($0) } ?? String(localized: "Never checked"))
                    .foregroundStyle(f?.lastCheck == nil ? Theme.orange : Theme.inkSecondary)
            } label: { Text("Last check") }

            let n = f?.toLookAt ?? 0
            if n > 0 {
                Label {
                    Text("\(n) files to look at")
                } icon: { Image(systemName: "exclamationmark.triangle.fill") }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.red)
                Text("If you did not upload these files yourself, someone may have planted code.")
                    .font(.footnote)
                    .foregroundStyle(Theme.red)
            } else if f?.lastCheck != nil {
                Label("All files look as expected", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.green)
            }
        } header: {
            Text("Files")
        }

        if let f, (f.toLookAt ?? 0) > 0 {
            ForEach(f.grouped) { g in
                Section {
                    ForEach(g.items) { item in
                        Text(verbatim: item.path)
                            .font(.footnote.monospaced())
                            .environment(\.layoutDirection, .leftToRight)
                            .textSelection(.enabled)
                    }
                } header: {
                    Text(verbatim: "\(Security.Files.groupLabel(g.group)) (\(f.counts?[g.group] ?? g.items.count))")
                }
            }
        }
    }

    // MARK: Logins

    @ViewBuilder
    private func logins(_ l: Security.Logins?) -> some View {
        if let l {
            Section {
                stat("Blocked now", l.blockedNow, red: (l.blockedNow ?? 0) > 0)
                stat("Failed in 24 hours", l.failed24h)
                stat("Blocked in 24 hours", l.blocked24h)
                ForEach(l.recent ?? []) { e in EventRow(event: e) }
            } header: {
                Text("Logins")
            }
        }
    }

    private func stat(_ title: LocalizedStringKey, _ value: Int?, red: Bool = false) -> some View {
        LabeledContent {
            Text(verbatim: String(value ?? 0))
                .font(.body.bold().monospacedDigit())
                .foregroundStyle(red ? Theme.red : Theme.ink)
        } label: { Text(title) }
    }

    // MARK: Two-step login

    @ViewBuilder
    private func twoStep(_ t: Security.TwoStep?) -> some View {
        if let t {
            let ok = t.allProtected ?? false
            Section {
                Label {
                    Text("\(t.withTwoStep ?? 0) of \(t.admins ?? 0) administrators")
                } icon: {
                    Image(systemName: ok ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                }
                .foregroundStyle(ok ? Theme.green : Theme.red)
            } header: {
                Text("Two-step login")
            } footer: {
                if !ok { Text("Every administrator should turn on two-step login.") }
            }
        }
    }
}

struct CheckRow: View {
    let check: Security.Check

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: icon).foregroundStyle(check.state.color).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: check.label).font(.subheadline.weight(.semibold))
                if let h = check.help, !h.isEmpty {
                    Text(verbatim: h).font(.footnote).foregroundStyle(Theme.inkSecondary)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(stateWord))
    }

    private var icon: String {
        switch check.state {
        case .bad: return "xmark.octagon.fill"
        case .warn: return "exclamationmark.triangle.fill"
        case .ok: return "checkmark.circle.fill"
        case .info, .unknown: return "info.circle"
        }
    }

    private var stateWord: String {
        switch check.state {
        case .bad: return String(localized: "Fix now")
        case .warn: return String(localized: "Should be fixed")
        case .ok: return String(localized: "Passed")
        case .info, .unknown: return ""
        }
    }
}

struct EventRow: View {
    let event: Security.Logins.Event

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle().fill((event.level ?? .info).color).frame(width: 8, height: 8).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: event.text ?? event.type ?? "–")
                    .font(.subheadline)
                    .foregroundStyle(event.level == .bad ? Theme.red : (event.level == .warn ? Theme.orange : Theme.ink))
                HStack(spacing: 6) {
                    if let t = event.time { Text(verbatim: Formatters.show(t)) }
                    if let u = event.user, !u.isEmpty { Text(verbatim: "· \(u)") }
                    if let ip = event.ip, !ip.isEmpty {
                        Text(verbatim: "· \(ip)").monospacedDigit().environment(\.layoutDirection, .leftToRight)
                    }
                }
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Home card "Security": score, red when a check is bad or files need a look.
struct SecurityCard: View {
    let security: Security
    let action: () -> Void

    var body: some View {
        let level = security.level
        StatCard(title: "Security", systemImage: "lock.shield",
                 value: security.score.map { "\($0) / 100" },
                 tint: level.color,
                 badge: security.badCount + (security.filesToLookAt > 0 ? 1 : 0),
                 action: action) {
            VStack(alignment: .leading, spacing: 2) {
                if security.badCount > 0 {
                    Text("\(security.badCount) checks to fix now").foregroundStyle(Theme.red)
                }
                if security.filesToLookAt > 0 {
                    Text("\(security.filesToLookAt) files to look at").foregroundStyle(Theme.red)
                }
                if level == .warn {
                    Text("\(security.warnCount) checks should be fixed").foregroundStyle(Theme.orange)
                }
                if level == .ok {
                    Text("All checks OK")
                }
            }
        }
    }
}
