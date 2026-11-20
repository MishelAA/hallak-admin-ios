import XCTest
@testable import HallakAdmin

/// Every endpoint's fixture decodes into its model (M1 "done when").
final class DecodingTests: XCTestCase {
    func testPing() throws {
        let p = try Fixture.decode(Ping.self, "ping")
        XCTAssertTrue(p.ok)
        XCTAssertEqual(p.hallakCore, "1.12.4")
        XCTAssertEqual(p.api, "1.2.0")
        XCTAssertEqual(p.generatedAt, "2026-11-19 13:13")
    }

    func testMe() throws {
        let me = try Fixture.decode(Me.self, "me")
        XCTAssertEqual(me.user?.username, "mishel-app")
        XCTAssertTrue(me.canWrite, "API 1.2: changes allowed")
        XCTAssertTrue(me.hasBilling)
        XCTAssertFalse(me.hasAI)
        XCTAssertEqual(me.site?.hallakCore, "1.4.2")
    }

    func testOverviewWithMissingSection() throws {
        let o = try Fixture.decode(Overview.self, "overview")
        XCTAssertEqual(o.salons?.total, 23)
        XCTAssertEqual(o.billing?.late, 2)
        XCTAssertEqual(o.money?.mrr?.display, "$690")
        XCTAssertEqual(o.money?.unpaid?.count, 4)
        XCTAssertEqual(o.leads?.new, 2)
        XCTAssertEqual(o.whatsapp?.chatsNeedTeam, 3)
        XCTAssertNil(o.ai, "AI plugin off: the section is missing and its card is hidden")
        XCTAssertEqual(o.health?.warnings, 2)
        XCTAssertFalse(o.health?.isClean ?? true)
        XCTAssertEqual(o.activityToday, 57)
    }

    func testHealth() throws {
        let h = try Fixture.decode(Health.self, "health")
        XCTAssertEqual(h.plugins?.count, 3)
        XCTAssertEqual(h.plugins?[1].upToDate, false)
        XCTAssertNil(h.plugins?[2].installed)
        XCTAssertEqual(h.sortedProblems.map(\.level), [.error, .warn, .info])
        XCTAssertEqual(h.environment?["https"]?.value, "yes")
    }

    func testActivity() throws {
        let p = try Fixture.decode(Page<Activity>.self, "activity")
        XCTAssertEqual(p.items.count, 2)
        XCTAssertEqual(p.total, 57)
        XCTAssertTrue(p.hasMore)
        XCTAssertEqual(p.items[0].details?["price"]?.value, "10")
        XCTAssertNil(p.items[0].by)
        XCTAssertNil(p.items[1].details, "Nested details are skipped, never an error")
        XCTAssertEqual(p.items[1].by?.name, "Mishel")
    }

    func testFeatures() throws {
        let f = try Fixture.decode(ItemList<Feature>.self, "features")
        XCTAssertEqual(f.items.map(\.slug), ["appointments", "wabot", "loyalty"])
        XCTAssertEqual(f.items[1].isDefault, false)
    }

    func testSalons() throws {
        let p = try Fixture.decode(Page<Salon>.self, "salons")
        XCTAssertEqual(p.items.count, 2)
        XCTAssertEqual(p.pages, 12)
        let s = p.items[0]
        XCTAssertEqual(s.owner?.name, "Gio Emmanuel")
        XCTAssertEqual(s.billing?.status, .active)
        XCTAssertEqual(s.billing?.statusLabel, "Paid")
        XCTAssertEqual(p.items[1].isSuspended, true)
        XCTAssertEqual(p.items[1].billing?.daysLeft, -3)
        XCTAssertNil(p.items[1].owner)
    }

    func testSalonDetail() throws {
        let d = try Fixture.decode(SalonDetail.self, "salon")
        XCTAssertEqual(d.salon.fx?.rate, 89500)
        XCTAssertEqual(d.salon.notes, "Pays on the 7th.")
        XCTAssertEqual(d.features?.filter { $0.on == true }.count, 2)
        XCTAssertEqual(d.links?.whatsapp, "https://wa.me/96170123456")
        XCTAssertEqual(d.invoices?.first?.paymentMethod, .whish)
        XCTAssertEqual(d.month?.revenue?.amount, 3120.5)
        XCTAssertEqual(d.whatsapp?.limit, 1000)
        XCTAssertEqual(d.ai?.featureOn, false)
    }

