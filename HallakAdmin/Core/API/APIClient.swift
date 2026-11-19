import Foundation

/// Site address + username + Application Password. Lives in the Keychain only.
struct Credentials: Equatable {
    let site: URL
    let username: String
    let password: String

    /// "Basic base64(username:password)". Spaces in the Application Password are kept as typed.
    var authorizationHeader: String {
        "Basic " + Data("\(username):\(password)".utf8).base64EncodedString()
    }
}

/// An answer, and where it came from.
struct Fetched<T> {
    let value: T
    /// "2026-11-19 13:13" (Lebanon time), from the answer's generated_at.
    let generatedAt: String?
    /// true when the network failed and this is the last saved answer.
    let isStale: Bool
    /// When this answer was saved on the phone.
    let savedAt: Date

    func map<U>(_ f: (T) -> U) -> Fetched<U> {
        Fetched<U>(value: f(value), generatedAt: generatedAt, isStale: isStale, savedAt: savedAt)
    }
}

/// The one way the app talks to {site}/wp-json/hallak/v1.
actor APIClient {
    static let apiRoot = "/wp-json/hallak/v1"

    let credentials: Credentials
    private(set) var language: String
    private let session: URLSession
    private let cache: ETagCache

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    init(credentials: Credentials, language: String = "en", session: URLSession = .shared, cache: ETagCache = ETagCache()) throws {
        guard credentials.site.scheme?.lowercased() == "https" else { throw APIError.notHTTPS }
        self.credentials = credentials
        self.language = language == "ar" ? "ar" : "en"
        self.session = session
        self.cache = cache
    }

    func setLanguage(_ code: String) { language = (code == "ar") ? "ar" : "en" }

    // MARK: Site address

    /// Cleans what was typed on the login screen. Refuses anything that is not https.
    static func validateSite(_ text: String) throws -> URL {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasSuffix("/") { s.removeLast() }
        if s.lowercased().hasSuffix(apiRoot) { s.removeLast(apiRoot.count) }
        while s.hasSuffix("/") { s.removeLast() }
        guard s.lowercased().hasPrefix("https://"),
              let url = URL(string: s), let host = url.host, !host.isEmpty else {
            throw APIError.notHTTPS
        }
        return url
    }

    // MARK: Requests

    func url(for endpoint: Endpoint) -> URL {
        var c = URLComponents(string: credentials.site.absoluteString + Self.apiRoot + endpoint.path)!
        if !endpoint.query.isEmpty {
            c.queryItems = endpoint.query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return c.url!
    }

    func request(for endpoint: Endpoint, etag: String? = nil) -> URLRequest {
        var r = URLRequest(url: url(for: endpoint), cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        r.httpMethod = endpoint.method.rawValue
        r.setValue(credentials.authorizationHeader, forHTTPHeaderField: "Authorization")
        r.setValue(language, forHTTPHeaderField: "Accept-Language")
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body = endpoint.body {
            r.httpBody = body
            r.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        }
        if let etag { r.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        return r
    }

    /// The last saved answer, to show a screen instantly before refreshing.
    func cached<T: Decodable>(_ endpoint: Endpoint, as type: T.Type = T.self) async -> Fetched<T>? {
        let key = ETagCache.key(url: url(for: endpoint), language: language)
        guard let entry = await cache.entry(for: key),
              let value = try? Self.decoder.decode(T.self, from: entry.body) else { return nil }
        return Fetched(value: value, generatedAt: Self.generatedAt(entry.body), isStale: true, savedAt: entry.savedAt)
    }

    /// GET with the ETag cache: 304 → saved answer; offline or 5xx → saved answer marked stale.
    func fetch<T: Decodable>(_ endpoint: Endpoint, as type: T.Type = T.self) async throws -> Fetched<T> {
        let key = ETagCache.key(url: url(for: endpoint), language: language)
        let saved = await cache.entry(for: key)

        let data: Data
        let http: HTTPURLResponse
        do {
            let (d, r) = try await session.data(for: request(for: endpoint, etag: saved?.etag))
            guard let h = r as? HTTPURLResponse else { throw APIError.badAnswer }
            data = d
            http = h
        } catch let e as APIError {
            throw e
        } catch {
            if let saved { return try decodeSaved(saved, as: T.self, stale: true) }
            throw APIError.offline
        }

        if http.statusCode == 304 {
            if let saved {
                let refreshed = ETagCache.Entry(etag: saved.etag, body: saved.body, savedAt: Date())
                await cache.store(refreshed, for: key)
                return try decodeSaved(refreshed, as: T.self, stale: false)
            }
            throw APIError.server(304)
        }

        guard (200..<300).contains(http.statusCode) else {
            let error = Self.error(from: data, status: http.statusCode)
            if error.behaviour == .offline, let saved { return try decodeSaved(saved, as: T.self, stale: true) }
            throw error
        }

        let value: T
        do {
            value = try Self.decoder.decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("Hallak API: cannot read \(endpoint.path): \(error)")
            #endif
            throw APIError.badAnswer
        }
        let entry = ETagCache.Entry(etag: http.value(forHTTPHeaderField: "ETag"), body: data, savedAt: Date())
        await cache.store(entry, for: key)
        return Fetched(value: value, generatedAt: Self.generatedAt(data), isStale: false, savedAt: entry.savedAt)
    }

    /// POST / PATCH / PUT / DELETE (API 1.1 and later). Never cached, never retried.
    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type = T.self) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request(for: endpoint))
        } catch {
            throw APIError.offline
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.badAnswer }
        guard (200..<300).contains(http.statusCode) else { throw Self.error(from: data, status: http.statusCode) }
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            throw APIError.badAnswer
        }
    }

    /// Log out: forget the saved answers.
    func clearCache() async { await cache.clear() }

    // MARK: Helpers

    private func decodeSaved<T: Decodable>(_ e: ETagCache.Entry, as: T.Type, stale: Bool) throws -> Fetched<T> {
        guard let value = try? Self.decoder.decode(T.self, from: e.body) else { throw APIError.offline }
        return Fetched(value: value, generatedAt: Self.generatedAt(e.body), isStale: stale, savedAt: e.savedAt)
    }

    static func error(from data: Data, status: Int) -> APIError {
        var e = (try? JSONDecoder().decode(APIError.self, from: data)) ?? .server(status)
        e.status = status
        return e
    }

    private struct Meta: Decodable { let generatedAt: String? }

    static func generatedAt(_ data: Data) -> String? {
        (try? decoder.decode(Meta.self, from: data))?.generatedAt
    }
}
