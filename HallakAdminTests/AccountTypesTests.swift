import XCTest
@testable import HallakAdmin

/// API 1.4: account types (billing.type) and demo salons.
final class AccountTypesTests: XCTestCase {
    private func body(_ e: Endpoint) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(e.body)) as? [String: Any])
    }

    func testBillingHasTheType() throws {
        let page = try Fixture.decode(Page<Salon>.self, "salons")
        XCTAssertEqual(page.items.first?.billing?.type, .paid)
        XCTAssertEqual(page.items.first?.billing?.typeLabel, "Paid")
        XCTAssertNil(page.items.first?.billing?.trialEndsSoon)

        let trial = try XCTUnwrap(Fixture.decode(SubscriptionAnswer.self, "subscription_trial").subscription)
        XCTAssertEqual(trial.type, .trial)
        XCTAssertEqual(trial.trialEndsSoon, 5, "Orange \"Trial ends in 5 days\" on the header")

        let unknown = try APIClient.decoder.decode(Billing.self, from: Data(#"{"status":"demo","type":"later"}"#.utf8))
        XCTAssertEqual(unknown.status, .demo)
        XCTAssertEqual(unknown.type, .unknown, "Unknown types do not break decoding")
    }

    func testOverviewTypesAndMe() throws {
        let o = try Fixture.decode(Overview.self, "overview")
        XCTAssertEqual(o.types?.paid, 18)
        XCTAssertEqual(o.types?.demo, 2)
        XCTAssertEqual(o.billing?.demo, 2)
        XCTAssertTrue(try Fixture.decode(Me.self, "me").canPlan)
        XCTAssertEqual(try Fixture.decode(Me.self, "me").can?.demos, true)
        XCTAssertEqual(try Fixture.decode(BillingSummary.self, "billing_summary").salons?.demo, 2)
    }

    func testVersionCheck() {
        XCTAssertTrue(APIVersion.isAtLeast("1.4.0", "1.4.0"))
        XCTAssertTrue(APIVersion.isAtLeast("1.10.0", "1.4.0"))
        XCTAssertTrue(APIVersion.isAtLeast("2.0", "1.4.0"))
        XCTAssertTrue(APIVersion.isAtLeast("1.4", "1.4.0"))
        XCTAssertFalse(APIVersion.isAtLeast("1.3.9", "1.4.0"))
        XCTAssertFalse(APIVersion.isAtLeast(nil, "1.4.0"))
        XCTAssertFalse(APIVersion.isAtLeast("", "1.4.0"))
    }

    func testTypedSubscriptionBodies() throws {
        var f = SubscriptionForm()
        f.type = .paid
        XCTAssertFalse(f.isComplete, "A paid salon needs a plan")
        f.planId = 2
        f.cycle = "year"
        f.until = try XCTUnwrap(Formatters.date("2027-11-30"))
        XCTAssertTrue(f.isComplete)
        let paid = try body(.setSubscription(4, f))
        XCTAssertEqual(paid["type"] as? String, "paid")
        XCTAssertEqual(paid["plan_id"] as? Int, 2)
        XCTAssertEqual(paid["until"] as? String, "2027-11-30")
        XCTAssertNil(paid["trial_length"])

        f.type = .trial
        f.trialLength = TrialLength.days14.rawValue
        let trial = try body(.setSubscription(4, f))
        XCTAssertEqual(trial["type"] as? String, "trial")
        XCTAssertEqual(trial["trial_length"] as? String, "14")
        XCTAssertEqual(trial["plan_id"] as? Int, 2, "The plan billed after the trial")
        XCTAssertNil(trial["until"])
        f.planId = 0
        XCTAssertNil(try body(.setSubscription(4, f))["plan_id"], "Trial without a plan: no plan_id")
        XCTAssertTrue(f.isComplete)

        f.type = .free
        XCTAssertEqual(Set(try body(.setSubscription(4, f)).keys), ["type"])
        f.type = .demo
        XCTAssertEqual(try body(.setSubscription(4, f))["type"] as? String, "demo")

        f.type = nil
        XCTAssertNil(try body(.setSubscription(4, f))["type"], "Before 1.4: the old body")
    }

    func testFormStartsFromTheSalon() throws {
        let trial = try Fixture.decode(SubscriptionAnswer.self, "subscription_trial").subscription
        XCTAssertEqual(SubscriptionForm(from: trial).type, .trial)

        var old = SubscriptionForm(from: try Fixture.decode(SubscriptionAnswer.self, "subscription").subscription)
        old.type = nil
        old.guessType()
        XCTAssertEqual(old.type, .paid)
        var none = SubscriptionForm()
        none.guessType()
        XCTAssertEqual(none.type, .free, "No plan = free")
    }

    func testTypeFilterAndErrors() throws {
        var q = SalonQuery()
        XCTAssertNil(q.params["type"])
        q.type = .trial
        XCTAssertEqual(q.params["type"], "trial")
        XCTAssertEqual(NewSalonView.step(for: "trial_length"), .plan)
        XCTAssertEqual(NewSalonView.step(for: "type"), .plan)
        let e = try JSONDecoder().decode(APIError.self, from: Fixture.data("error_plan"))
        XCTAssertEqual(e.code, "smb_plan")
    }

    func testDemos() throws {
        let list = try Fixture.decode(DemoList.self, "demos")
        XCTAssertEqual(list.items.count, 2)
        XCTAssertEqual(list.max, 10)
        XCTAssertEqual(list.canAdd, true)
        let first = try XCTUnwrap(list.items.first)
        XCTAssertEqual(first.main, true)
        XCTAssertEqual(first.ownerLogin, "demo")
        XCTAssertTrue(first.isPublic)
        XCTAssertNotNil(first.links?.owner)
        let one = try Fixture.decode(DemoOne.self, "demo_one")
        XCTAssertEqual(one.demo.key, "2")
        XCTAssertEqual(one.demo.language, "ar")
        XCTAssertEqual(one.demo.barberLogin, "demo2-barber")
    }

    func testDemoEndpoints() throws {
        let c = Endpoint.createDemo(name: "  ", lang: "ar", isPublic: true, nightly: false)
        XCTAssertEqual(c.method, .post)
        XCTAssertEqual(c.path, "/admin/demos")
        let cb = try body(c)
        XCTAssertNil(cb["name"], "Empty name: the server picks one")
        XCTAssertEqual(cb["lang"] as? String, "ar")
        XCTAssertEqual(cb["public"] as? Bool, true)
        XCTAssertEqual(try body(.createDemo(name: " Karim ", lang: "en", isPublic: false, nightly: true))["name"] as? String, "Karim")

        let u = Endpoint.updateDemo("2", main: true)
        XCTAssertEqual(u.method, .patch)
        XCTAssertEqual(u.path, "/admin/demos/2")
        XCTAssertEqual(Set(try body(u).keys), ["main"], "Only the switch that changes")

        XCTAssertEqual(Endpoint.resetDemo("2").path, "/admin/demos/2/reset")
        XCTAssertEqual(try body(.resetDemo("2", lang: "en"))["lang"] as? String, "en")
        XCTAssertEqual(Endpoint.deleteDemo("2").method, .delete)
        XCTAssertEqual(Endpoint.deleteDemo("../x").path, "/admin/demos/%2E%2E%2Fx", "A key stays one path part")
    }

    func testWhatsAppShareLink() throws {
        let url = try XCTUnwrap(Contact.whatsappShare(text: "Demo\nhttps://hallak.online/?hallak_demo=2&as=owner"))
        XCTAssertEqual(url.host, "wa.me")
        XCTAssertTrue(url.absoluteString.contains("hallak_demo%3D2%26as%3Downer"), "The link stays whole inside the message")
    }

    #if DEBUG
    func testDemoModeServesDemos() {
        XCTAssertEqual(DemoMode.fixture(for: APIClient.apiRoot + "/admin/demos"), "demos")
        XCTAssertEqual(DemoMode.fixture(for: APIClient.apiRoot + "/admin/demos/2"), "demo_one")
        XCTAssertEqual(DemoMode.fixture(for: APIClient.apiRoot + "/admin/demos/2/reset"), "demo_one")
    }
    #endif
}
