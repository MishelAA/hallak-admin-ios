import Foundation

// MARK: - API 1.2 changes (POST / PUT / PATCH / DELETE). Never cached, never retried.

/// A JSON body. `NSNull()` sends `null` (e.g. "platform default" limit, "plan price").
typealias JSONBody = [String: Any]

private func json(_ body: JSONBody) -> Data? {
    try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
}

extension Endpoint {
    // Salons
    static func createSalon(_ body: JSONBody) -> Endpoint { Endpoint(.post, "/admin/salons", body: json(body)) }
    /// Send only the fields that change.
    static func updateSalon(_ id: Int, _ body: JSONBody) -> Endpoint { Endpoint(.patch, "/admin/salons/\(id)", body: json(body)) }
    /// `confirm` = the salon name (any letter case).
    static func deleteSalon(_ id: Int, confirm: String) -> Endpoint {
        Endpoint(.delete, "/admin/salons/\(id)", body: json(["confirm": confirm]))
    }
    static func suspendSalon(_ id: Int) -> Endpoint { Endpoint(.post, "/admin/salons/\(id)/suspend") }
    static func activateSalon(_ id: Int) -> Endpoint { Endpoint(.post, "/admin/salons/\(id)/activate") }
    static func moveSalon(_ id: Int, ownerId: Int) -> Endpoint {
        Endpoint(.post, "/admin/salons/\(id)/move", body: json(["owner_id": ownerId]))
    }
    /// Only the features sent change.
    static func setFeatures(_ id: Int, _ features: [String: Bool]) -> Endpoint {
        Endpoint(.patch, "/admin/salons/\(id)/features", body: json(features))
    }
    /// nil = platform default, 0 = no limit. Only the keys given are sent.
    static func setLimits(_ id: Int, whatsapp: LimitChoice? = nil, ai: LimitChoice? = nil) -> Endpoint {
        var b: JSONBody = [:]
        if let whatsapp { b["whatsapp"] = whatsapp.jsonValue }
        if let ai { b["ai"] = ai.jsonValue }
        return Endpoint(.patch, "/admin/salons/\(id)/limits", body: json(b))
    }
    static func setSubscription(_ id: Int, _ s: SubscriptionForm) -> Endpoint {
        Endpoint(.put, "/admin/salons/\(id)/subscription", body: json(s.body))
    }

    // Logins
    static func resetPassword(userId: Int) -> Endpoint { Endpoint(.post, "/admin/users/\(userId)/reset-password") }

    // Billing
    static func createInvoice(salonId: Int, _ form: InvoiceForm) -> Endpoint {
        Endpoint(.post, "/admin/salons/\(salonId)/invoices", body: json(form.body))
    }
    static func payInvoice(_ id: Int, method: PaymentMethod, note: String) -> Endpoint {
        var b: JSONBody = ["method": method.rawValue]
        if !note.isEmpty { b["note"] = note }
        return Endpoint(.post, "/admin/invoices/\(id)/pay", body: json(b))
    }
    static func voidInvoice(_ id: Int) -> Endpoint { Endpoint(.post, "/admin/invoices/\(id)/void") }
    static func createPlan(_ form: PlanForm) -> Endpoint { Endpoint(.post, "/admin/plans", body: json(form.body)) }
    static func updatePlan(_ id: Int, _ form: PlanForm) -> Endpoint { Endpoint(.patch, "/admin/plans/\(id)", body: json(form.body)) }

    // Demo requests
    static func setLeadStatus(_ id: Int, done: Bool) -> Endpoint {
        Endpoint(.patch, "/admin/leads/\(id)", body: json(["status": done ? "done" : "new"]))
    }
    static func deleteLead(_ id: Int) -> Endpoint { Endpoint(.delete, "/admin/leads/\(id)") }
    /// Same body as a new salon; missing parts come from the request.
    static func convertLead(_ id: Int, _ body: JSONBody) -> Endpoint {
        Endpoint(.post, "/admin/leads/\(id)/convert", body: json(body))
    }
}

/// A monthly limit: platform default (null), no limit (0) or a number.
enum LimitChoice: Hashable {
    case platformDefault, noLimit, number(Int)

    var jsonValue: Any {
        switch self {
        case .platformDefault: return NSNull()
        case .noLimit: return 0
        case .number(let n): return max(0, n)
        }
    }
}

// MARK: - Forms

