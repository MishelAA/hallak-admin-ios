import Foundation

/// One line of the activity log (GET /admin/activity).
struct Activity: Decodable, Hashable, Identifiable {
    struct By: Decodable, Hashable {
        let id: Int?
        let name: String?
    }

    let id: Int
    let salonId: Int?
    let salonName: String?
    /// e.g. appointment_online
    let action: String?
    let summary: String?
    let objectType: String?
    let objectId: Int?
    let by: By?
    /// Free-form extra details: the simple values are kept, nested ones are skipped.
    let details: [String: FlexibleString]?
    let at: String?

    private enum CodingKeys: String, CodingKey {
        case id, salonId, salonName, action, summary, objectType, objectId, by, details, at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        salonId = try c.decodeIfPresent(Int.self, forKey: .salonId)
        salonName = try c.decodeIfPresent(String.self, forKey: .salonName)
        action = try c.decodeIfPresent(String.self, forKey: .action)
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
        objectType = try c.decodeIfPresent(String.self, forKey: .objectType)
        objectId = try? c.decodeIfPresent(Int.self, forKey: .objectId)
        by = try c.decodeIfPresent(By.self, forKey: .by)
        details = try? c.decodeIfPresent([String: FlexibleString].self, forKey: .details)
        at = try c.decodeIfPresent(String.self, forKey: .at)
    }
}
