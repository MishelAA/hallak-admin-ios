import Foundation

/// Token counts in/out (`in` is a Swift keyword, hence the names).
struct TokenCounts: Decodable, Hashable {
    let input: Int?
    let output: Int?
    private enum CodingKeys: String, CodingKey { case input = "in", output = "out" }
}

/// Prices in/out.
struct TokenPrices: Decodable, Hashable {
    let input: Double?
    let output: Double?
    private enum CodingKeys: String, CodingKey { case input = "in", output = "out" }
}

/// GET /admin/whatsapp. Never the keys: only `key_set`.
struct WhatsAppReport: Decodable, Hashable {
    struct LastError: Decodable, Hashable {
        let at: String?
        let text: String?
    }
    struct Totals: Decodable, Hashable {
        let replies: Int?
        let cost: Money?
    }
    struct SalonUse: Decodable, Hashable, Identifiable {
        let salonId: Int
        let salonName: String?
        let featureOn: Bool?
        let tokens: TokenCounts?
        let cost: Money?
        let limit: Int?
        let ownLimit: Int?
        let botOn: Bool?
        let numberLinked: Bool?
        let replies: Int?
        let chatsNeedTeam: Int?
        var id: Int { salonId }
    }

    let month: String?
    let model: String?
    let limit: Int?
    let keySet: Bool?
    let prices: TokenPrices?
    let lastError: LastError?
    let totals: Totals?
    let salons: [SalonUse]?
    let generatedAt: String?
}