/// PUT /admin/salons/{id}/subscription (also `subscription` in a new salon).
struct SubscriptionForm: Hashable {
    /// 0 = not billed
    var planId = 0
    var cycle = "month"
    var until = Date()
    /// nil = the plan price
    var ownPrice: Double?
    var trial = false
    var applyFeatures = false

    var body: JSONBody {
        var b: JSONBody = ["plan_id": planId, "cycle": cycle, "trial": trial, "apply_features": applyFeatures,
                           "price": ownPrice.map { $0 as Any } ?? NSNull()]
        if planId != 0 { b["until"] = Self.day(until) }
        return b
    }

    /// "yyyy-MM-dd" in Lebanon time.
    static func day(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = Formatters.lebanon
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    init() {}

    /// Starts from the salon's current subscription.
    init(from b: Billing?) {
        planId = b?.planId ?? 0
        cycle = b?.cycle ?? "month"
        until = Formatters.date(b?.until) ?? Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        ownPrice = (b?.ownPrice == true) ? b?.price?.amount : nil
        trial = b?.trial ?? false
    }
}

/// POST /admin/salons/{id}/invoices: a new invoice, or a payment recorded at once (`paid`).
struct InvoiceForm: Hashable {
    var months = 1
    /// nil = from the plan
    var amount: Double?
    var paid = false
    var method = PaymentMethod.cash
    var note = ""

    var body: JSONBody {
        var b: JSONBody = ["months": max(1, months), "amount": amount.map { $0 as Any } ?? NSNull()]
        if paid {
            b["paid"] = true
            b["method"] = method.rawValue
        }
        if !note.isEmpty { b["note"] = note }
        return b
    }
}

/// POST /admin/plans · PATCH /admin/plans/{id}
struct PlanForm: Hashable {
    var name = ""
    var priceMonth: Double = 0
    var priceYear: Double = 0
    var features: Set<String> = []
    var note = ""
    var active = true

    init() {}
    init(from p: Plan) {
        name = p.name ?? ""
        priceMonth = p.priceMonth?.amount ?? 0
        priceYear = p.priceYear?.amount ?? 0
        features = Set(p.features ?? [])
        note = p.note ?? ""
        active = p.active ?? true
    }

    var body: JSONBody {
        ["name": name.trimmingCharacters(in: .whitespaces), "price_month": priceMonth, "price_year": priceYear,
         "features": features.sorted(), "note": note, "active": active]
    }
}

// MARK: - Answers

/// A new login, shown ONCE (never stored): new salon, demo request converted, new password.
struct NewLogin: Decodable, Hashable {
    let username: String?
    let password: String
    let loginUrl: String?
    let whatsappLink: String?
}

/// POST /admin/salons and POST /admin/leads/{id}/convert: the salon + its owner login (+ warnings).
struct CreatedSalon: Decodable {
    let detail: SalonDetail
    let login: NewLogin?
    let warnings: [String]?
    let lead: Lead?

    private enum CodingKeys: String, CodingKey { case login, warnings, lead }
    init(from decoder: Decoder) throws {
        detail = try SalonDetail(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        login = try? c.decodeIfPresent(NewLogin.self, forKey: .login)
        warnings = try? c.decodeIfPresent([String].self, forKey: .warnings)
        lead = try? c.decodeIfPresent(Lead.self, forKey: .lead)
    }
}

/// POST /admin/users/{id}/reset-password
struct PasswordReset: Decodable, Hashable {
    let user: UserShort?
    let password: String
    let loginUrl: String?
    let whatsappLink: String?

    var login: NewLogin { NewLogin(username: user?.username, password: password, loginUrl: loginUrl, whatsappLink: whatsappLink) }
}

/// DELETE /admin/salons/{id}
struct DeletedSalon: Decodable, Hashable {
    let deleted: Bool
    let id: Int?
    let name: String?
    let rows: Int?
    let message: String?
}

/// Invoice actions: the invoice (+ the subscription when a payment moved paid-until).
struct InvoiceChange: Decodable, Hashable {
    let invoice: Invoice
    let subscription: Billing?
}

struct PlanChange: Decodable, Hashable {
    let plan: Plan
}

/// PATCH / DELETE /admin/leads/{id}
struct LeadChange: Decodable, Hashable {
    let lead: Lead?
    let deleted: Bool?
    let new: Int?
}
