import Foundation

enum SalonStatus: String, Decodable, Hashable {
    case active, suspended, unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SalonStatus(rawValue: raw) ?? .unknown
    }
}

/// A salon (GET /admin/salons, and `salon` in /admin/salons/{id}).
struct Salon: Decodable, Hashable, Identifiable {
    struct Owner: Decodable, Hashable {
        let id: Int?
        let username: String?
        let name: String?
        let email: String?
    }
    /// Second currency and its rate, e.g. LBP at 89500.
    struct FX: Decodable, Hashable {
        let second: String?
        let rate: Double?
    }

    let id: Int
    let slug: String?
    let name: String
    let phone: String?
    let address: String?
    let currency: String?
    let language: String?
    let status: SalonStatus?
    let createdAt: String?
    /// Last line in the activity log.
    let lastActivity: String?
    let owner: Owner?
    let billing: Billing?
    // Only in /admin/salons/{id}
    let notes: String?
    let fx: FX?

    var isSuspended: Bool { status == .suspended }
}

/// GET /admin/salons/{id}
struct SalonDetail: Decodable, Hashable {
    struct FeatureState: Decodable, Hashable, Identifiable {
        let slug: String
        let label: String?
        let on: Bool?
        var id: String { slug }
    }
    struct Links: Decodable, Hashable {
        let dashboard: String?
        let page: String?
        let booking: String?
        /// wa.me link to the salon phone.
        let whatsapp: String?
    }
    struct Month: Decodable, Hashable {
        let visits: Int?
        let revenue: Money?
        let customers: Int?
    }
    struct WhatsApp: Decodable, Hashable {
        let featureOn: Bool?
        let botOn: Bool?
        let numberLinked: Bool?
        let repliesMonth: Int?
        /// 0 = no limit
        let limit: Int?
        let ownLimit: Bool?
        let chatsNeedTeam: Int?
        let costMonth: Money?
    }
    struct AI: Decodable, Hashable {
        let featureOn: Bool?
        let questionsMonth: Int?
        /// 0 = no limit
        let limit: Int?
        let ownLimit: Bool?
        let costMonth: Money?
    }

    let salon: Salon
    let features: [FeatureState]?
    let links: Links?
    let invoices: [Invoice]?
    let month: Month?
    let whatsapp: WhatsApp?
    let ai: AI?
    let generatedAt: String?
}

/// GET /admin/owners: an owner and their salons (branches).
struct Owner: Decodable, Hashable, Identifiable {
    struct SalonRef: Decodable, Hashable, Identifiable {
        let id: Int
        let name: String?
        let status: SalonStatus?
    }

    let id: Int
    let username: String?
    let name: String?
    let email: String?
    let lastLogin: String?
    let salons: [SalonRef]?

    var displayName: String { (name?.isEmpty == false ? name : username) ?? "#\(id)" }
}
