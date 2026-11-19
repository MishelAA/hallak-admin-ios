import XCTest
@testable import HallakAdmin

final class ActivityQueryTests: XCTestCase {
    private func date(_ s: String) -> Date { Formatters.date(s)! }

    func testFilters() {
        var q = ActivityQuery(salonId: 7)
        XCTAssertEqual(q.params(), ["salon_id": "7"])
        q.kind = .billing
        q.search = " invoice "
        XCTAssertEqual(q.params()["type"], "billing")
        XCTAssertEqual(q.params()["search"], "invoice")
        XCTAssertTrue(q.isFiltered)
    }

    func testDateRangesInLebanonTime() {
        let now = date("2026-11-19 23:30")
        var q = ActivityQuery()
        q.range = .today
        XCTAssertEqual(q.params(now: now)["from"], "2026-11-19")
        XCTAssertEqual(q.params(now: now)["to"], "2026-11-19")
        q.range = .week
        XCTAssertEqual(q.params(now: now)["from"], "2026-11-13")
        q.range = .month
        XCTAssertEqual(q.params(now: now)["from"], "2026-11-01")
        q.range = .any
        XCTAssertNil(q.params(now: now)["from"])
    }
}

final class MoneyAndRequestsTests: XCTestCase {
    func testInvoiceFilter() {
        XCTAssertEqual(MoneyView.InvoiceFilter.unpaid.query, ["status": "unpaid"])
        XCTAssertEqual(MoneyView.InvoiceFilter.void.query, ["status": "void"])
        XCTAssertEqual(MoneyView.InvoiceFilter.all.query, [:])
    }

    func testRequestsQuery() {
        var q = RequestsView.Query()
        XCTAssertEqual(q.params, ["status": "new"])
        q.filter = .all
        q.search = "karim"
        XCTAssertEqual(q.params, ["search": "karim"])
    }

    func testBillingWords() {
        XCTAssertEqual(BillingStatus.grace.label, "Payment due")
        XCTAssertEqual(BillingStatus.free.label, "Not billed")
    }

    func testEnvironmentKeyWords() {
        XCTAssertEqual(HealthView.words("memoryLimit"), "Memory limit")
        XCTAssertEqual(HealthView.words("php"), "PHP")
        XCTAssertEqual(HealthView.words("wordpress"), "WordPress")
    }
}

@MainActor
final class NavigationAndLanguageTests: XCTestCase {
    private var keychain: Keychain!
    private var defaults: UserDefaults!
    private let suite = "hallak.tests.nav.\(UUID().uuidString)"

    override func setUp() async throws {
        keychain = Keychain(service: "online.hallak.admin.tests.\(UUID().uuidString)")
        try keychain.save(testCredentials)
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() async throws {
        keychain.removeAll()
        defaults.removePersistentDomain(forName: suite)
    }

    private func session() -> AppSession {
        AppSession(keychain: keychain, urlSession: StubURLProtocol.session(), cache: ETagCache(folder: nil),
                   defaults: defaults, lock: BiometricLock(evaluate: { _ in true }))
    }

    func testHomeCardOpensScreenInsideMore() {
        let s = session()
        s.open(.more, .route(.whatsapp))
        XCTAssertEqual(s.selectedTab, .more)
        XCTAssertEqual(s.path(.more), [.whatsapp])
        XCTAssertNil(s.pendingDestination)

        s.open(.salons, .salons(billing: .grace))
        XCTAssertEqual(s.pendingDestination, .salons(billing: .grace))
        XCTAssertEqual(s.path(.salons), [])
    }

    func testLanguageSetting() {
        let s = session()
        XCTAssertEqual(s.languageSetting, .system)
        s.languageSetting = .ar
        XCTAssertEqual(s.language, "ar")
        XCTAssertTrue(s.isRightToLeft)
        XCTAssertEqual(defaults.stringArray(forKey: "AppleLanguages"), ["ar"])
        s.languageSetting = .en
        XCTAssertEqual(s.language, "en")
        s.languageSetting = .system
        // The app's own override is gone (the iPhone's list shows through again).
        XCTAssertNil(defaults.persistentDomain(forName: suite)?["AppleLanguages"])
    }

    func testLogoutClearsNavigation() async {
        let s = session()
        s.open(.more, .route(.health))
        await s.logout()
        XCTAssertTrue(s.paths.isEmpty)
    }
}

final class DashboardSignInTests: XCTestCase {
    func testEndpoint() throws {
        let e = Endpoint.webLogin(salonId: 7)
        XCTAssertEqual(e.method, .post)
        XCTAssertEqual(e.path, "/admin/salons/7/web-login")
        let body = try XCTUnwrap(e.body)
        XCTAssertEqual(try JSONSerialization.jsonObject(with: body) as? [String: String], ["tab": ""])
    }

