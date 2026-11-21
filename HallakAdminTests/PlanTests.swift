import XCTest
@testable import HallakAdmin

/// API 1.3: business plan 2027–2029 (decoding, request bodies, edit form, checklist).
final class BusinessPlanDecodingTests: XCTestCase {
    func testPlanDecodes() throws {
        let p = try Fixture.decode(BusinessPlan.self, "plan")
        XCTAssertEqual(p.years?.count, 3)
        XCTAssertEqual(p.renewalTarget, 80)
        XCTAssertEqual(p.customized, true)
        XCTAssertEqual(p.changed?.by, "Mishel")

        let y = try XCTUnwrap(p.currentYear)
        XCTAssertEqual(y.year, 2027, "Opens on the current year")
        XCTAssertEqual(y.status, .onTrack)
        XCTAssertEqual(y.actual?.totalPaying, 3)
        XCTAssertEqual(y.fraction, 0.3, accuracy: 0.001)
        XCTAssertEqual(y.quarters?.first?.cumulative, 3)
        XCTAssertNil(y.quarters?.last?.cumulative, "Future quarter: nothing to draw")

        let later = try XCTUnwrap(p.years?.last)
        XCTAssertEqual(later.status, .notStarted)
        XCTAssertNil(later.actual, "No real numbers before the year starts")
        XCTAssertEqual(later.fraction, 0)
    }

    func testKPIValues() throws {
        let kpis = try XCTUnwrap(Fixture.decode(BusinessPlan.self, "plan").kpis)
        func value(_ slug: String) -> PlanKPI.Value? { kpis.first { $0.slug == slug }?.value }
        XCTAssertEqual(value("paying"), .number(3))
        if case .new(let n)? = value("new") { XCTAssertEqual(n.quarter, 3) } else { XCTFail("new") }
        XCTAssertNil(value("renewal"), "null = track yourself")
        if case .pipeline(let v)? = value("pipeline") { XCTAssertEqual(v.websiteRequests, 2) } else { XCTFail("pipeline") }
        if case .cash(let v)? = value("cash") { XCTAssertEqual(v.unpaid?.count, 1) } else { XCTFail("cash") }
        XCTAssertNil(value("satisfaction"))
    }

    func testChecklistValuesAreNumbersOrTicks() throws {
        let c = try Fixture.decode(PlanChecklist.self, "plan_checklist")
        XCTAssertEqual(c.month, "2027-02")
        let contacts = try XCTUnwrap(c.items.first { $0.slug == "contacts" })
        XCTAssertFalse(contacts.isCheck)
        XCTAssertEqual(contacts.count, 25)
        XCTAssertEqual(contacts.target, 25)
        XCTAssertEqual(contacts.done, true)
        let offers = try XCTUnwrap(c.items.first { $0.slug == "offers" })
        XCTAssertNil(offers.target)
        XCTAssertNil(offers.done, "Count without a goal")
        let followups = try XCTUnwrap(c.items.first { $0.slug == "followups" })
        XCTAssertTrue(followups.isCheck)
        XCTAssertEqual(followups.checked, false)
        XCTAssertNil(followups.count)
    }

    func testRenewalsRoadmapBudget() throws {
        let p = try Fixture.decode(BusinessPlan.self, "plan")
        XCTAssertEqual(p.renewalsDue?.count, 2)
        XCTAssertNotNil(Contact.whatsappURL(p.renewalsDue?.first?.whatsappLink))
        XCTAssertNil(Contact.whatsappURL(p.renewalsDue?.last?.whatsappLink), "No phone: no WhatsApp button")
        XCTAssertEqual(p.renewalsDue?.last?.status, .grace)
        XCTAssertEqual(p.roadmap?.map(\.status), ["ready", "partial", "planned"])
        XCTAssertEqual(p.budget?.items?.reduce(0) { $0 + ($1.share ?? 0) }, 100)
        XCTAssertEqual(p.tiers?.items?.count, 2)
    }

