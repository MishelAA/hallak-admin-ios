import Foundation

/// A list answer: `items, page, per_page, total, pages` (+ generated_at, tz).
struct Page<T: Decodable>: Decodable {
    let items: [T]
    let page: Int
    let perPage: Int
    let total: Int
    let pages: Int
    let generatedAt: String?

    var hasMore: Bool { page < pages }
    var nextPage: Int? { hasMore ? page + 1 : nil }

    init(items: [T], page: Int = 1, perPage: Int = 25, total: Int? = nil, pages: Int = 1, generatedAt: String? = nil) {
        self.items = items
        self.page = page
        self.perPage = perPage
        self.total = total ?? items.count
        self.pages = pages
        self.generatedAt = generatedAt
    }

    private enum CodingKeys: String, CodingKey { case items, page, perPage, total, pages, generatedAt }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = try c.decode([T].self, forKey: .items)
        page = try c.decodeIfPresent(Int.self, forKey: .page) ?? 1
        perPage = try c.decodeIfPresent(Int.self, forKey: .perPage) ?? items.count
        total = try c.decodeIfPresent(Int.self, forKey: .total) ?? items.count
        pages = try c.decodeIfPresent(Int.self, forKey: .pages) ?? 1
        generatedAt = try c.decodeIfPresent(String.self, forKey: .generatedAt)
    }
}

/// Lists without paging (/features, /plans, /salons/{id}/users).
struct ItemList<T: Decodable>: Decodable {
    let items: [T]
    let generatedAt: String?
}

/// Pages already loaded, for infinite scroll.
struct PagedList<T: Decodable & Identifiable> {
    private(set) var items: [T] = []
    private(set) var lastPage = 0
    private(set) var pages = 1
    private(set) var total = 0

    var canLoadMore: Bool { lastPage < pages }
    var nextPage: Int { lastPage + 1 }

    mutating func reset() { self = PagedList() }

    /// Adds a page; page 1 replaces everything. Rows already shown (moved between pages) are skipped.
    mutating func append(_ p: Page<T>) {
        if p.page <= 1 { items = [] }
        let known = Set(items.map { AnyHashable($0.id) })
        items += p.items.filter { !known.contains(AnyHashable($0.id)) }
        lastPage = p.page
        pages = max(p.pages, 1)
        total = p.total
    }
}
