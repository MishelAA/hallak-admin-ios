import Foundation

/// An error from the Hallak API, or from talking to it.
/// The server always answers `{ "code", "message", "data": { "status", "field", "check" } }`.
struct APIError: Error, Equatable, Decodable {
    let code: String
    let message: String
    var status: Int?
    var field: String?
    /// Yes/no diagnostics sent with `smapi_login` (shown in a "Details" disclosure).
    var check: [String: String]?

    init(code: String, message: String, status: Int? = nil, field: String? = nil, check: [String: String]? = nil) {
        self.code = code
        self.message = message
        self.status = status
        self.field = field
        self.check = check
    }

    private enum CodingKeys: String, CodingKey { case code, message, data }
    private struct Payload: Decodable {
        let status: Int?
        let field: String?
        let check: [String: FlexibleString]?
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = try c.decode(String.self, forKey: .code)
        message = (try? c.decode(String.self, forKey: .message)) ?? ""
        let data = try? c.decodeIfPresent(Payload.self, forKey: .data)
        status = data?.status
        field = data?.field
        check = data?.check?.mapValues(\.value)
    }

    // MARK: Errors made by the app itself

    static func server(_ status: Int) -> APIError {
        APIError(code: "server", message: String(localized: "Server problem, try again."), status: status)
    }
    static let offline = APIError(code: "offline", message: String(localized: "No connection."))
    static let notHTTPS = APIError(code: "smapi_https", message: String(localized: "The site must use https."))
    static let badAnswer = APIError(code: "bad_answer", message: String(localized: "The server sent an answer the app does not understand."))
}

extension APIError {
    /// What the app does with this error (brief, section 4).
    enum Behaviour: Equatable {
        /// 401 smapi_no_auth_header: the server strips the Authorization header. Stay on login.
        case fixServerHeader
        /// Unknown username: back to login, highlight the username field.
        case wrongUsername
        /// Not an Application Password: back to login, with the help link.
        case wrongPassword
        /// Show the server message (with optional yes/no details). Stay on login.
        case loginMessage
        /// Not an administrator, or not https: log out.
        case logOut
        /// 404 smapi_not_found: show "Not found" and go back.
        case notFound
        /// That plugin is off: hide the screen.
        case pluginOff
        /// 429 smapi_slow_down: "wait a minute". No retry loop.
        case slowDown
        /// 429 smapi_locked: "locked for 15 minutes".
        case locked
        /// 5xx or no connection: show saved data with an offline banner and Retry.
        case offline
        /// Anything else: show the message.
        case other
    }

    var behaviour: Behaviour {
        switch code {
        case "smapi_no_auth_header": return .fixServerHeader
        case "invalid_username", "smapi_login_user": return .wrongUsername
        case "incorrect_password", "smapi_login_password": return .wrongPassword
        case "smapi_app_passwords_off", "smapi_login": return .loginMessage
        case "smapi_forbidden", "smapi_https": return .logOut
        case "smapi_not_found": return .notFound
        case "smapi_no_billing", "smapi_no_site", "smapi_no_whatsapp", "smapi_no_ai": return .pluginOff
        case "smapi_slow_down": return .slowDown
        case "smapi_locked": return .locked
        case "offline", "server": return .offline
        default:
            if let s = status, s >= 500 { return .offline }
            if status == 401 { return .loginMessage }
            return .other
        }
    }

    /// Never retried automatically: 401s and rate limits.
    var mustNotRetry: Bool {
        status == 401 || status == 429
            || [.wrongUsername, .wrongPassword, .fixServerHeader, .loginMessage, .slowDown, .locked].contains(behaviour)
    }

    /// The text to show.
    var userMessage: String {
        switch behaviour {
        case .fixServerHeader:
            return String(localized: "The server did not receive the login. In wp-admin → Salons → iPhone app (API) press Fix the server.")
        case .wrongUsername:
            return String(localized: "Unknown username.")
        case .wrongPassword:
            return String(localized: "This is not an Application Password.")
        case .logOut:
            return code == "smapi_https"
                ? String(localized: "The site must use https.")
                : String(localized: "This account is not an administrator.")
        case .notFound:
            return String(localized: "Not found.")
        case .slowDown:
            return String(localized: "Too many requests, wait a minute.")
        case .locked:
            return String(localized: "Locked for 15 minutes after wrong passwords.")
        case .offline:
            return message.isEmpty ? String(localized: "No connection.") : message
        case .loginMessage, .pluginOff, .other:
            return message.isEmpty ? String(localized: "Something went wrong.") : message
        }
    }
}

/// Decodes a JSON string, number or bool as text (the server is PHP: some values arrive as either).
struct FlexibleString: Decodable, Hashable {
    let value: String

    init(_ value: String) { self.value = value }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { value = "" }
        else if let s = try? c.decode(String.self) { value = s }
        else if let b = try? c.decode(Bool.self) { value = b ? "yes" : "no" }
        else if let i = try? c.decode(Int.self) { value = String(i) }
        else if let d = try? c.decode(Double.self) { value = String(d) }
        else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "Not a simple value") }
    }
}
