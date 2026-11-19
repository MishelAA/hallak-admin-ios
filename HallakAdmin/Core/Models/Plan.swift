import Foundation

/// GET /admin/plans
struct Plan: Decodable, Hashable, Identifiable {
    let id: Int
    let name: String?
    let priceMonth: Money?
    let priceYear: Money?
    /// Feature slugs, see /admin/features
    let features: [String]?
    let note: String?
    let active: Bool?
}
