import Foundation

/// GET /admin/health: the Hallak check report.
struct Health: Decodable, Hashable {
    struct Plugin: Decodable, Hashable, Identifiable {
        let number: Int?
        let folder: String?
        let name: String?
        let installed: String?
        let latest: String?
        let active: Bool?
        let upToDate: Bool?
        var id: String { folder ?? name ?? String(number ?? 0) }
    }

    enum Level: String, Decodable, Hashable, Comparable {
        case error, warn, info

        init(from decoder: Decoder) throws {
            let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
            self = Level(rawValue: raw) ?? .info
        }

        private var rank: Int {
            switch self {
            case .error: return 0
            case .warn: return 1
            case .info: return 2
            }
        }

        static func < (l: Level, r: Level) -> Bool { l.rank < r.rank }
    }

    struct Problem: Decodable, Hashable {
        let level: Level
        let text: String
    }

    let available: Bool?
    let checkVersion: String?
    let environment: [String: FlexibleString]?
    let plugins: [Plugin]?
    let problems: [Problem]?
    let generatedAt: String?

    /// Errors first, then warnings, then info.
    var sortedProblems: [Problem] { (problems ?? []).sorted { $0.level < $1.level } }
}
