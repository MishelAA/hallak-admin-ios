import Foundation

/// A demo request from the website (GET /admin/leads).
struct Lead: Decodable, Hashable, Identifiable {
    let id: Int
    let name: String?
    let salon: String?
    let phone: String?
    let email: String?
    let plan: String?
    /// Number of barbers, as typed on the website form.
    let barbers: String?
    let message: String?
    /// new | done
    let status: String?
    let createdAt: String?
    /// One-tap https://wa.me/... link from the API.
    let whatsapp: String?

    var isNew: Bool { status == "new" }

    private enum CodingKeys: String, CodingKey {
        case id, name, salon, phone, email, plan, barbers, message, status, createdAt, whatsapp
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        salon = try c.decodeIfPresent(String.self, forKey: .salon)
        phone = try c.decodeIfPresent(FlexibleString.self, forKey: .phone)?.value
        email = try c.decodeIfPresent(String.self, forKey: .email)
        plan = try c.decodeIfPresent(String.self, forKey: .plan)
        barbers = try c.decodeIfPresent(FlexibleString.self, forKey: .barbers)?.value
        message = try c.decodeIfPresent(String.self, forKey: .message)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        whatsapp = try c.decodeIfPresent(String.self, forKey: .whatsapp)
    }
}

/// GET /admin/leads: a page plus how many are still new.
struct LeadsPage: Decodable {
    let page: Page<Lead>
    let new: Int?

    private enum CodingKeys: String, CodingKey { case new }

    init(from decoder: Decoder) throws {
        page = try Page<Lead>(from: decoder)
        new = try decoder.container(keyedBy: CodingKeys.self).decodeIfPresent(Int.self, forKey: .new)
    }
}
