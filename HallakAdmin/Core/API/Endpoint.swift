import Foundation

enum HTTPMethod: String {
    case get = "GET", post = "POST", patch = "PATCH", put = "PUT", delete = "DELETE"
}

/// One API call: method, path under /wp-json/hallak/v1, query and (from API 1.1) a JSON body.
struct Endpoint: Hashable {
    var method: HTTPMethod
    var path: String
    var query: [String: String]
    var body: Data?

    init(_ method: HTTPMethod = .get, _ path: String, query: [String: String] = [:], body: Data? = nil) {
        self.method = method
        self.path = path
        self.query = query.filter { !$0.value.isEmpty }
        self.body = body
    }
}

/// Paging + filters shared by list endpoints.
struct ListQuery: Hashable {
    var page = 1
    var perPage = 25
    var filters: [String: String] = [:]

    init(page: Int = 1, perPage: Int = 25, filters: [String: String] = [:]) {
        self.page = page
        self.perPage = perPage
        self.filters = filters
    }

    var items: [String: String] {
        var q = filters
        q["page"] = String(max(page, 1))
        q["per_page"] = String(min(max(perPage, 1), 100))
        return q
    }
}

/// The 18 endpoints of API 1.0.1 (all GET, read only).
extension Endpoint {
    static let ping = Endpoint(.get, "/admin/ping")
    static let me = Endpoint(.get, "/admin/me")
    static let overview = Endpoint(.get, "/admin/overview")
    static let health = Endpoint(.get, "/admin/health")
    static let features = Endpoint(.get, "/admin/features")
    static let billingSummary = Endpoint(.get, "/admin/billing/summary")
    static let whatsapp = Endpoint(.get, "/admin/whatsapp")
    static let ai = Endpoint(.get, "/admin/ai")

    /// Filters: salon_id, type, action, from, to, search
    static func activity(_ q: ListQuery = ListQuery()) -> Endpoint { Endpoint(.get, "/admin/activity", query: q.items) }
    /// Filters: search, status (active|suspended), billing (free|trial|active|grace|overdue), owner_id, sort (new|name|until|activity)
    static func salons(_ q: ListQuery = ListQuery()) -> Endpoint { Endpoint(.get, "/admin/salons", query: q.items) }
    static func salon(_ id: Int) -> Endpoint { Endpoint(.get, "/admin/salons/\(id)") }
    static func salonUsers(_ id: Int) -> Endpoint { Endpoint(.get, "/admin/salons/\(id)/users") }
    static func subscription(_ id: Int) -> Endpoint { Endpoint(.get, "/admin/salons/\(id)/subscription") }
    /// Filters: search
    static func owners(_ q: ListQuery = ListQuery()) -> Endpoint { Endpoint(.get, "/admin/owners", query: q.items) }
    static func plans(activeOnly: Bool = false) -> Endpoint {
        Endpoint(.get, "/admin/plans", query: activeOnly ? ["active": "1"] : [:])
    }
    /// Filters: status (unpaid|paid|void), salon_id, from, to
    static func invoices(_ q: ListQuery = ListQuery()) -> Endpoint { Endpoint(.get, "/admin/invoices", query: q.items) }
    static func invoice(_ id: Int) -> Endpoint { Endpoint(.get, "/admin/invoices/\(id)") }
    /// Filters: status (new|done), search
    static func leads(_ q: ListQuery = ListQuery()) -> Endpoint { Endpoint(.get, "/admin/leads", query: q.items) }
}
