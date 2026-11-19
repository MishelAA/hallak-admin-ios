import XCTest
@testable import HallakAdmin

@MainActor
final class SessionTests: XCTestCase {
    private var keychain: Keychain!
    private var defaults: UserDefaults!
    private var suite: String!
    /// What the fake Face ID prompt answers.
    private final class Answer { var value = true }
    private let answer = Answer()
    private var biometricAnswer: Bool {
        get { answer.value }
        set { answer.value = newValue }
    }

    override func setUp() async throws {
        StubURLProtocol.reset()
        keychain = Keychain(service: "online.hallak.admin.tests.\(UUID().uuidString)")
        suite = "hallak.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        biometricAnswer = true
    }

    override func tearDown() async throws {
        keychain.removeAll()
        defaults.removePersistentDomain(forName: suite)
        StubURLProtocol.reset()
    }

    private func makeSession() -> AppSession {
        let box = answer
        let lock = BiometricLock(evaluate: { _ in box.value })
        return AppSession(keychain: keychain, urlSession: StubURLProtocol.session(),
                          cache: ETagCache(folder: nil), defaults: defaults, lock: lock)
    }

    /// Answers like hallak.online: ping and me OK, everything else from fixtures.
    private func serveSite(password: String = "abcd efgh ijkl mnop") throws {
        let ping = try Fixture.data("ping"), me = try Fixture.data("me"), overview = try Fixture.data("overview")
        let goodAuth = "Basic " + Data("tester:\(password)".utf8).base64EncodedString()
        StubURLProtocol.handler = { req in
            guard req.value(forHTTPHeaderField: "Authorization") == goodAuth else {
                return (401, [:], Data(#"{"code":"incorrect_password","message":"Wrong password","data":{"status":401}}"#.utf8))
            }
            switch req.url?.path {
            case "/wp-json/hallak/v1/admin/ping": return (200, [:], ping)
            case "/wp-json/hallak/v1/admin/me": return (200, [:], me)
            case "/wp-json/hallak/v1/admin/overview": return (200, ["ETag": "\"o\""], overview)
            default: return (404, [:], try Fixture.data("error_not_found"))
            }
        }
    }

    func testStartsLoggedOutWithoutKeychain() {
        let s = makeSession()
        XCTAssertEqual(s.phase, .loggedOut)
        XCTAssertNil(s.client)
    }

    func testConnectSavesToKeychainAndShowsWelcome() async throws {
        try serveSite()
        let s = makeSession()
        try await s.connect(site: "https://example.test/", username: " tester ", password: "abcd efgh ijkl mnop")

        guard case .welcome(let ping) = s.phase else { return XCTFail("Expected welcome, got \(s.phase)") }
        XCTAssertEqual(ping.hallakCore, "1.4.2")
        XCTAssertEqual(s.me?.user?.username, "mishel-app")
        XCTAssertEqual(keychain.loadCredentials(), testCredentials, "Saved only after ping ok; username trimmed")

        await s.finishWelcome(enableFaceID: true)
        XCTAssertEqual(s.phase, .ready)
        XCTAssertTrue(s.faceIDEnabled)

        let restarted = makeSession()
        XCTAssertEqual(restarted.phase, .ready, "Next launch goes straight to the tabs")
        XCTAssertTrue(restarted.isLocked, "…behind Face ID")
    }

    func testWrongPasswordSavesNothing() async throws {
        try serveSite(password: "the right one")
        let s = makeSession()
        do {
            try await s.connect(site: "https://example.test", username: "tester", password: "wrong")
            XCTFail("Expected an error")
        } catch let e as APIError {
            XCTAssertEqual(e.behaviour, .wrongPassword)
            let failure = LoginFailure(e)
            XCTAssertEqual(failure.field, .password)
            XCTAssertTrue(failure.showHelp)
        }
        XCTAssertNil(keychain.loadCredentials())
        XCTAssertEqual(s.phase, .loggedOut)
        XCTAssertEqual(StubURLProtocol.requests.count, 1, "No retry after a 401")
    }

    func testRefusesHTTPSite() async {
        let s = makeSession()
        do {
            try await s.connect(site: "http://example.test", username: "a", password: "b")
            XCTFail("Expected an error")
        } catch let e as APIError {
            XCTAssertEqual(LoginFailure(e).field, .site)
        } catch { XCTFail("\(error)") }
        XCTAssertTrue(StubURLProtocol.requests.isEmpty, "Nothing is sent over http")
    }

    func testDeclinedFaceIDStaysOff() async throws {
        try serveSite()
        biometricAnswer = false
        let s = makeSession()
        try await s.connect(site: "https://example.test", username: "tester", password: "abcd efgh ijkl mnop")
        await s.finishWelcome(enableFaceID: true)
        XCTAssertFalse(s.faceIDEnabled)
        XCTAssertFalse(s.isLocked)
    }

    func testLocksAfterFiveMinutesInBackground() async throws {
        try keychain.save(testCredentials)
        defaults.set(true, forKey: "faceIDEnabled")
        let s = makeSession()
        XCTAssertTrue(s.isLocked)
        await s.unlock()
        XCTAssertFalse(s.isLocked)

        let now = Date()
        s.simulateBackground(at: now.addingTimeInterval(-4 * 60))
        s.didBecomeActive(now: now)
        XCTAssertFalse(s.isLocked, "4 minutes: still open")

        s.simulateBackground(at: now.addingTimeInterval(-5 * 60 - 1))
        s.didBecomeActive(now: now)
        XCTAssertTrue(s.isLocked, "5 minutes: locked")

        biometricAnswer = false
        await s.unlock()
        XCTAssertTrue(s.isLocked, "A failed Face ID keeps it locked")
    }

    func testNoLockWhenFaceIDOff() throws {
        try keychain.save(testCredentials)
        let s = makeSession()
        XCTAssertFalse(s.isLocked)
        s.simulateBackground(at: Date().addingTimeInterval(-3600))
        s.didBecomeActive()
        XCTAssertFalse(s.isLocked)
    }

    func testNotAdminLogsOutWithNotice() async throws {
        try keychain.save(testCredentials)
        let s = makeSession()
        let handled = await s.handleSessionError(APIError(code: "smapi_forbidden", message: "x", status: 403))
        XCTAssertTrue(handled)
        XCTAssertEqual(s.phase, .loggedOut)
        XCTAssertEqual(s.loginNotice, "This account is not an administrator.")
        XCTAssertNil(keychain.loadCredentials(), "Log out clears the Keychain")

        let other = await s.handleSessionError(APIError(code: "smapi_slow_down", message: "x", status: 429))
        XCTAssertFalse(other, "Rate limits do not log out")
    }

    func testLogout() async throws {
        try serveSite()
        let s = makeSession()
        try await s.connect(site: "https://example.test", username: "tester", password: "abcd efgh ijkl mnop")
        await s.finishWelcome(enableFaceID: true)
        await s.logout()
        XCTAssertEqual(s.phase, .loggedOut)
        XCTAssertNil(s.client)
        XCTAssertNil(s.me)
        XCTAssertFalse(s.faceIDEnabled)
        XCTAssertNil(keychain.loadCredentials())
        XCTAssertNil(s.loginNotice)
    }

    func testHomeNavigation() throws {
        try keychain.save(testCredentials)
        let s = makeSession()
        s.open(.salons, .salons(billing: .overdue))
        XCTAssertEqual(s.selectedTab, .salons)
        XCTAssertEqual(s.pendingDestination, .salons(billing: .overdue))
    }
}

@MainActor
final class ScreenLoaderTests: XCTestCase {
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
                   defaults: UserDefaults(suiteName: "hallak.tests.loader")!, lock: BiometricLock(evaluate: { _ in true }))
    }

