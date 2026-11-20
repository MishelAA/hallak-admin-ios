import XCTest
@testable import HallakAdmin

/// API 1.2 changes: request bodies, answers, and the action runner rules (no double taps, no retry).
final class WriteBodiesTests: XCTestCase {
    private func body(_ e: Endpoint) throws -> [String: Any] {
        let data = try XCTUnwrap(e.body, "No body")
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testMethodsAndPaths() {
        XCTAssertEqual(Endpoint.createSalon([:]).method, .post)
        XCTAssertEqual(Endpoint.updateSalon(4, [:]).method, .patch)
        XCTAssertEqual(Endpoint.updateSalon(4, [:]).path, "/admin/salons/4")
        XCTAssertEqual(Endpoint.deleteSalon(4, confirm: "x").method, .delete)
        XCTAssertEqual(Endpoint.suspendSalon(4).path, "/admin/salons/4/suspend")
        XCTAssertEqual(Endpoint.activateSalon(4).path, "/admin/salons/4/activate")
        XCTAssertEqual(Endpoint.setSubscription(4, SubscriptionForm()).method, .put)
        XCTAssertEqual(Endpoint.resetPassword(userId: 9).path, "/admin/users/9/reset-password")
        XCTAssertEqual(Endpoint.voidInvoice(15).path, "/admin/invoices/15/void")
        XCTAssertEqual(Endpoint.updatePlan(2, PlanForm()).method, .patch)
        XCTAssertEqual(Endpoint.deleteLead(31).method, .delete)
        XCTAssertEqual(Endpoint.convertLead(31, [:]).path, "/admin/leads/31/convert")
    }

    func testDeleteNeedsTheName() throws {
        XCTAssertEqual(try body(.deleteSalon(4, confirm: "Studio 7"))["confirm"] as? String, "Studio 7")
    }

    func testMoveFeaturesLimits() throws {
        XCTAssertEqual(try body(.moveSalon(4, ownerId: 18))["owner_id"] as? Int, 18)
        let f = try body(.setFeatures(4, ["wabot": true, "queue": false]))
        XCTAssertEqual(f["wabot"] as? Bool, true)
        XCTAssertEqual(f["queue"] as? Bool, false)

        let a = try body(.setLimits(4, whatsapp: .number(300)))
        XCTAssertEqual(a["whatsapp"] as? Int, 300)
        XCTAssertNil(a["ai"], "Only the limit that changes is sent")
        XCTAssertTrue(try body(.setLimits(4, ai: .platformDefault))["ai"] is NSNull, "Default = null")
        XCTAssertEqual(try body(.setLimits(4, ai: .noLimit))["ai"] as? Int, 0, "No limit = 0")
    }

    func testSubscriptionBody() throws {
        var s = SubscriptionForm()
        s.planId = 2
        s.cycle = "year"
        s.until = try XCTUnwrap(Formatters.date("2026-12-31"))
        s.trial = true
        let b = try body(.setSubscription(4, s))
        XCTAssertEqual(b["plan_id"] as? Int, 2)
        XCTAssertEqual(b["until"] as? String, "2026-12-31", "Paid-until in Lebanon days")
        XCTAssertTrue(b["price"] is NSNull, "No own price = plan price (null)")
        XCTAssertEqual(b["trial"] as? Bool, true)

        s.ownPrice = 25
        XCTAssertEqual(try body(.setSubscription(4, s))["price"] as? Double, 25)

        let notBilled = try body(.setSubscription(4, SubscriptionForm()))
        XCTAssertEqual(notBilled["plan_id"] as? Int, 0)
        XCTAssertNil(notBilled["until"])
    }

    func testSubscriptionStartsFromCurrent() throws {
        let b = try Fixture.decode(SubscriptionAnswer.self, "subscription").subscription
        let form = SubscriptionForm(from: b)
        XCTAssertEqual(form.planId, 1)
        XCTAssertEqual(form.cycle, "year")
        XCTAssertEqual(form.ownPrice, 240, "Own price kept")
        XCTAssertEqual(SubscriptionForm.day(form.until), "2026-11-16")
    }

    func testInvoiceAndPaymentBodies() throws {
        var f = InvoiceForm()
        let inv = try body(.createInvoice(salonId: 4, f))
        XCTAssertEqual(inv["months"] as? Int, 1)
        XCTAssertTrue(inv["amount"] is NSNull, "Amount from the plan")
        XCTAssertNil(inv["paid"])

        f.paid = true
        f.method = .omt
        f.amount = 30
        f.months = 2
        let pay = try body(.createInvoice(salonId: 4, f))
        XCTAssertEqual(pay["paid"] as? Bool, true)
        XCTAssertEqual(pay["method"] as? String, "omt")
        XCTAssertEqual(pay["amount"] as? Double, 30)

        let p = try body(.payInvoice(15, method: .whish, note: ""))
        XCTAssertEqual(p["method"] as? String, "whish")
        XCTAssertNil(p["note"], "Empty note not sent")
    }

    func testPlanAndLeadBodies() throws {
        var f = PlanForm()
        f.name = " Pro "
        f.priceMonth = 30
        f.features = ["wabot", "page"]
        let b = try body(.createPlan(f))
        XCTAssertEqual(b["name"] as? String, "Pro")
        XCTAssertEqual(b["features"] as? [String], ["page", "wabot"])
        XCTAssertEqual(b["active"] as? Bool, true)

        XCTAssertEqual(try body(.setLeadStatus(31, done: true))["status"] as? String, "done")
        XCTAssertEqual(try body(.setLeadStatus(31, done: false))["status"] as? String, "new")
    }

    func testNewSalonErrorGoesToTheRightStep() {
        XCTAssertEqual(NewSalonView.step(for: "owner.username"), .owner)
        XCTAssertEqual(NewSalonView.step(for: "owner_id"), .owner)
        XCTAssertEqual(NewSalonView.step(for: "plan_id"), .plan)
        XCTAssertEqual(NewSalonView.step(for: "until"), .plan)
        XCTAssertEqual(NewSalonView.step(for: "name"), .salon)
        XCTAssertEqual(NewSalonView.step(for: "currency"), .salon)
    }
}

final class WriteAnswersTests: XCTestCase {
    func testCreatedSalonWithOneTimeLogin() throws {
        let c = try Fixture.decode(CreatedSalon.self, "salon_created")
        XCTAssertEqual(c.detail.salon.id, 41)
        XCTAssertEqual(c.detail.features?.first?.on, true)
        XCTAssertEqual(c.login?.password.count, 12)
        XCTAssertNotNil(Contact.whatsappURL(c.login?.whatsappLink), "Send on WhatsApp uses the API link")
        XCTAssertEqual(c.warnings?.count, 1)
        XCTAssertNil(c.lead)
    }

