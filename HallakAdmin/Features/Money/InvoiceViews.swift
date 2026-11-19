import SwiftUI

extension InvoiceStatus {
    var label: String {
        switch self {
        case .paid: return String(localized: "Paid")
        case .unpaid: return String(localized: "Unpaid")
        case .void: return String(localized: "Cancelled")
        case .unknown: return String(localized: "Other")
        }
    }
}

extension Invoice {
    /// "7 Nov 2026 – 7 Dec 2026"
    var periodText: String? {
        guard periodFrom != nil || periodTo != nil else { return nil }
        return "\(Formatters.show(periodFrom, .day)) – \(Formatters.show(periodTo, .day))"
    }

    /// Short text for the Share button (no PDF in v1).
    var shareText: String {
        var lines = ["Hallak · \(title)"]
        if let s = salonName { lines.append(s) }
        if let p = plan { lines.append(p + (months.map { " · \($0) " + String(localized: "months") } ?? "")) }
        if let period = periodText { lines.append(period) }
        if let a = amount { lines.append(a.display) }
        lines.append((status ?? .unknown).label + (methodLabel.map { " · \($0)" } ?? ""))
        if let paid = paidAt { lines.append(Formatters.show(paid)) }
        return lines.joined(separator: "\n")
    }
}

/// One invoice in a list: number, salon, period, amount, status, method.
struct InvoiceRow: View {
    let invoice: Invoice
    var showSalon = true

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: invoice.title).font(.subheadline.weight(.semibold)).monospacedDigit()
                if showSalon, let s = invoice.salonName { Text(verbatim: s).font(.subheadline) }
                if let p = invoice.periodText { Text(verbatim: p).font(.caption).foregroundStyle(Theme.inkSecondary) }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                MoneyText(money: invoice.amount).font(.subheadline.weight(.semibold))
                StatusBadge(text: (invoice.status ?? .unknown).label, color: Theme.color(for: invoice.status))
                if let m = invoice.methodLabel { Text(verbatim: m).font(.caption2).foregroundStyle(Theme.inkSecondary) }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// GET /admin/invoices/{id}
struct InvoiceDetailView: View {
    let invoiceId: Int
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var loader: ScreenLoader<InvoiceAnswer>

    init(invoiceId: Int) {
        self.invoiceId = invoiceId
        _loader = State(initialValue: ScreenLoader(.invoice(invoiceId)))
    }

    var body: some View {
        List {
            switch loader.state {
            case .loading:
                ProgressView().frame(maxWidth: .infinity)
            case .failed(let e):
                ErrorView(error: e) { Task { await loader.refresh(session) } }.listRowBackground(Color.clear)
            case .loaded(let answer):
                let inv = answer.value.invoice
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: inv.title).font(.title3.bold()).monospacedDigit()
                        MoneyText(money: inv.amount).font(.statNumber)
                        StatusBadge(text: (inv.status ?? .unknown).label, color: Theme.color(for: inv.status))
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    if let sid = inv.salonId {
                        NavigationLink(value: AppRoute.salon(id: sid, name: inv.salonName)) {
                            LabeledContent { Text(verbatim: inv.salonName ?? "#\(sid)") } label: { Text("Salon") }
                        }
                    }
                    InfoRow(label: "Plan", value: inv.plan)
                    InfoRow(label: "Period", value: inv.periodText)
                    InfoRow(label: "Months", value: inv.months.map(String.init))
                    InfoRow(label: "Method", value: inv.methodLabel)
                    InfoRow(label: "Paid at", value: inv.paidAt.map { Formatters.show($0) })
                    InfoRow(label: "Created", value: inv.createdAt.map { Formatters.show($0) })
                }
                if let note = inv.note, !note.isEmpty {
                    Section("Note") { Text(verbatim: note) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Invoice")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let inv = loader.value?.invoice {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: inv.shareText) { Label("Share", systemImage: "square.and.arrow.up") }
                }
            }
        }
        .refreshable { await loader.refresh(session) }
        .task { await loader.load(session) }
        .onChange(of: loader.error) { _, e in
            if e?.behaviour == .notFound, loader.value == nil { dismiss() }
        }
    }
}
