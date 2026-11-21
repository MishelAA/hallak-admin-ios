#if DEBUG
import Foundation

/// Debug builds only: `-HallakDemo YES` runs the app on the bundled test answers (DemoData/*.json),
/// so the CI can take screenshots of every screen without a real login.
/// Optional: `-HallakTab salons|money|requests|more` and `-HallakRoute salon|invoice|lead|health|owners|whatsapp|ai|settings|activity`.
/// The Release build (the IPA) leaves DemoData out (EXCLUDED_SOURCE_FILE_NAMES = *.json).
enum DemoMode {
    static var isOn: Bool { UserDefaults.standard.bool(forKey: "HallakDemo") }

    @MainActor
    static func makeSession() -> AppSession? {
        guard isOn else { return nil }
        let keychain = Keychain(service: "online.hallak.admin.demo")
        try? keychain.save(Credentials(site: URL(string: "https://demo.hallak.test")!, username: "mishel-app", password: "demo demo demo demo"))
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DemoURLProtocol.self]
        let defaults = UserDefaults(suiteName: "hallak.demo") ?? .standard
        defaults.set(false, forKey: "faceIDEnabled")
        let session = AppSession(keychain: keychain, urlSession: URLSession(configuration: config),
                                 cache: ETagCache(folder: nil), defaults: defaults)

        let args = UserDefaults.standard
        let tab: AppSession.Tab
        switch args.string(forKey: "HallakTab") {
        case "salons": tab = .salons
        case "money": tab = .money
        case "requests": tab = .requests
        case "more": tab = .more
        default: tab = .home
        }
        let route: AppRoute?
        switch args.string(forKey: "HallakRoute") {
        case "salon": route = .salon(id: 1, name: "Emmanuel Hairstyle")
        case "invoice": route = .invoice(id: 15)
        case "lead":
            let leads = try? APIClient.decoder.decode(LeadsPage.self, from: data("leads") ?? Data())
            route = leads?.page.items.first.map { AppRoute.lead($0) }
        case "health": route = .health
        case "owners": route = .owners
        case "whatsapp": route = .whatsapp
        case "ai": route = .ai
        case "settings": route = .settings
        case "plan": route = .businessPlan
        case "activity": route = .activity(salonId: nil, salonName: nil)
        case "web": route = .web(url: URL(string: "https://hallak.online/")!, title: "Salon page")
        default: route = nil
        }
        session.open(tab, route.map { .route($0) })
        return session
    }

    static func data(_ name: String) -> Data? {
        Bundle.main.url(forResource: name, withExtension: "json").flatMap { try? Data(contentsOf: $0) }
    }

    /// /wp-json/hallak/v1/admin/... → fixture name.
    static func fixture(for path: String) -> String? {
        let p = path.replacingOccurrences(of: APIClient.apiRoot + "/admin/", with: "")
        let parts = p.split(separator: "/").map(String.init)
        let first = parts.first ?? ""
        switch (first, parts.count) {
        case ("salons", 1): return "salons"
        case ("salons", 2): return "salon"
        case ("salons", 3): return parts[2] == "users" ? "salon_users" : "subscription"
        case ("invoices", 1): return "invoices"
        case ("invoices", 2): return "invoice"
        case ("billing", 2): return "billing_summary"
        case ("plan", 2): return "plan_checklist"
        case (_, 1): return first
        default: return nil
        }
    }
}

final class DemoURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let name = request.url.map { DemoMode.fixture(for: $0.path) } ?? nil
        let body = name.flatMap(DemoMode.data) ?? DemoMode.data("error_not_found") ?? Data()
        let status = name.flatMap(DemoMode.data) == nil ? 404 : 200
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
#endif
