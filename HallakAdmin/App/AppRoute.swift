import SwiftUI

/// Screens reachable from any tab.
enum AppRoute: Hashable {
    case salon(id: Int, name: String?)
    case invoice(id: Int)
    case activity(salonId: Int?, salonName: String?)
    case salonUsers(id: Int, name: String?)
    case lead(Lead)
    /// A web page inside the app (salon dashboard, salon page, booking page).
    case web(url: URL, title: String)
    case health, owners, whatsapp, ai, settings
}

extension View {
    /// Attach once at the root of each tab's NavigationStack.
    func appDestinations() -> some View {
        navigationDestination(for: AppRoute.self) { route in
            switch route {
            case let .salon(id, name): SalonDetailView(salonId: id, initialName: name)
            case let .invoice(id): InvoiceDetailView(invoiceId: id)
            case let .activity(salonId, salonName): ActivityListView(salonId: salonId, salonName: salonName)
            case let .salonUsers(id, name): SalonUsersView(salonId: id, salonName: name)
            case let .lead(lead): LeadDetailView(lead: lead)
            case let .web(url, title): WebPageView(url: url, title: title)
            case .health: HealthView()
            case .owners: OwnersView()
            case .whatsapp: WhatsAppView()
            case .ai: AIView()
            case .settings: SettingsView()
            }
        }
    }
}

/// A web page opened in Safari inside the app.
struct WebLink: Identifiable, Hashable {
    let url: URL
    var id: String { url.absoluteString }
}