    func testLinkMustBeTheSameSiteOverHTTPS() {
        let site = URL(string: "https://hallak.online")!
        let ok = WebLoginAnswer(url: "https://hallak.online/?hallak_app_login=abc", expiresIn: 60, target: nil)
        XCTAssertNotNil(ok.safeURL(site: site))
        XCTAssertNil(WebLoginAnswer(url: "https://evil.example/?hallak_app_login=abc", expiresIn: 60, target: nil).safeURL(site: site))
        XCTAssertNil(WebLoginAnswer(url: "http://hallak.online/?hallak_app_login=abc", expiresIn: 60, target: nil).safeURL(site: site))
    }

    func testSendDecodesAndNeverCaches() async throws {
        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }
        StubURLProtocol.handler = { req in
            XCTAssertEqual(req.httpMethod, "POST")
            XCTAssertEqual(req.value(forHTTPHeaderField: "Content-Type"), "application/json; charset=utf-8")
            return (200, [:], Data(#"{"url":"https://example.test/?hallak_app_login=x","expires_in":60,"target":"https://example.test/salon/a/"}"#.utf8))
        }
        let client = try APIClient(credentials: testCredentials, session: StubURLProtocol.session(), cache: ETagCache(folder: nil))
        let a = try await client.send(.webLogin(salonId: 1), as: WebLoginAnswer.self)
        XCTAssertEqual(a.expiresIn, 60)
        XCTAssertNotNil(a.safeURL(site: testCredentials.site))
        let cached = await client.cached(.webLogin(salonId: 1), as: WebLoginAnswer.self)
        XCTAssertNil(cached, "Sign-in links are never saved")
    }

    func testPluginMissingIsRecognised() async throws {
        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }
        StubURLProtocol.handler = { _ in
            (404, [:], Data(#"{"code":"rest_no_route","message":"No route was found","data":{"status":404}}"#.utf8))
        }
        let client = try APIClient(credentials: testCredentials, session: StubURLProtocol.session(), cache: ETagCache(folder: nil))
        do {
            _ = try await client.send(.webLogin(salonId: 1), as: WebLoginAnswer.self)
            XCTFail("Expected 404")
        } catch let e as APIError {
            XCTAssertEqual(e.code, "rest_no_route")
            XCTAssertEqual(e.status, 404)
        }
    }
}

final class DemoModeTests: XCTestCase {
    func testFixtureRouting() {
        let root = APIClient.apiRoot + "/admin/"
        XCTAssertEqual(DemoMode.fixture(for: root + "overview"), "overview")
        XCTAssertEqual(DemoMode.fixture(for: root + "salons"), "salons")
        XCTAssertEqual(DemoMode.fixture(for: root + "salons/1"), "salon")
        XCTAssertEqual(DemoMode.fixture(for: root + "salons/1/users"), "salon_users")
        XCTAssertEqual(DemoMode.fixture(for: root + "salons/1/subscription"), "subscription")
        XCTAssertEqual(DemoMode.fixture(for: root + "billing/summary"), "billing_summary")
        XCTAssertEqual(DemoMode.fixture(for: root + "invoices/15"), "invoice")
    }
}
