import Foundation

/// Billing status of a salon. free = not billed, grace = payment due (still working), overdue = past the grace days.
enum BillingStatus: String, Decodable, CaseIterable, Hashable {
    case free, trial, active, grace, overdue, unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = BillingStatus(rawValue: raw) ?? .unknown
    }
}

/// The `Billing` object (in a salon, and in /salons/{id}/subscription).
struct Billing: Decodable, Hashable {
    let status: BillingStatus?
    /// Plain words from the API ("Paid", "Payment due"): show this, not the raw status.
    let statusLabel: String?
    let planId: Int?
    let plan: String?
    /// month | year
    let cycle: String?
    let price: Money?
    let monthly: Money?
    let ownPrice: Bool?
    let until: String?
    /// Negative when the date has passed.
    let daysLeft: Int?
    let graceEnd: String?
    let trial: Bool?
}

/// GET /admin/salons/{id}/subscription
struct SubscriptionAnswer: Decodable, Hashable {
    let salonId: Int?
    let subscription: Billing?
    let openInvoice: Invoice?
    let generatedAt: String?
}

/// GET /admin/billing/summary
struct BillingSummary: Decodable, Hashable {
    struct Unpaid: Decodable, Hashable {
        let count: Int?
        let amount: Money?
    }
    struct Counts: Decodable, Hashable {
        let free: Int?
        let trial: Int?
        let active: Int?
        let grace: Int?
        let overdue: Int?
    }
    struct DueSoon: Decodable, Hashable, Identifiable {
        let salonId: Int
        let salonName: String?
        let status: BillingStatus?
        let until: String?
        let daysLeft: Int?
        var id: Int { salonId }
    }
    struct Method: Decodable, Hashable, Identifiable {
        let slug: String
        let label: String?
        var id: String { slug }
    }

    let currency: String?
    let mrr: Money?
    let paidThisMonth: Money?
    let unpaid: Unpaid?
    let salons: Counts?
    let dueSoon: [DueSoon]?
    let graceDays: Int?
    let methods: [Method]?
    let generatedAt: String?
}
