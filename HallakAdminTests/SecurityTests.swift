import XCTest
@testable import HallakAdmin

/// API 1.5: GET /admin/security (read only).
final class SecurityTests: XCTestCase {
    func testDecodesTheExampleAnswer() throws {
        let s = try Fixture.decode(Security.self, "security")
        XCTAssertEqual(s.available, true)
        XCTAssertEqual(s.score, 50)
        XCTAssertEqual(s.summary?.bad, 1)
        XCTAssertEqual(s.checks?.first?.state, .bad)
        XCTAssertEqual(s.checks?.first?.label, "Code editor in wp-admin off")
        XCTAssertEqual(s.files?.lastCheck, "2026-11-23 04:00")
        XCTAssertEqual(s.files?.toLookAt, 2)
        XCTAssertEqual(s.files?.counts?["unknown_in_wordpress"], 1)
        XCTAssertEqual(s.files?.items?.count, 2)
        XCTAssertEqual(s.logins?.blockedNow, 3)
        XCTAssertEqual(s.logins?.failed24h, 7)
        XCTAssertEqual(s.logins?.blocked24h, 1)
        XCTAssertEqual(s.logins?.recent?.first?.level, .warn)
        XCTAssertEqual(s.logins?.recent?.first?.ip, "1.2.3.4")
        XCTAssertEqual(s.twoStep?.admins, 2)
        XCTAssertEqual(s.twoStep?.withTwoStep, 1)
        XCTAssertEqual(s.twoStep?.allProtected, false)
        XCTAssertEqual(s.generatedAt, "2026-11-23 10:07")
    }

    func testHomeCardIsRed() throws {
        let s = try Fixture.decode(Security.self, "security")
        XCTAssertEqual(s.level, .bad, "A bad check or files to look at = red")

        let filesOnly = try decode(#"{"score":95,"summary":{"ok":5,"warn":0,"bad":0},"files":{"to_look_at":1}}"#)
        XCTAssertEqual(filesOnly.level, .bad)
        let warn = try decode(#"{"score":80,"summary":{"ok":4,"warn":1,"bad":0},"files":{"to_look_at":0}}"#)
        XCTAssertEqual(warn.level, .warn)
        let clean = try decode(#"{"score":100,"summary":{"ok":6,"warn":0,"bad":0},"files":{"last_check":null,"to_look_at":0}}"#)
        XCTAssertEqual(clean.level, .ok)
        XCTAssertNil(clean.files?.lastCheck, "null = never checked")
    }

    func testChecksBadFirstThenWarnThenOK() throws {
        let s = try decode(#"""
        {"checks":[{"state":"ok","label":"A","help":""},{"state":"warn","label":"B","help":"x"},
                   {"state":"bad","label":"C","help":"y"},{"state":"ok","label":"D","help":""},{"state":"bad","label":"E","help":"z"}]}
        """#)
        XCTAssertEqual(s.sortedChecks.map(\.label), ["C", "E", "B", "A", "D"])
    }

    func testFilesGroupedInOrder() throws {
        let s = try decode(#"""
        {"files":{"to_look_at":4,"items":[{"group":"unknown_in_wordpress","path":"a.php"},{"group":"new","path":"b.php"},
         {"group":"changed","path":"c.php"},{"group":"new","path":"d.php"}]}}
        """#)
        let g = try XCTUnwrap(s.files?.grouped)
        XCTAssertEqual(g.map(\.group), ["changed", "new", "unknown_in_wordpress"])
        XCTAssertEqual(g[1].items.map(\.path), ["b.php", "d.php"])
    }

    func testScoreColors() {
        XCTAssertEqual(Security.scoreColor(85), Theme.green)
        XCTAssertEqual(Security.scoreColor(84), Theme.orange)
        XCTAssertEqual(Security.scoreColor(60), Theme.orange)
        XCTAssertEqual(Security.scoreColor(59), Theme.red)
    }

    func testOnlyWithThePluginAndAPI15() throws {
        let me = try Fixture.decode(Me.self, "me")
        XCTAssertTrue(me.hasSecurity)
        let old = try APIClient.decoder.decode(Me.self, from: Data(#"{"site":{"plugins":{"billing":true}}}"#.utf8))
        XCTAssertFalse(old.hasSecurity, "No security flag = hidden")
        XCTAssertTrue(APIVersion.isAtLeast("1.5.0", "1.5.0"))
        XCTAssertFalse(APIVersion.isAtLeast("1.4.0", "1.5.0"))

        let e = try JSONDecoder().decode(APIError.self, from: Fixture.data("error_no_security"))
        XCTAssertEqual(e.code, "smapi_no_security")
        XCTAssertEqual(e.behaviour, .pluginOff, "404 smapi_no_security hides the screen")
        XCTAssertEqual(Endpoint.security.method, .get)
        XCTAssertEqual(Endpoint.security.path, "/admin/security")
    }

    private func decode(_ json: String) throws -> Security {
        try APIClient.decoder.decode(Security.self, from: Data(json.utf8))
    }
}
