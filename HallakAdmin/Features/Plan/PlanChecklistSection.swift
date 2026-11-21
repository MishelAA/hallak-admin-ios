import SwiftUI

/// "This month": counts with − / +1, tick boxes, hints, and a month picker for past months.
/// Each tap is one PATCH /admin/plan/checklist; the screen shows the answer. Never retried.
struct PlanChecklistSection: View {
    let initial: PlanChecklist
    @Environment(AppSession.self) private var session
    @State private var runner = ActionRunner()
    @State private var shown: PlanChecklist?
    @State private var month: String?
    @State private var loadingMonth = false

    private var list: PlanChecklist { shown ?? initial }
    /// nil = this month (the one in /admin/plan).
    private var isPast: Bool { month != nil && month != initial.month }

    var body: some View {
        Section {
            if loadingMonth {
                ProgressView().frame(maxWidth: .infinity)
            }
            ForEach(list.items) { item in
                if item.isCheck { checkRow(item) } else { countRow(item) }
            }
        } header: {
            HStack {
                Text("This month")
                Spacer()
                Menu {
                    ForEach(Self.months(from: initial.month), id: \.self) { m in
                        Button { Task { await open(m) } } label: { Text(verbatim: Self.monthName(m)) }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(verbatim: Self.monthName(list.month))
                        Image(systemName: "chevron.up.chevron.down").font(.caption2)
                    }
                    .font(.subheadline)
                }
                .textCase(nil)
            }
        } footer: {
            if let done = list.done, let of = list.of {
                Text("\(done) of \(of) done")
            }
        }
        .disabled(runner.isRunning || loadingMonth)
        .actionErrorAlert(runner)
        .onChange(of: initial) { _, new in
            if !isPast { shown = new }
        }
    }

    private func countRow(_ item: PlanChecklist.Item) -> some View {
        let value = item.count ?? 0
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                if item.done == true {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green)
                        .accessibilityLabel(Text("Goal reached"))
                }
                Text(verbatim: item.label ?? item.slug)
                Spacer()
                Text(verbatim: item.target.map { "\(value) / \($0)" } ?? String(value))
                    .font(.body.bold().monospacedDigit())
                    .environment(\.layoutDirection, .leftToRight)
                Button {
                    Task { await change(.setChecklist(item.slug, max(0, value - 1), month: month)) }
                } label: {
                    Image(systemName: "minus").frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)
                .disabled(value <= 0)
                .accessibilityLabel(Text("Minus one"))
                Button {
                    Task { await change(.addToChecklist(item.slug, 1, month: month)) }
                } label: {
                    Text(verbatim: "+1").bold().frame(minWidth: 36, minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.actionRed)
                .accessibilityLabel(Text("Add one"))
            }
            hint(item)
        }
    }

    private func checkRow(_ item: PlanChecklist.Item) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: Binding(
                get: { item.checked ?? false },
                set: { on in Task { await change(.setChecklist(item.slug, on, month: month)) } }
            )) {
                Text(verbatim: item.label ?? item.slug)
            }
            .tint(Theme.green)
            hint(item)
        }
    }

    @ViewBuilder
    private func hint(_ item: PlanChecklist.Item) -> some View {
        if let h = item.hint, !h.isEmpty {
            Text(verbatim: h).font(.caption).foregroundStyle(Theme.inkSecondary)
        }
    }

    private func change(_ endpoint: Endpoint) async {
        let answer = await runner.run(session, refreshLists: false) {
            try await ActionRunner.client(session).send(endpoint, as: PlanChecklist.self)
        }
        if let answer { shown = answer }
    }

    private func open(_ m: String) async {
        guard m != list.month else { return }
        if m == initial.month {
            month = nil
            shown = initial
            return
        }
        guard let client = session.client else { return }
        loadingMonth = true
        defer { loadingMonth = false }
        do {
            shown = try await client.fetch(.planChecklist(month: m), as: PlanChecklist.self).value
            month = m
        } catch let e as APIError {
            if await session.handleSessionError(e) { return }
            runner.error = e
        } catch {
            runner.error = .offline
        }
    }

    /// This month and the 11 before it, newest first ("2026-11", "2026-10", …).
    static func months(from current: String, count: Int = 12) -> [String] {
        let parts = current.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2 else { return [current] }
        var (y, m) = (parts[0], parts[1])
        var out: [String] = []
        for _ in 0..<count {
            out.append(String(format: "%04d-%02d", y, m))
            m -= 1
            if m == 0 { m = 12; y -= 1 }
        }
        return out
    }

    /// "2027-03" → "March 2027" in the app language.
    static func monthName(_ ym: String, locale: Locale = Formatters.appLocale) -> String {
        guard let d = Formatters.date(ym + "-01") else { return ym }
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = Formatters.lebanon
        f.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return f.string(from: d)
    }
}
