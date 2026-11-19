import Foundation
import Observation

/// Who is logged in, the API client, the lock and the selected tab. One per app.
@Observable
@MainActor
final class AppSession {
    enum Phase: Equatable {
        /// No login saved: show the login screen.
        case loggedOut
        /// Just connected: show the versions and offer Face ID, then Home.
        case welcome(Ping)
        /// Logged in: show the tabs.
        case ready
    }

    enum Tab: Hashable { case home, salons, money, requests, more }

    /// Where a Home card wants to go inside a tab.
    enum Destination: Hashable {
        /// Salons list with a billing filter chip.
        case salons(billing: BillingStatus?)
        /// A screen pushed on the tab (e.g. More → WhatsApp bot).
        case route(AppRoute)
    }

    /// Settings → Language.
    enum LanguageSetting: String, CaseIterable, Identifiable {
        case system, en, ar
        var id: String { rawValue }
    }

    private(set) var phase: Phase = .loggedOut
    private(set) var client: APIClient?
    private(set) var me: Me?
    private(set) var ping: Ping?
    var selectedTab: Tab = .home
    var pendingDestination: Destination?
    /// Navigation of each tab (so Home can open a screen inside another tab).
    var paths: [Tab: [AppRoute]] = [:]
    /// Shown on the login screen after the app logged itself out (revoked password, not an admin...).
    var loginNotice: String?

    // Lock
    private(set) var isLocked = false
    private var backgroundedAt: Date?
    static let lockAfter: TimeInterval = 5 * 60

    private let keychain: Keychain
    private let urlSession: URLSession
    private let cache: ETagCache
    private let defaults: UserDefaults
    private let lock: BiometricLock

    init(keychain: Keychain = Keychain(),
         urlSession: URLSession = .shared,
         cache: ETagCache = ETagCache(),
         defaults: UserDefaults = .standard,
         lock: BiometricLock = BiometricLock()) {
        self.keychain = keychain
        self.urlSession = urlSession
        self.cache = cache
        self.defaults = defaults
        self.lock = lock
        if let saved = keychain.loadCredentials(), let c = try? makeClient(saved) {
            client = c
            phase = .ready
            isLocked = faceIDEnabled
        }
    }

    /// The app language: the Settings choice, or the iPhone language (Arabic or English).
    var language: String {
        switch languageSetting {
        case .en: return "en"
        case .ar: return "ar"
        case .system: return (Locale.preferredLanguages.first ?? "en").hasPrefix("ar") ? "ar" : "en"
        }
    }

    var isRightToLeft: Bool { language == "ar" }

    /// System / English / Arabic. Screens switch at once; a few system texts follow after reopening the app.
    var languageSetting: LanguageSetting {
        get {
            access(keyPath: \.languageSetting)
            return LanguageSetting(rawValue: defaults.string(forKey: "appLanguage") ?? "") ?? .system
        }
        set {
            withMutation(keyPath: \.languageSetting) {
                defaults.set(newValue.rawValue, forKey: "appLanguage")
                if newValue == .system {
                    defaults.removeObject(forKey: "AppleLanguages")
                } else {
                    defaults.set([newValue.rawValue], forKey: "AppleLanguages")
                }
            }
            let code = language
            if let client { Task { await client.setLanguage(code) } }
        }
    }

    var credentials: Credentials? { keychain.loadCredentials() }

    // MARK: Face ID setting (not a secret: a simple on/off in UserDefaults)

    var faceIDEnabled: Bool {
        get { access(keyPath: \.faceIDEnabled); return defaults.bool(forKey: "faceIDEnabled") }
        set { withMutation(keyPath: \.faceIDEnabled) { defaults.set(newValue, forKey: "faceIDEnabled") } }
    }

    var biometryName: String { lock.biometryName }
    var canUseBiometrics: Bool { lock.isAvailable }

    // MARK: Login

    /// Login screen "Connect": ping, then save to the Keychain, then /admin/me.
    func connect(site: String, username: String, password: String) async throws {
        let url = try APIClient.validateSite(site)
        let creds = Credentials(site: url, username: username.trimmingCharacters(in: .whitespaces), password: password)
        let c = try makeClient(creds)
        let answer = try await c.fetch(.ping, as: Ping.self)
        guard !answer.isStale else { throw APIError.offline }
        guard answer.value.ok else { throw APIError(code: "smapi_login", message: String(localized: "The site refused the login.")) }
        guard answer.value.https != false else { throw APIError.notHTTPS }

        try keychain.save(creds)
        client = c
        ping = answer.value
        loginNotice = nil
        me = try? await c.fetch(.me, as: Me.self).value
        phase = .welcome(answer.value)
    }

    /// Welcome screen: done (with or without Face ID).
    func finishWelcome(enableFaceID: Bool) async {
        if enableFaceID {
            faceIDEnabled = await lock.authenticate(reason: String(localized: "Turn on Face ID for Hallak Admin"))
        } else {
            faceIDEnabled = false
        }
        selectedTab = .home
        phase = .ready
    }

    /// Who am I and which plugins are on (hides screens of plugins that are off).
    func refreshMe() async {
        guard let client else { return }
        if let answer = try? await client.fetch(.me, as: Me.self) { me = answer.value }
        if ping == nil, let answer = try? await client.fetch(.ping, as: Ping.self) { ping = answer.value }
    }

    /// Settings "Log out", or forced: clears the Keychain and the saved answers.
    func logout(notice: String? = nil) async {
        await client?.clearCache()
        await cache.clear()
        keychain.removeAll()
        faceIDEnabled = false
        client = nil
        me = nil
        ping = nil
        isLocked = false
        selectedTab = .home
        pendingDestination = nil
        paths = [:]
        loginNotice = notice
        phase = .loggedOut
    }

    /// Errors that end the session (brief, section 4). Returns true when handled here.
    @discardableResult
    func handleSessionError(_ error: APIError) async -> Bool {
        switch error.behaviour {
        case .logOut, .wrongPassword, .wrongUsername, .fixServerHeader:
            await logout(notice: error.userMessage)
            return true
        default:
            return false
        }
    }

    // MARK: Lock

    func didEnterBackground() { backgroundedAt = Date() }

    func didBecomeActive(now: Date = Date()) {
        defer { backgroundedAt = nil }
        guard phase == .ready, faceIDEnabled, let since = backgroundedAt else { return }
        if now.timeIntervalSince(since) >= Self.lockAfter { isLocked = true }
    }

    func unlock() async {
        guard isLocked else { return }
        if await lock.authenticate(reason: String(localized: "Open Hallak Admin")) { isLocked = false }
    }

    // MARK: Navigation from Home

    func open(_ tab: Tab, _ destination: Destination? = nil) {
        switch destination {
        case .route(let r)?:
            pendingDestination = nil
            paths[tab] = [r]
        case .salons?:
            pendingDestination = destination
            paths[tab] = []
        case nil:
            pendingDestination = nil
        }
        selectedTab = tab
    }

    func path(_ tab: Tab) -> [AppRoute] { paths[tab] ?? [] }

    // MARK: Helpers

    private func makeClient(_ c: Credentials) throws -> APIClient {
        try APIClient(credentials: c, language: language, session: urlSession, cache: cache)
    }

    #if DEBUG
    /// Tests: pretend the app went to the background at this time.
    func simulateBackground(at date: Date) { backgroundedAt = date }
    #endif
}