    func testMeCanPlan() throws {
        XCTAssertTrue(try Fixture.decode(Me.self, "me").canPlan)
        let old = try APIClient.decoder.decode(Me.self, from: Data(#"{"can":{"read":true}}"#.utf8))
        XCTAssertFalse(old.canPlan, "Before API 1.3 the plan screen stays hidden")
    }

    func testBudgetErrorNamesTheField() throws {
        let e = try JSONDecoder().decode(APIError.self, from: Fixture.data("error_budget"))
        XCTAssertEqual(e.field, "budget")
    }
}

final class BusinessPlanBodyTests: XCTestCase {
    private func body(_ e: Endpoint) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(e.body)) as? [String: Any])
    }

    func testEndpoints() throws {
        XCTAssertEqual(Endpoint.businessPlan.path, "/admin/plan")
        XCTAssertEqual(Endpoint.planChecklist().query, [:], "Default = this month")
        XCTAssertEqual(Endpoint.planChecklist(month: "2027-02").query, ["month": "2027-02"])

        let add = Endpoint.addToChecklist("contacts")
        XCTAssertEqual(add.method, .patch)
        XCTAssertEqual(add.path, "/admin/plan/checklist")
        XCTAssertEqual((try body(add)["add"] as? [String: Int]), ["contacts": 1])

        let tick = Endpoint.setChecklist("followups", true, month: "2027-02")
        XCTAssertEqual(tick.query, ["month": "2027-02"])
        XCTAssertEqual(try body(tick)["followups"] as? Bool, true)
        XCTAssertEqual(try body(.setChecklist("contacts", 11))["contacts"] as? Int, 11)

        XCTAssertEqual(Endpoint.resetBusinessPlan.method, .patch)
        XCTAssertEqual(try body(.resetBusinessPlan)["reset"] as? Bool, true)
    }

    func testFormSendsOnlyWhatChanged() throws {
        let plan = try Fixture.decode(BusinessPlan.self, "plan")
        let original = PlanTargetsForm(from: plan)
        XCTAssertEqual(original.years[2027]?.cumulative, [2, 5, 8, 10])
        XCTAssertEqual(original.years[2028]?.total, 25)
        XCTAssertEqual(original.budgetSum, 100)
        XCTAssertEqual(original.goals, ["contacts": 25, "demos": 4, "posts": 8])
        XCTAssertEqual(original.renewal, 80)
        XCTAssertTrue(original.body(comparedTo: original).isEmpty, "Nothing changed: nothing to send")

        var f = original
        f.years[2028]?.total = 28
        f.years[2028]?.cumulative = [12, 17, 22, 28]
        f.goals["contacts"] = 30
        let b = f.body(comparedTo: original)
        XCTAssertEqual(Set(b.keys), ["years", "checklist"])
        let years = try XCTUnwrap(b["years"] as? [String: Any])
        XCTAssertEqual(Array(years.keys), ["2028"], "Only the changed year")
        let y = try XCTUnwrap(years["2028"] as? [String: Any])
        XCTAssertEqual(y["total"] as? Int, 28)
        XCTAssertEqual(y["cumulative"] as? [Int], [12, 17, 22, 28])
        XCTAssertEqual(y["quarters"] as? [Int], original.years[2028]?.quarters, "A changed year is sent whole")
        XCTAssertEqual(b["checklist"] as? [String: Int], ["contacts": 30])
    }

    func testBudgetMustAddUpTo100() throws {
        var f = PlanTargetsForm(from: try Fixture.decode(BusinessPlan.self, "plan"))
        let original = f
        f.budget["marketing"] = 25
        XCTAssertEqual(f.budgetSum, 95)
        XCTAssertFalse(f.budgetOK)
        f.budget["reserve"] = 25
        XCTAssertTrue(f.budgetOK)
        XCTAssertEqual(f.body(comparedTo: original)["budget"] as? [String: Int],
                       ["hosting": 15, "marketing": 25, "development": 25, "unexpected": 10, "reserve": 25])
        f.renewal = 75
        XCTAssertEqual(f.body(comparedTo: original)["renewal"] as? Int, 75)
    }

    func testMonthPicker() {
        let m = PlanChecklistSection.months(from: "2027-02")
        XCTAssertEqual(m.count, 12)
        XCTAssertEqual(Array(m.prefix(3)), ["2027-02", "2027-01", "2026-12"])
        XCTAssertEqual(m.last, "2026-03")
        XCTAssertEqual(PlanChecklistSection.monthName("2027-03", locale: Locale(identifier: "en_US")), "March 2027")
    }

    #if DEBUG
    func testDemoServesThePlan() {
        XCTAssertEqual(DemoMode.fixture(for: APIClient.apiRoot + "/admin/plan"), "plan")
        XCTAssertEqual(DemoMode.fixture(for: APIClient.apiRoot + "/admin/plan/checklist"), "plan_checklist")
        XCTAssertEqual(DemoMode.fixture(for: APIClient.apiRoot + "/admin/plans"), "plans", "Billing plans stay apart")
    }
    #endif
}

@MainActor
final class ChecklistActionTests: XCTestCase {
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

    func testPlusOneUpdatesFromTheAnswer() async throws {
        let body = try Fixture.data("plan_checklist")
        StubURLProtocol.handler = { req in
            XCTAssertEqual(req.httpMethod, "PATCH")
            XCTAssertTrue(req.url?.absoluteString.contains("month=2027-02") ?? false)
            return (200, [:], body)
        }
        let s = AppSession(keychain: keychain, urlSession: StubURLProtocol.session(), cache: ETagCache(folder: nil),
                           defaults: UserDefaults(suiteName: "hallak.tests.plan")!, lock: BiometricLock(evaluate: { _ in true }))
        let runner = ActionRunner()
        let answer = await runner.run(s, refreshLists: false) {
            try await ActionRunner.client(s).send(.addToChecklist("contacts", month: "2027-02"), as: PlanChecklist.self)
        }
        XCTAssertEqual(answer?.items.first?.count, 25)
        XCTAssertEqual(s.dataVersion, 0, "A tick does not reload every list")
        XCTAssertEqual(StubURLProtocol.requests.count, 1)
    }

    func testFailedTickIsNotRetried() async throws {
        StubURLProtocol.handler = { _ in (500, [:], Data()) }
        let s = AppSession(keychain: keychain, urlSession: StubURLProtocol.session(), cache: ETagCache(folder: nil),
                           defaults: UserDefaults(suiteName: "hallak.tests.plan")!, lock: BiometricLock(evaluate: { _ in true }))
        let runner = ActionRunner()
        let answer = await runner.run(s, refreshLists: false) {
            try await ActionRunner.client(s).send(.setChecklist("followups", true), as: PlanChecklist.self)
        }
        XCTAssertNil(answer)
        XCTAssertNotNil(runner.error)
        XCTAssertEqual(StubURLProtocol.requests.count, 1)
    }
}
