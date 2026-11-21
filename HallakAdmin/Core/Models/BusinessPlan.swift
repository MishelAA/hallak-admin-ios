import Foundation

// MARK: - API 1.3: business plan 2027–2029 (GET /admin/plan). Named BusinessPlan: `Plan` is a billing plan.

/// GET / PATCH /admin/plan
struct BusinessPlan: Decodable, Hashable {
    struct Changed: Decodable, Hashable {
        let at: String?
        let by: String?
    }
    struct ThreeYear: Decodable, Hashable {
        let targetRevenue: Money?
        let actualRevenue: Money?
    }

    let title: String?
    let subtitle: String?
    let summary: String?
    let assumptions: [String]?
    let currency: String?
    let billingActive: Bool?
    let renewalTarget: Int?
    /// Targets were changed from the original plan.
    let customized: Bool?
    let changed: Changed?
    let years: [PlanYear]?
    let threeYear: ThreeYear?
    let kpis: [PlanKPI]?
    let renewalsDue: [RenewalDue]?
    let checklist: PlanChecklist?
    let roadmap: [RoadmapItem]?
    let budget: PlanBudget?
    let tiers: PlanTiers?
    let recommendation: String?
    let note: String?
    let generatedAt: String?

    /// The year to open on: the current one, else the first.
    var currentYear: PlanYear? { years?.first { $0.current == true } ?? years?.first }
}

struct PlanYear: Decodable, Hashable, Identifiable {
    struct Targets: Decodable, Hashable {
        let new: Int?
        let renewed: Int?
        let total: Int?
        let price: Money?
        let revenue: Money?
        let monthly: Money?
    }
    struct Actual: Decodable, Hashable {
        let started: Bool?
        /// Salons whose FIRST payment is in this year.
        let new: Int?
        /// Salons that paid this year and had paid before.
        let renewed: Int?
        /// Paying at the end of the year (today for the current year). nil before the year starts.
        let totalPaying: Int?
        let revenue: Money?
        let monthly: Money?
        let renewalRate: Int?
        let renewalOf: Int?
    }
    struct Quarter: Decodable, Hashable, Identifiable {
        let q: Int
        let newTarget: Int?
        let cumulativeTarget: Int?
        let actions: String?
        /// nil for future quarters.
        let new: Int?
        let cumulative: Int?
        var id: Int { q }
    }
    struct Progress: Decodable, Hashable {
        let status: PlanStatus?
        /// Paying salons expected today on the way to the target.
        let expectedNow: Int?
        let totalPct: Int?
        let revenuePct: Int?
    }

    let year: Int
    let name: String?
    let objective: String?
    let priorities: [String]?
    let success: String?
    let targets: Targets?
    let actual: Actual?
    let quarters: [Quarter]?
    let progress: Progress?
    let current: Bool?

    var id: Int { year }
    var status: PlanStatus { progress?.status ?? .notStarted }
    /// 0…1 for the ring: paying salons of the target.
    var fraction: Double {
        guard let total = targets?.total, total > 0 else { return 0 }
        return min(1, Double(actual?.totalPaying ?? 0) / Double(total))
    }
}

enum PlanStatus: String, Decodable, Hashable {
    case notStarted = "not_started", onTrack = "on_track", behind, reached, missed, noBilling = "no_billing", unknown

    init(from decoder: Decoder) throws {
        self = PlanStatus(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
    }
}

/// One KPI card. `value` depends on the slug; nil = "track yourself".
struct PlanKPI: Decodable, Hashable, Identifiable {
    struct NewCounts: Decodable, Hashable { let month: Int?; let quarter: Int? }
    struct Pipeline: Decodable, Hashable { let contacted: Int?; let demos: Int?; let offers: Int?; let websiteRequests: Int? }
    struct Unpaid: Decodable, Hashable { let count: Int?; let amount: Money? }
    struct Cash: Decodable, Hashable { let month: Money?; let year: Money?; let unpaid: Unpaid? }

    enum Value: Hashable {
        case number(Int)
        case new(NewCounts)
        case pipeline(Pipeline)
        case cash(Cash)
    }

    let slug: String
    let label: String?
    let what: String?
    let value: Value?

    var id: String { slug }

