import XCTest
@testable import HallakAdmin

final class APIClientTests: XCTestCase {
    private var client: APIClient!

    override func setUp() async throws {
        StubURLProtocol.reset()
        client = try APIClient(credentials: testCredentials, language: "ar", session: StubURLProtocol.session(), cache: ETagCache(folder: nil))
    }

    override func tearDown() {
        StubURLProtocol.reset()
    }

    func testRefusesHTTP() {
        let plain = Credentials(site: URL(string: "http://hallak.online")!, username: "a", password: "b")
        XCTAssertThrowsError(try APIClient(credentials: plain)) { error in
            XCTAssertEqual((error as? APIError)?.code, "smapi_https")
        }
    }

    func testValidateSite() throws {
        XCTAssertEqual(try APIClient.validateSite("  https://hallak.online/ ").absoluteString, "https://hallak.online")
        XCTAssertEqual(try APIClient.validateSite("https://hallak.online/wp-json/hallak/v1").absoluteString, "https://hallak.online")
        XCTAssertEqual(try APIClient.validateSite("https://staging.hallak.online").absoluteString, "https://staging.hallak.online")
        XCTAssertThrowsError(try APIClient.validateSite("http://hallak.online"))
        XCTAssertThrowsError(try APIClient.validateSite("hallak.online"))
        XCTAssertThrowsError(try APIClient.validateSite("https://"))
    }

    func testRequestHeadersAndURL() async throws {
        let r = await client.request(for: .salons(ListQuery(page: 2, perPage: 500, filters: ["search": "emm", "billing": "grace", "status": ""])))
        XCTAssertEqual(r.url?.absoluteString, "https://example.test/wp-json/hallak/v1/admin/salons?billing=grace&page=2&per_page=100&search=emm")
        XCTAssertEqual(r.httpMethod, "GET")
        XCTAssertEqual(r.value(forHTTPHeaderField: "Accept-Language"), "ar")
        let expected = "Basic " + Data("tester:abcd efgh ijkl mnop".utf8).base64EncodedString()
        XCTAssertEqual(r.value(forHTTPHeaderField: "Authorization"), expected)
        XCTAssertNil(r.value(forHTTPHeaderField: "If-None-Match"))
    }

    func testFetchDecodesAndSendsETagNextTime() async throws {
        let body = try Fixture.data("overview")
        StubURLProtocol.handler = { req in
            if req.value(forHTTPHeaderField: "If-None-Match") == "\"v1\"" { return (304, [:], Data()) }
            return (200, ["ETag": "\"v1\"", "Content-Type": "application/json"], body)
        }

        let first: Fetched<Overview> = try await client.fetch(.overview)
        XCTAssertEqual(first.value.salons?.total, 23)
        XCTAssertFalse(first.isStale)
        XCTAssertEqual(first.generatedAt, "2026-11-19 13:13")

        let second: Fetched<Overview> = try await client.fetch(.overview)
        XCTAssertEqual(StubURLProtocol.requests.count, 2)
        XCTAssertEqual(StubURLProtocol.requests[1].value(forHTTPHeaderField: "If-None-Match"), "\"v1\"")
        XCTAssertEqual(second.value, first.value, "304 → the saved answer")
        XCTAssertFalse(second.isStale)
    }

    func testCacheIsPerLanguage() async throws {
        let body = try Fixture.data("ping")
        StubURLProtocol.handler = { _ in (200, ["ETag": "\"p\""], body) }
        _ = try await client.fetch(.ping, as: Ping.self)
        await client.setLanguage("en")
        _ = try await client.fetch(.ping, as: Ping.self)
        XCTAssertNil(StubURLProtocol.requests[1].value(forHTTPHeaderField: "If-None-Match"), "English has its own cache entry")
        let cachedEN = await client.cached(.ping, as: Ping.self)
        XCTAssertNotNil(cachedEN)
    }

    func testOfflineFallsBackToSavedAnswer() async throws {
        let body = try Fixture.data("billing_summary")
        StubURLProtocol.handler = { _ in (200, ["ETag": "\"b\""], body) }
        _ = try await client.fetch(.billingSummary, as: BillingSummary.self)

        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let offline = try await client.fetch(.billingSummary, as: BillingSummary.self)
        XCTAssertTrue(offline.isStale)
        XCTAssertEqual(offline.value.mrr?.display, "$690")

        StubURLProtocol.handler = { _ in (503, [:], Data("<html>busy</html>".utf8)) }
        let busy = try await client.fetch(.billingSummary, as: BillingSummary.self)
        XCTAssertTrue(busy.isStale, "5xx → saved answer + offline banner")
    }

    func testOfflineWithoutSavedAnswerThrows() async {
        StubURLProtocol.handler = { _ in throw URLError(.timedOut) }
        do {
            _ = try await client.fetch(.health, as: Health.self)
            XCTFail("Expected offline")
        } catch {
            XCTAssertEqual((error as? APIError)?.behaviour, .offline)
        }
    }

    func testServerErrorIsDecoded() async throws {
        let body = try Fixture.data("error_not_found")
        StubURLProtocol.handler = { _ in (404, [:], body) }
        do {
            _ = try await client.fetch(.salon(999), as: SalonDetail.self)
            XCTFail("Expected an error")
        } catch let e as APIError {
            XCTAssertEqual(e.code, "smapi_not_found")
            XCTAssertEqual(e.status, 404)
        }
    }

    func test401IsNotServedFromCache() async throws {
        let body = try Fixture.data("me")
        StubURLProtocol.handler = { _ in (200, [:], body) }
        _ = try await client.fetch(.me, as: Me.self)
        StubURLProtocol.handler = { _ in
            (401, [:], Data(#"{"code":"incorrect_password","message":"x","data":{"status":401}}"#.utf8))
        }
        do {
            _ = try await client.fetch(.me, as: Me.self)
            XCTFail("A revoked password must not show saved data")
        } catch let e as APIError {
            XCTAssertEqual(e.behaviour, .wrongPassword)
        }
        XCTAssertEqual(StubURLProtocol.requests.count, 2, "No automatic retry")
    }

    func testBadJSONIsAnError() async {
        StubURLProtocol.handler = { _ in (200, [:], Data(#"{"items": "oops"}"#.utf8)) }
        do {
            _ = try await client.fetch(.salons(), as: Page<Salon>.self)
            XCTFail("Expected bad answer")
        } catch {
            XCTAssertEqual((error as? APIError)?.code, "bad_answer")
        }
    }

    func testClearCache() async throws {
        let body = try Fixture.data("ping")
        StubURLProtocol.handler = { _ in (200, ["ETag": "\"p\""], body) }
        _ = try await client.fetch(.ping, as: Ping.self)
        let before = await client.cached(.ping, as: Ping.self)
        XCTAssertNotNil(before)
        await client.clearCache()
        let after = await client.cached(.ping, as: Ping.self)
        XCTAssertNil(after)
    }

    func testDiskCacheSurvivesRestart() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let body = try Fixture.data("plans")
        StubURLProtocol.handler = { _ in (200, ["ETag": "\"pl\""], body) }
        let a = try APIClient(credentials: testCredentials, session: StubURLProtocol.session(), cache: ETagCache(folder: folder))
        _ = try await a.fetch(.plans(), as: ItemList<Plan>.self)

        let b = try APIClient(credentials: testCredentials, session: StubURLProtocol.session(), cache: ETagCache(folder: folder))
        let saved = await b.cached(.plans(), as: ItemList<Plan>.self)
        XCTAssertEqual(saved?.value.items.count, 3)
    }
}
