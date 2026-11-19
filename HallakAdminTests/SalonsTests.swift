import XCTest
@testable import HallakAdmin

final class SalonQueryTests: XCTestCase {
    func testChipsMapToAPIParameters() {
        XCTAssertEqual(SalonFilter.all.query, [:])
        XCTAssertEqual(SalonFilter.active.query, ["status": "active"])
        XCTAssertEqual(SalonFilter.suspended.query, ["status": "suspended"])
        XCTAssertEqual(SalonFilter.trial.query, ["billing": "trial"])
        XCTAssertEqual(SalonFilter.paid.query, ["billing": "active"])
        XCTAssertEqual(SalonFilter.due.query, ["billing": "grace"])
        XCTAssertEqual(SalonFilter.overdue.query, ["billing": "overdue"])
        XCTAssertEqual(SalonFilter.notBilled.query, ["billing": "free"])
    }

    func testHomeBillingStatusPicksTheChip() {
        XCTAssertEqual(SalonFilter(billing: .grace), .due)
        XCTAssertEqual(SalonFilter(billing: .active), .paid)
        XCTAssertEqual(SalonFilter(billing: .free), .notBilled)
        XCTAssertEqual(SalonFilter(billing: nil), .all)
    }

    func testQueryParams() {
        var q = SalonQuery()
        XCTAssertEqual(q.params, [:], "Default: newest first, no filter")
        q.search = "  70 123 "
        q.filter = .overdue
        q.sort = .until
        XCTAssertEqual(q.params, ["search": "70 123", "billing": "overdue", "sort": "until"])
    }
}

final class ContactTests: XCTestCase {
    func testPhoneMailWhatsApp() {
        XCTAssertEqual(Contact.phoneURL("+961 70 123 456")?.absoluteString, "tel:+96170123456")
        XCTAssertNil(Contact.phoneURL("12"))
        XCTAssertEqual(Contact.mailURL("gio@example.com")?.absoluteString, "mailto:gio@example.com")
        XCTAssertNil(Contact.mailURL(""))
        XCTAssertNotNil(Contact.whatsappURL("https://wa.me/96170123456"))
        XCTAssertNil(Contact.whatsappURL("http://wa.me/961"), "Only https")
        XCTAssertNil(Contact.whatsappURL("https://evil.example/wa.me"), "Only wa.me links from the API")
        XCTAssertNil(Contact.webURL("javascript:alert(1)"))
    }

    func testInvoiceShareText() throws {
        let inv = try Fixture.decode(InvoiceAnswer.self, "invoice").invoice
        let text = inv.shareText
        XCTAssertTrue(text.contains("HL-2026-0015"))
        XCTAssertTrue(text.contains("$240"))
        XCTAssertTrue(text.contains("Studio 7"))
    }
}

@MainActor
final class PagedLoaderTests: XCTestCase {
    private var keychain: Keychain!

    override func setUp() async throws {
        StubURLProtocol.reset()
        keychain = Keychain(service: "online.hallak.admin.tests.\(UUID().uuidString)")
        try keychain.save(testCredentials)
    }

    override func tearDown() async throws {
        keychain.removeAll()
        StubURLProtocol.reset()
    }

    private func session() -> AppSession {
        AppSession(keychain: keychain, urlSession: StubURLProtocol.session(), cache: ETagCache(folder: nil),
                   defaults: UserDefaults(suiteName: "hallak.tests.paged")!, lock: BiometricLock(evaluate: { _ in true }))
    }

    /// 5 salons, 2 per page; names say which filter answered.
    private func serveSalons() {
        StubURLProtocol.handler = { req in
            let items = URLComponents(url: req.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let q = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
            let page = Int(q["page"] ?? "1") ?? 1
            let tag = q["billing"] ?? "all"
            let ids = Array(((page - 1) * 2 + 1)...min(page * 2, 5))
            let rows = ids.map { #"{"id": \#($0), "name": "\#(tag) \#($0)"}"# }.joined(separator: ",")
            let body = #"{"items": [\#(rows)], "page": \#(page), "per_page": 2, "total": 5, "pages": 3, "generated_at": "2026-11-19 13:13"}"#
            return (200, [:], Data(body.utf8))
        }
    }

    func testPagesLoadAsYouScroll() async {
        serveSalons()
        let s = session()
        let loader = PagedLoader<Salon>(perPage: 2) { .salons($0) }
        await loader.reload(s)
        XCTAssertEqual(loader.items.map(\.id), [1, 2])
        XCTAssertEqual(loader.list.total, 5)

        await loader.loadMoreIfNeeded(after: loader.items[1], s)
        XCTAssertEqual(loader.items.map(\.id), [1, 2, 3, 4])
        await loader.loadMoreIfNeeded(after: loader.items[3], s)
        XCTAssertEqual(loader.items.map(\.id), [1, 2, 3, 4, 5])
        XCTAssertFalse(loader.list.canLoadMore)

        let before = StubURLProtocol.requests.count
        await loader.loadMoreIfNeeded(after: loader.items[4], s)
        XCTAssertEqual(StubURLProtocol.requests.count, before, "No request after the last page")
        XCTAssertEqual(StubURLProtocol.requests[1].url?.query?.contains("page=2"), true)
    }

    func testFilterChangeStartsAgainFromPageOne() async {
        serveSalons()
        let s = session()
        let loader = PagedLoader<Salon>(perPage: 2) { .salons($0) }
        await loader.reload(s)
        await loader.loadMoreIfNeeded(after: loader.items[1], s)
        XCTAssertEqual(loader.items.count, 4)

        await loader.setFilters(["billing": "overdue"], s)
        XCTAssertEqual(loader.items.map(\.name), ["overdue 1", "overdue 2"])
        XCTAssertEqual(StubURLProtocol.requests.last?.url?.query?.contains("billing=overdue"), true)

        let count = StubURLProtocol.requests.count
        await loader.setFilters(["billing": "overdue"], s)
        XCTAssertEqual(StubURLProtocol.requests.count, count, "Same filters: nothing reloaded")
    }

    func testEmptyList() async {
        StubURLProtocol.handler = { _ in (200, [:], Data(#"{"items": [], "page": 1, "per_page": 25, "total": 0, "pages": 0}"#.utf8)) }
        let s = session()
        let loader = PagedLoader<Salon> { .salons($0) }
        await loader.reload(s)
        XCTAssertTrue(loader.isEmpty)
        XCTAssertFalse(loader.list.canLoadMore)
    }
}
