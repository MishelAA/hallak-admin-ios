import Foundation

/// GET /admin/ai
struct AIReport: Decodable, Hashable {
    struct Totals: Decodable, Hashable {
        let questions: Int?
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
        let questions: Int?
        let summaries: Int?
        var id: Int { salonId }
    }

    let month: String?
    let model: String?
    let limit: Int?
    let weekly: Bool?
    let keySet: Bool?
    let prices: TokenPrices?
    let totals: Totals?
    let salons: [SalonUse]?
    let generatedAt: String?
}
