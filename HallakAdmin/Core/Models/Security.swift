import SwiftUI

// MARK: - API 1.5: GET /admin/security (read only, Security plugin 1.0.1+)

/// What wp-admin → Salons → Security shows. The app never changes security settings.
struct Security: Decodable, Hashable {
    enum State: String, Decodable, Hashable {
        case ok, warn, bad, info, unknown
        init(from decoder: Decoder) throws {
            self = State(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
        }
        var color: Color {
            switch self {
            case .ok: return Theme.green
            case .warn: return Theme.orange
            case .bad: return Theme.red
            case .info, .unknown: return Theme.grey
            }
        }
    }
    struct Summary: Decodable, Hashable {
        let ok: Int?
        let warn: Int?
        let bad: Int?
    }
    struct Check: Decodable, Hashable, Identifiable {
        let state: State
        let label: String
        /// How to fix it (empty when ok), in the app language.
        let help: String?
        var id: String { "\(state.rawValue)|\(label)" }
    }
    struct Files: Decodable, Hashable {
        struct Item: Decodable, Hashable, Identifiable {
            let group: String
            let path: String
            var id: String { group + "|" + path }
        }
        /// nil = the file check never ran.
        let lastCheck: String?
        /// 0 = all good.
        let toLookAt: Int?
        let counts: [String: Int]?
        /// The first 30 files.
        let items: [Item]?

        static let groups = ["changed", "new", "removed", "uploads", "wordpress_changed", "unknown_in_wordpress"]

        struct Group: Hashable, Identifiable {
            let group: String
            let items: [Item]
            var id: String { group }
        }

        /// The items by group, in the brief's order (unknown groups last).
        var grouped: [Group] {
            let all = items ?? []
            let order = Self.groups + all.map(\.group).filter { !Self.groups.contains($0) }
            var seen = Set<String>()
            return order.compactMap { g in
                guard seen.insert(g).inserted else { return nil }
                let list = all.filter { $0.group == g }
                return list.isEmpty ? nil : Group(group: g, items: list)
            }
        }
    }
    struct Logins: Decodable, Hashable {
        struct Event: Decodable, Hashable, Identifiable {
            let time: String?
            let type: String?
            let level: State?
            let text: String?
            let ip: String?
            let user: String?
            var id: String { [time, type, ip, user, text].map { $0 ?? "" }.joined(separator: "|") }
        }
        let blockedNow: Int?
        let failed24h: Int?
        let blocked24h: Int?
        /// Newest first (20).
        let recent: [Event]?

        // "failed_24h": convertFromSnakeCase makes "failed24H" (capital H). Both spellings are read.
        private struct Key: CodingKey {
            let stringValue: String
            init(_ s: String) { stringValue = s }
            init?(stringValue: String) { self.stringValue = stringValue }
            var intValue: Int? { nil }
            init?(intValue: Int) { nil }
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Key.self)
            func int(_ names: String...) -> Int? {
                for n in names { if let v = try? c.decodeIfPresent(Int.self, forKey: Key(n)) { return v } }
                return nil
            }
            blockedNow = int("blockedNow", "blocked_now")
            failed24h = int("failed24H", "failed24h", "failed_24h")
            blocked24h = int("blocked24H", "blocked24h", "blocked_24h")
            recent = try? c.decodeIfPresent([Event].self, forKey: Key("recent"))
        }
    }
    struct TwoStep: Decodable, Hashable {
        let admins: Int?
        let withTwoStep: Int?
        let allProtected: Bool?
    }

    let available: Bool?
    /// 0–100.
    let score: Int?
    let summary: Summary?
    let checks: [Check]?
    let files: Files?
    let logins: Logins?
    let twoStep: TwoStep?
    let generatedAt: String?

    /// Checks: bad first, then warn, then ok (the API order kept inside each).
    var sortedChecks: [Check] {
        let rank: [State: Int] = [.bad: 0, .warn: 1, .ok: 3]
        return (checks ?? []).enumerated()
            .sorted { (rank[$0.element.state] ?? 2, $0.offset) < (rank[$1.element.state] ?? 2, $1.offset) }
            .map(\.element)
    }

    var badCount: Int { summary?.bad ?? (checks ?? []).filter { $0.state == .bad }.count }
    var warnCount: Int { summary?.warn ?? (checks ?? []).filter { $0.state == .warn }.count }
    var filesToLookAt: Int { files?.toLookAt ?? 0 }

    /// Home card: red when a check is bad or files need a look; orange for warn; else green.
    var level: State {
        if badCount > 0 || filesToLookAt > 0 { return .bad }
        if warnCount > 0 { return .warn }
        return .ok
    }

    /// Score ring: green from 85, orange from 60, red below.
    static func scoreColor(_ score: Int) -> Color {
        score >= 85 ? Theme.green : (score >= 60 ? Theme.orange : Theme.red)
    }
}

extension Security.Files {
    static func groupLabel(_ g: String) -> String {
        switch g {
        case "changed": return String(localized: "Changed files")
        case "new": return String(localized: "New files")
        case "removed": return String(localized: "Removed files")
        case "uploads": return String(localized: "Program files in uploads")
        case "wordpress_changed": return String(localized: "Changed WordPress files")
        case "unknown_in_wordpress": return String(localized: "Files WordPress does not have")
        default: return g
        }
    }
}

extension Endpoint {
    static let security = Endpoint(.get, "/admin/security")
}

extension Me {
    /// Security plugin 1.0.1+ (API 1.5). A missing flag counts as off.
    var hasSecurity: Bool { site?.plugins?.security ?? false }
}

extension AppSession {
    /// Security screen: API 1.5+, the plugin on, and the endpoint did not answer 404 smapi_no_security.
    var showsSecurity: Bool {
        APIVersion.isAtLeast(ping?.api ?? me?.site?.api, "1.5.0") && (me?.hasSecurity ?? false) && !securityOff
    }
}
