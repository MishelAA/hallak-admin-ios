import XCTest
@testable import HallakAdmin

/// Each error code of the brief's section 4 → the right behaviour.
final class APIErrorTests: XCTestCase {
    func testDecodesServerShape() throws {
        let e = try JSONDecoder().decode(APIError.self, from: Fixture.data("error_not_found"))
        XCTAssertEqual(e.code, "smapi_not_found")
        XCTAssertEqual(e.message, "Salon not found.")
        XCTAssertEqual(e.status, 404)
        XCTAssertEqual(e.behaviour, .notFound)
    }

    func testLoginDiagnostics() throws {
        let e = try JSONDecoder().decode(APIError.self, from: Fixture.data("error_login"))
        XCTAssertEqual(e.behaviour, .loginMessage)
        XCTAssertEqual(e.check?["user_exists"], "yes")
        XCTAssertEqual(e.check?["app_passwords_on"], "yes", "Bools in check read as yes/no")
        XCTAssertTrue(e.mustNotRetry)
    }

    func testMapping() {
        let cases: [(String, Int, APIError.Behaviour)] = [
            ("smapi_no_auth_header", 401, .fixServerHeader),
            ("invalid_username", 401, .wrongUsername),
            ("smapi_login_user", 401, .wrongUsername),
            ("incorrect_password", 401, .wrongPassword),
            ("smapi_login_password", 401, .wrongPassword),
            ("smapi_app_passwords_off", 401, .loginMessage),
            ("smapi_login", 401, .loginMessage),
            ("smapi_forbidden", 403, .logOut),
            ("smapi_https", 403, .logOut),
            ("smapi_not_found", 404, .notFound),
            ("smapi_no_billing", 404, .pluginOff),
            ("smapi_no_site", 404, .pluginOff),
            ("smapi_no_whatsapp", 404, .pluginOff),
            ("smapi_no_ai", 404, .pluginOff),
            ("smapi_slow_down", 429, .slowDown),
            ("smapi_locked", 429, .locked),
            ("internal_server_error", 500, .offline),
            ("rest_no_route", 404, .other),
            ("something_new", 401, .loginMessage),
        ]
        for (code, status, expected) in cases {
            let e = APIError(code: code, message: "m", status: status)
            XCTAssertEqual(e.behaviour, expected, code)
        }
    }

    func testNoRetryFor401And429() {
        XCTAssertTrue(APIError(code: "smapi_slow_down", message: "", status: 429).mustNotRetry)
        XCTAssertTrue(APIError(code: "x", message: "", status: 401).mustNotRetry)
        XCTAssertFalse(APIError(code: "x", message: "", status: 500).mustNotRetry)
    }

    func testUserMessages() {
        XCTAssertTrue(APIError(code: "smapi_no_auth_header", message: "", status: 401).userMessage.contains("Fix the server"))
        XCTAssertEqual(APIError(code: "smapi_forbidden", message: "", status: 403).userMessage, "This account is not an administrator.")
        XCTAssertEqual(APIError(code: "smapi_https", message: "", status: 403).userMessage, "The site must use https.")
        XCTAssertEqual(APIError(code: "smapi_app_passwords_off", message: "Application Passwords are off.", status: 401).userMessage,
                       "Application Passwords are off.")
    }

    func testNonJSONErrorBecomesServerError() {
        let e = APIClient.error(from: Data("<html>502 Bad Gateway</html>".utf8), status: 502)
        XCTAssertEqual(e.code, "server")
        XCTAssertEqual(e.status, 502)
        XCTAssertEqual(e.behaviour, .offline)
    }
}