    func testSalonChangeIsASalonDetail() throws {
        // PATCH / suspend / activate / move / features / limits answer like GET /admin/salons/{id}.
        XCTAssertNoThrow(try Fixture.decode(SalonDetail.self, "salon"))
    }

    func testOtherAnswers() throws {
        let r = try Fixture.decode(PasswordReset.self, "password_reset")
        XCTAssertEqual(r.login.username, "gio")
        XCTAssertEqual(r.password.count, 12)

        let paid = try Fixture.decode(InvoiceChange.self, "invoice_paid")
        XCTAssertEqual(paid.invoice.status, .paid)
        XCTAssertEqual(paid.subscription?.status, .active)

        let deleted = try Fixture.decode(DeletedSalon.self, "salon_deleted")
        XCTAssertTrue(deleted.deleted)
        XCTAssertEqual(deleted.rows, 37)

        let lead = try Fixture.decode(LeadChange.self, "lead_done")
        XCTAssertEqual(lead.lead?.isNew, false)
        XCTAssertEqual(lead.new, 0)
    }

    func testConflictNamesTheField() throws {
        let e = try JSONDecoder().decode(APIError.self, from: Fixture.data("error_conflict"))
        XCTAssertEqual(e.status, 409)
        XCTAssertEqual(e.field, "owner.username")
        XCTAssertEqual(NewSalonView.step(for: e.field ?? ""), .owner)
    }
}

@MainActor
final class ActionRunnerTests: XCTestCase {
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
                   defaults: UserDefaults(suiteName: "hallak.tests.actions")!, lock: BiometricLock(evaluate: { _ in true }))
    }

    func testSuccessRefreshesListsAndShowsToast() async throws {
        let body = try Fixture.data("salon")
        StubURLProtocol.handler = { req in
            XCTAssertEqual(req.httpMethod, "POST")
            return (200, [:], body)
        }
        let s = session()
        let runner = ActionRunner()
        let before = s.dataVersion
        let d = await runner.run(s, success: "Salon suspended") {
            try await ActionRunner.client(s).send(.suspendSalon(1), as: SalonDetail.self)
        }
        XCTAssertEqual(d?.salon.id, 1)
        XCTAssertEqual(s.dataVersion, before + 1)
        XCTAssertEqual(s.toast, "Salon suspended")
        XCTAssertFalse(runner.isRunning)
        XCTAssertNil(runner.error)
    }

    func testErrorKeepsTheFieldAndIsNotRetried() async throws {
        let body = try Fixture.data("error_conflict")
        StubURLProtocol.handler = { _ in (409, [:], body) }
        let s = session()
        let runner = ActionRunner()
        let r = await runner.run(s) {
            try await ActionRunner.client(s).send(.createSalon(["name": "X"]), as: CreatedSalon.self)
        }
        XCTAssertNil(r)
        XCTAssertEqual(runner.error?.field, "owner.username")
        XCTAssertEqual(StubURLProtocol.requests.count, 1, "A change is never retried")
        XCTAssertEqual(s.dataVersion, 0, "Nothing changed")
        XCTAssertEqual(s.phase, .ready, "A conflict does not log out")
    }

    func testNoDoubleTap() async throws {
        let body = try Fixture.data("salon")
        StubURLProtocol.handler = { _ in
            Thread.sleep(forTimeInterval: 0.3)
            return (200, [:], body)
        }
        let s = session()
        let runner = ActionRunner()
        async let first: SalonDetail? = runner.run(s) { try await ActionRunner.client(s).send(.activateSalon(1), as: SalonDetail.self) }
        try await Task.sleep(for: .milliseconds(50))
        let second = await runner.run(s) { try await ActionRunner.client(s).send(.activateSalon(1), as: SalonDetail.self) }
        let one = await first
        XCTAssertNotNil(one)
        XCTAssertNil(second, "Second tap while running is ignored")
        XCTAssertEqual(StubURLProtocol.requests.count, 1)
    }

    func testDeleteSendsTheBody() async throws {
        let body = try Fixture.data("salon_deleted")
        StubURLProtocol.handler = { req in
            XCTAssertEqual(req.httpMethod, "DELETE")
            return (200, [:], body)
        }
        let s = session()
        let r = await ActionRunner().run(s) {
            try await ActionRunner.client(s).send(.deleteSalon(41, confirm: "Postman Test"), as: DeletedSalon.self)
        }
        XCTAssertEqual(r?.deleted, true)
    }
}