    private enum CodingKeys: String, CodingKey { case slug, label, what, value }

    init(slug: String, label: String?, what: String?, value: Value?) {
        self.slug = slug
        self.label = label
        self.what = what
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        slug = try c.decode(String.self, forKey: .slug)
        label = try c.decodeIfPresent(String.self, forKey: .label)
        what = try c.decodeIfPresent(String.self, forKey: .what)
        // Unknown shapes are ignored (shown as "track yourself"), never a decoding failure.
        if let n = try? c.decodeIfPresent(Int.self, forKey: .value) {
            value = .number(n)
        } else if slug == "new", let v = try? c.decodeIfPresent(NewCounts.self, forKey: .value) {
            value = .new(v)
        } else if slug == "pipeline", let v = try? c.decodeIfPresent(Pipeline.self, forKey: .value) {
            value = .pipeline(v)
        } else if slug == "cash", let v = try? c.decodeIfPresent(Cash.self, forKey: .value) {
            value = .cash(v)
        } else {
            value = nil
        }
    }
}

/// A salon whose paid time ends within 60 days (or already in grace days).
struct RenewalDue: Decodable, Hashable, Identifiable {
    let salonId: Int
    let salonName: String?
    let status: BillingStatus?
    let until: String?
    let daysLeft: Int?
    let amount: Money?
    let phone: String?
    /// Ready renewal message in the salon language.
    let whatsappLink: String?
    var id: Int { salonId }
}

/// GET / PATCH /admin/plan/checklist (and `checklist` in /admin/plan).
struct PlanChecklist: Decodable, Hashable {
    struct Item: Decodable, Hashable, Identifiable {
        let slug: String
        let label: String?
        /// count = number with − / +1 buttons, check = tick box.
        let type: String?
        let target: Int?
        /// A number for a count line.
        let count: Int?
        /// true / false for a check line.
        let checked: Bool?
        /// Goal reached / ticked. nil = count without a goal.
        let done: Bool?
        let hint: String?

        var id: String { slug }
        var isCheck: Bool { type == "check" }

        private enum CodingKeys: String, CodingKey { case slug, label, type, target, value, done, hint }

        init(slug: String, label: String?, type: String?, target: Int?, count: Int?, checked: Bool?, done: Bool?, hint: String?) {
            self.slug = slug
            self.label = label
            self.type = type
            self.target = target
            self.count = count
            self.checked = checked
            self.done = done
            self.hint = hint
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            slug = try c.decode(String.self, forKey: .slug)
            label = try c.decodeIfPresent(String.self, forKey: .label)
            type = try c.decodeIfPresent(String.self, forKey: .type)
            target = try? c.decodeIfPresent(Int.self, forKey: .target)
            // value is a number for counts and true/false for checks.
            if let b = try? c.decodeIfPresent(Bool.self, forKey: .value) {
                checked = b
                count = nil
            } else {
                count = try? c.decodeIfPresent(Int.self, forKey: .value)
                checked = nil
            }
            done = try? c.decodeIfPresent(Bool.self, forKey: .done)
            hint = try c.decodeIfPresent(String.self, forKey: .hint)
        }
    }

    /// "2027-03"
    let month: String
    let done: Int?
    /// Lines with a goal.
    let of: Int?
    let items: [Item]
    let generatedAt: String?
}

struct RoadmapItem: Decodable, Hashable, Identifiable {
    /// critical | high | medium
    let priority: String?
    let capability: String
    let timing: Int?
    /// ready | partial | planned (from the plugins active on the site)
    let status: String?
    let plugins: [String]?
    var id: String { capability }
}

struct PlanBudget: Decodable, Hashable {
    struct Item: Decodable, Hashable, Identifiable {
        /// hosting | marketing | development | unexpected | reserve
        let slug: String
        let label: String?
        let share: Int?
        let amount: Money?
        let amountTarget: Money?
        var id: String { slug }
    }
    let year: Int?
    /// Cash collected this year.
    let base: Money?
    let baseTarget: Money?
    let note: String?
    let items: [Item]?
}

struct PlanTiers: Decodable, Hashable {
    struct Tier: Decodable, Hashable, Identifiable {
        let name: String
        let price: Money?
        let positioning: String?
        var id: String { name }
    }
    let items: [Tier]?
    let note: String?
}

// MARK: - Endpoints and bodies

extension Endpoint {
    static let businessPlan = Endpoint(.get, "/admin/plan")

