import XCTest
@testable import HallakAdmin

final class MoneyTests: XCTestCase {
    func testDisplayIsShownAsSent() throws {
        let m = try APIClient.decoder.decode(Money.self, from: Data(#"{"amount": 25.5, "currency": "USD", "display": "$25.50"}"#.utf8))
        XCTAssertEqual(m.display, "$25.50")
        XCTAssertFalse(m.isLBP)
        let l = try APIClient.decoder.decode(Money.self, from: Data(#"{"amount": 1800000, "currency": "LBP", "display": "1,800,000 LBP"}"#.utf8))
        XCTAssertTrue(l.isLBP)
        XCTAssertEqual(l.amount, 1_800_000)
    }

    func testSortByAmountOnly() {
        let a = Money(amount: 30, currency: "USD", display: "$30")
        let b = Money(amount: 240, currency: "USD", display: "$240")
        XCTAssertEqual([b, a].sorted(), [a, b])
        XCTAssertTrue(Money.zero().isZero)
    }
}

final class PagingTests: XCTestCase {
    private struct Row: Decodable, Identifiable { let id: Int }

    func testInfiniteScrollAppendsAndSkipsDuplicates() {
        var list = PagedList<Row>()
        XCTAssertTrue(list.canLoadMore)
        list.append(Page(items: [Row(id: 1), Row(id: 2)], page: 1, perPage: 2, total: 5, pages: 3))
        XCTAssertEqual(list.nextPage, 2)
        list.append(Page(items: [Row(id: 2), Row(id: 3)], page: 2, perPage: 2, total: 5, pages: 3))
        XCTAssertEqual(list.items.map(\.id), [1, 2, 3])
        list.append(Page(items: [Row(id: 4), Row(id: 5)], page: 3, perPage: 2, total: 5, pages: 3))
        XCTAssertFalse(list.canLoadMore)
        XCTAssertEqual(list.total, 5)
        list.append(Page(items: [Row(id: 9)], page: 1, perPage: 2, total: 1, pages: 1))
        XCTAssertEqual(list.items.map(\.id), [9], "Page 1 (pull to refresh) replaces the list")
    }

    func testListQueryLimits() {
        XCTAssertEqual(ListQuery(page: 0, perPage: 0).items, ["page": "1", "per_page": "1"])
        XCTAssertEqual(ListQuery(perPage: 1000).items["per_page"], "100")
        XCTAssertNil(Endpoint.salons(ListQuery(filters: ["search": ""])).query["search"], "Empty filters are not sent")
    }
}

final class FormatterTests: XCTestCase {
    func testParsesLebanonTimeWithoutConverting() throws {
        let d = try XCTUnwrap(Formatters.date("2026-11-17 22:45"))
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = Formatters.lebanon
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: d)
        XCTAssertEqual([c.year, c.month, c.day, c.hour, c.minute], [2026, 11, 17, 22, 45])
        XCTAssertNotNil(Formatters.date("2026-11-17"))
        XCTAssertNotNil(Formatters.date("2026-11-17 22:45:10"))
        XCTAssertNil(Formatters.date("soon"))
    }

    func testShowKeepsHourAsSent() {
        let s = Formatters.show("2026-11-17 22:45", locale: Locale(identifier: "en_GB"))
        XCTAssertTrue(s.contains("22:45"), s)
        XCTAssertEqual(Formatters.show(nil), "–")
        XCTAssertEqual(Formatters.show("not a date"), "not a date")
    }

    func testUpdatedTime() {
        XCTAssertEqual(Formatters.updatedTime("2026-11-19 13:13"), "13:13")
        XCTAssertNil(Formatters.updatedTime(nil))
    }

    func testRelative() throws {
        let now = try XCTUnwrap(Formatters.date("2026-11-19 15:00"))
        let r = try XCTUnwrap(Formatters.relative("2026-11-19 13:00", now: now, locale: Locale(identifier: "en_US")))
        XCTAssertTrue(r.contains("2"), r)
    }

    func testDaysLeft() {
        XCTAssertNil(Formatters.daysLeft(nil))
        XCTAssertNotNil(Formatters.daysLeft(0))
        XCTAssertNotEqual(Formatters.daysLeft(3), Formatters.daysLeft(-3))
    }
}

final class KeychainTests: XCTestCase {
    private let keychain = Keychain(service: "online.hallak.admin.tests.\(UUID().uuidString)")

    override func tearDown() { keychain.removeAll() }

    func testSaveLoadRemove() throws {
        XCTAssertNil(keychain.loadCredentials())
        try keychain.save(testCredentials)
        XCTAssertEqual(keychain.loadCredentials(), testCredentials)

        try keychain.set("other user", for: .username)
        XCTAssertEqual(keychain.get(.username), "other user", "Saving again updates")

        keychain.removeAll()
        XCTAssertNil(keychain.loadCredentials())
        XCTAssertNil(keychain.get(.password))
    }

    func testRefusesHTTPSiteFromKeychain() throws {
        try keychain.set("http://hallak.online", for: .site)
        try keychain.set("u", for: .username)
        try keychain.set("p", for: .password)
        XCTAssertNil(keychain.loadCredentials())
    }
}