    func testLoadThenOfflineKeepsDataWithBanner() async throws {
        let body = try Fixture.data("overview")
        StubURLProtocol.handler = { _ in (200, ["ETag": "\"o\""], body) }
        let s = session()
        let loader = ScreenLoader<Overview>(.overview)
        XCTAssertNil(loader.value)

        await loader.load(s)
        XCTAssertEqual(loader.value?.salons?.total, 23)
        XCTAssertFalse(loader.isOffline)

        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        await loader.refresh(s)
        XCTAssertEqual(loader.value?.salons?.total, 23, "Data stays on screen")
        XCTAssertTrue(loader.isOffline, "…with the offline banner")
    }

    func testFailedWithoutData() async throws {
        StubURLProtocol.handler = { _ in (429, [:], Data(#"{"code":"smapi_slow_down","message":"Slow down","data":{"status":429}}"#.utf8)) }
        let s = session()
        let loader = ScreenLoader<Overview>(.overview)
        await loader.load(s)
        guard case .failed(let e) = loader.state else { return XCTFail("Expected failed") }
        XCTAssertEqual(e.behaviour, .slowDown)
        XCTAssertEqual(StubURLProtocol.requests.count, 1, "No retry loop")
        XCTAssertEqual(s.phase, .ready, "A rate limit does not log out")
    }

    func testRevokedPasswordLogsOut() async throws {
        StubURLProtocol.handler = { _ in (401, [:], Data(#"{"code":"incorrect_password","message":"x","data":{"status":401}}"#.utf8)) }
        let s = session()
        let loader = ScreenLoader<Overview>(.overview)
        await loader.load(s)
        XCTAssertEqual(s.phase, .loggedOut)
        XCTAssertEqual(s.loginNotice, "This is not an Application Password.")
    }
}