    /// month = "YYYY-MM"; nil = this month.
    static func planChecklist(month: String? = nil) -> Endpoint {
        Endpoint(.get, "/admin/plan/checklist", query: ["month": month ?? ""])
    }

    /// Send only what changes (built by PlanTargetsForm.body).
    static func updateBusinessPlan(_ body: JSONBody) -> Endpoint {
        Endpoint(.patch, "/admin/plan", body: try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]))
    }

    static let resetBusinessPlan = Endpoint.updateBusinessPlan(["reset": true])

    /// +1 button: {"add": {"contacts": 1}}.
    static func addToChecklist(_ slug: String, _ n: Int = 1, month: String? = nil) -> Endpoint {
        checklist(["add": [slug: n]], month: month)
    }

    /// Set a value: {"contacts": 12} or {"followups": true}.
    static func setChecklist(_ slug: String, _ value: Any, month: String? = nil) -> Endpoint {
        checklist([slug: value], month: month)
    }

    private static func checklist(_ body: JSONBody, month: String?) -> Endpoint {
        Endpoint(.patch, "/admin/plan/checklist", query: ["month": month ?? ""],
                 body: try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]))
    }
}

/// The edit form (pencil): targets per year, budget shares, checklist goals, renewal target.
struct PlanTargetsForm: Equatable {
    struct Year: Equatable {
        var new = 0
        var renewed = 0
        var total = 0
        var price: Double = 0
        var quarters = [0, 0, 0, 0]
        var cumulative = [0, 0, 0, 0]

        var json: JSONBody {
            ["new": new, "renewed": renewed, "total": total, "price": price, "quarters": quarters, "cumulative": cumulative]
        }
    }

    static let budgetSlugs = ["hosting", "marketing", "development", "unexpected", "reserve"]
    static let goalSlugs = ["contacts", "demos", "posts"]

    var years: [Int: Year] = [:]
    var budget: [String: Int] = [:]
    var goals: [String: Int] = [:]
    var renewal = 0

    init() {}

    init(from plan: BusinessPlan) {
        for y in plan.years ?? [] {
            var f = Year()
            f.new = y.targets?.new ?? 0
            f.renewed = y.targets?.renewed ?? 0
            f.total = y.targets?.total ?? 0
            f.price = y.targets?.price?.amount ?? 0
            let qs = (y.quarters ?? []).sorted { $0.q < $1.q }
            for (i, q) in qs.prefix(4).enumerated() {
                f.quarters[i] = q.newTarget ?? 0
                f.cumulative[i] = q.cumulativeTarget ?? 0
            }
            years[y.year] = f
        }
        for item in plan.budget?.items ?? [] where Self.budgetSlugs.contains(item.slug) {
            budget[item.slug] = item.share ?? 0
        }
        for item in plan.checklist?.items ?? [] where Self.goalSlugs.contains(item.slug) {
            goals[item.slug] = item.target ?? 0
        }
        renewal = plan.renewalTarget ?? 0
    }

    var budgetSum: Int { budget.values.reduce(0, +) }
    var budgetOK: Bool { budget.isEmpty || budgetSum == 100 }

    /// PATCH body with only the parts that changed (a changed year is sent whole). Empty = nothing to save.
    func body(comparedTo original: PlanTargetsForm) -> JSONBody {
        var b: JSONBody = [:]
        var ys: JSONBody = [:]
        for (year, f) in years where original.years[year] != f { ys[String(year)] = f.json }
        if !ys.isEmpty { b["years"] = ys }
        if budget != original.budget { b["budget"] = budget }
        var g: JSONBody = [:]
        for (slug, n) in goals where original.goals[slug] != n { g[slug] = n }
        if !g.isEmpty { b["checklist"] = g }
        if renewal != original.renewal { b["renewal"] = renewal }
        return b
    }
}

extension Me {
    /// API 1.3: /admin/plan is available.
    var canPlan: Bool { can?.plan ?? false }
}
