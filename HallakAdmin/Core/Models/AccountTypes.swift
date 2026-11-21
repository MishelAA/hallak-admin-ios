import SwiftUI

// MARK: - API 1.4: account types (billing.type) and demo salons (/admin/demos)

/// paid = billed on its plan · trial = free until `until`, then billed · free = never billed · demo = never billed, left out of the numbers.
enum AccountType: String, Decodable, CaseIterable, Hashable, Identifiable {
    case paid, trial, free, demo, unknown

    static let choices: [AccountType] = [.paid, .trial, .free, .demo]
    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        self = AccountType(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
    }

    /// Short words for the segmented control and the filter chips (the API's `type_label` wins on chips).
    var label: String {
        switch self {
        case .paid: return String(localized: "Paid")
        case .trial: return String(localized: "Free trial")
        case .free: return String(localized: "Free")
        case .demo: return String(localized: "Demo")
        case .unknown: return "–"
        }
    }

    var color: Color {
        switch self {
        case .paid: return Theme.green
        case .trial: return Theme.blue
        case .free, .unknown: return Theme.grey
        case .demo: return Theme.purple
        }
    }
}

/// Trial lengths the API accepts ("7", "14" days; "1m", "2m", "3m" months).
enum TrialLength: String, CaseIterable, Identifiable {
    case days7 = "7", days14 = "14", month1 = "1m", month2 = "2m", month3 = "3m"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .days7: return String(localized: "7 days")
        case .days14: return String(localized: "14 days")
        case .month1: return String(localized: "1 month")
        case .month2: return String(localized: "2 months")
        case .month3: return String(localized: "3 months")
        }
    }
}

enum APIVersion {
    /// "1.4.0" ≥ "1.4"? Missing parts count as 0; nil or garbage = false.
    static func isAtLeast(_ version: String?, _ minimum: String) -> Bool {
        guard let version, !version.isEmpty else { return false }
        func parts(_ s: String) -> [Int] { s.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 } }
        let a = parts(version), b = parts(minimum)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return true
    }
}

extension AppSession {
    /// Account types are shown only when the API answers 1.4 or newer.
    var hasAccountTypes: Bool { APIVersion.isAtLeast(ping?.api ?? me?.site?.api, "1.4.0") }
    /// More → Demo salons (/admin/me can.demos).
    var canDemos: Bool { me?.can?.demos ?? false }
}

extension Billing {
    /// "Trial ends in N days" on the salon header (trials ending within 7 days).
    var trialEndsSoon: Int? {
        guard type == .trial, let d = daysLeft, d >= 0, d <= 7 else { return nil }
        return d
    }
}

// MARK: - Demo salons

struct DemoSalon: Decodable, Hashable, Identifiable {
    struct Links: Decodable, Hashable {
        let owner: String?
        let barber: String?
    }
    /// Demo number ("2").
    let key: String
    let name: String?
    let built: Bool?
    let salonId: Int?
    /// en | ar
    let language: String?
    /// Anyone can open it without a password (share links).
    let `public`: Bool?
    /// Back to the start every night at 03:00.
    let nightly: Bool?
    /// Opened by the home-page "Try the demo" button.
    let main: Bool?
    let builtAt: String?
    let ownerLogin: String?
    let barberLogin: String?
    /// Demo logins only (public by design).
    let password: String?
    let barberPassword: String?
    let links: Links?
    let dashboard: String?

    var id: String { key }
    var isPublic: Bool { self.public ?? false }
    var flag: String { language == "ar" ? "🇱🇧" : "🇬🇧" }
}

/// GET /admin/demos, DELETE answer.
struct DemoList: Decodable, Hashable {
    let items: [DemoSalon]
    let max: Int?
    let canAdd: Bool?
    /// Modules the demo needs that are not active.
    let missing: [String]?
    let languages: [String]?
    let generatedAt: String?
}

/// POST /admin/demos, PATCH, reset.
struct DemoOne: Decodable, Hashable {
    let demo: DemoSalon
    let generatedAt: String?
}

extension Endpoint {
    static let demos = Endpoint(.get, "/admin/demos")

    static func createDemo(name: String, lang: String, isPublic: Bool, nightly: Bool) -> Endpoint {
        var b: JSONBody = ["lang": lang, "public": isPublic, "nightly": nightly]
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !n.isEmpty { b["name"] = n }
        return Endpoint(.post, "/admin/demos", body: demoJSON(b))
    }

    /// Only the switches given are sent: public, nightly, main.
    static func updateDemo(_ key: String, isPublic: Bool? = nil, nightly: Bool? = nil, main: Bool? = nil) -> Endpoint {
        var b: JSONBody = [:]
        if let isPublic { b["public"] = isPublic }
        if let nightly { b["nightly"] = nightly }
        if let main { b["main"] = main }
        return Endpoint(.patch, "/admin/demos/\(demoKey(key))", body: demoJSON(b))
    }

    static func resetDemo(_ key: String, lang: String? = nil) -> Endpoint {
        Endpoint(.post, "/admin/demos/\(demoKey(key))/reset", body: demoJSON(lang.map { ["lang": $0] } ?? [:]))
    }

    static func deleteDemo(_ key: String) -> Endpoint { Endpoint(.delete, "/admin/demos/\(demoKey(key))") }

    private static func demoJSON(_ b: JSONBody) -> Data? { try? JSONSerialization.data(withJSONObject: b, options: [.sortedKeys]) }
    /// Keys are short numbers; anything else is escaped so it stays one path part.
    private static func demoKey(_ key: String) -> String {
        key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
    }
}
