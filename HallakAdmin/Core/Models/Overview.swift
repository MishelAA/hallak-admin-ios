import Foundation

/// GET /admin/overview. Sections are missing when their plugin is off: hide that card.
struct Overview: Decodable, Hashable {
    struct Salons: Decodable, Hashable {
        let total: Int?
        let active: Int?
        let suspended: Int?
    }
    struct BillingCounts: Decodable, Hashable {
        let free: Int?
        let trial: Int?
        let active: Int?
        let grace: Int?
        let overdue: Int?
        /// Payment due + overdue: red badge on Home when > 0.
        var late: Int { (grace ?? 0) + (overdue ?? 0) }
    }
    struct Unpaid: Decodable, Hashable {
        let count: Int?
        let amount: Money?
    }
    struct MoneyBlock: Decodable, Hashable {
        let mrr: Money?
        let paidThisMonth: Money?
        let unpaid: Unpaid?
    }
    struct Leads: Decodable, Hashable {
        let new: Int?
    }
    struct WhatsApp: Decodable, Hashable {
        let repliesMonth: Int?
        let costMonth: Money?
        let chatsNeedTeam: Int?
    }
    struct AI: Decodable, Hashable {
        let questionsMonth: Int?
        let summariesMonth: Int?
        let costMonth: Money?
    }
    struct Health: Decodable, Hashable {
        let errors: Int?
        let warnings: Int?
        var isClean: Bool { (errors ?? 0) == 0 && (warnings ?? 0) == 0 }
    }

    let salons: Salons?
    let billing: BillingCounts?
    let money: MoneyBlock?
    let leads: Leads?
    let whatsapp: WhatsApp?
    let ai: AI?
    let health: Health?
    let activityToday: Int?
    let generatedAt: String?
}