    func testSalonUsers() throws {
        let u = try Fixture.decode(ItemList<UserShort>.self, "salon_users")
        XCTAssertEqual(u.items.map(\.role), ["owner", "staff"])
        XCTAssertNil(u.items[1].lastLogin)
    }

    func testSubscription() throws {
        let s = try Fixture.decode(SubscriptionAnswer.self, "subscription")
        XCTAssertEqual(s.subscription?.status, .grace)
        XCTAssertEqual(s.subscription?.graceEnd, "2026-11-23")
        XCTAssertEqual(s.openInvoice?.status, .unpaid)
        XCTAssertNil(s.openInvoice?.method)

        let none = try Fixture.decode(SubscriptionAnswer.self, "subscription_none")
        XCTAssertNil(none.subscription)
        XCTAssertNil(none.openInvoice)
    }

    func testOwners() throws {
        let p = try Fixture.decode(Page<Owner>.self, "owners")
        XCTAssertEqual(p.items[0].salons?.count, 2)
        XCTAssertEqual(p.items[1].displayName, "rami", "Empty name falls back to the username")
    }

    func testBillingSummary() throws {
        let b = try Fixture.decode(BillingSummary.self, "billing_summary")
        XCTAssertEqual(b.paidThisMonth?.display, "$520")
        XCTAssertEqual(b.dueSoon?.count, 3)
        XCTAssertNil(b.dueSoon?[2].until)
        XCTAssertEqual(b.graceDays, 7)
        XCTAssertEqual(b.methods?.map(\.slug), ["cash", "whish", "omt", "bank", "other"])
    }

    func testPlans() throws {
        let p = try Fixture.decode(ItemList<Plan>.self, "plans")
        XCTAssertEqual(p.items.count, 3)
        XCTAssertEqual(p.items[2].priceMonth?.currency, "LBP")
        XCTAssertEqual(p.items[2].active, false)
    }

    func testInvoices() throws {
        let p = try Fixture.decode(Page<Invoice>.self, "invoices")
        XCTAssertEqual(p.items.map(\.status), [.unpaid, .paid])
        let one = try Fixture.decode(InvoiceAnswer.self, "invoice")
        XCTAssertEqual(one.invoice.title, "HL-2026-0015")
        XCTAssertEqual(one.invoice.months, 12)
    }

    func testLeads() throws {
        let l = try Fixture.decode(LeadsPage.self, "leads")
        XCTAssertEqual(l.new, 1)
        XCTAssertEqual(l.page.items.count, 2)
        XCTAssertTrue(l.page.items[0].isNew)
        XCTAssertEqual(l.page.items[1].phone, "96103111222", "A phone sent as a number still reads as text")
        XCTAssertEqual(l.page.items[1].barbers, "2")
        XCTAssertNil(l.page.items[1].whatsapp)
    }

    func testWhatsApp() throws {
        let w = try Fixture.decode(WhatsAppReport.self, "whatsapp")
        XCTAssertEqual(w.keySet, true)
        XCTAssertEqual(w.prices?.output, 5.0)
        XCTAssertEqual(w.lastError?.text, "Whapi: number not connected (Studio 7)")
        XCTAssertEqual(w.salons?[0].tokens?.input, 820000)
        XCTAssertNil(w.salons?[0].ownLimit)
        XCTAssertEqual(w.salons?[1].ownLimit, 300)
    }

    func testAI() throws {
        let a = try Fixture.decode(AIReport.self, "ai")
        XCTAssertEqual(a.weekly, true)
        XCTAssertEqual(a.keySet, false)
        XCTAssertEqual(a.totals?.questions, 212)
        XCTAssertEqual(a.salons?.first?.summaries, 4)
    }

    func testUnknownStatusNeverBreaksDecoding() throws {
        let json = #"{"id": 1, "name": "X", "status": "archived", "billing": {"status": "paused"}}"#
        let s = try APIClient.decoder.decode(Salon.self, from: Data(json.utf8))
        XCTAssertEqual(s.status, .unknown)
        XCTAssertEqual(s.billing?.status, .unknown)
    }
}
