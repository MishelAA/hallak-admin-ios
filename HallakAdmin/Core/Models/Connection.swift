import Foundation

/// GET /admin/ping
struct Ping: Decodable, Hashable {
    let ok: Bool
    let user: String?
    let site: String?
    let wordpress: String?
    let hallakCore: String?
    let api: String?
    let https: Bool?
    let generatedAt: String?
}

/// UserShort (+ role on /salons/{id}/users: owner | staff | other).
struct UserShort: Decodable, Hashable, Identifiable {
    let id: Int
    let username: String?
    let name: String?
    let email: String?
    let lastLogin: String?
    let role: String?

    var displayName: String { (name?.isEmpty == false ? name : username) ?? "#\(id)" }
}

/// GET /admin/me
struct Me: Decodable, Hashable {
    struct Can: Decodable, Hashable {
        let read: Bool?
        let write: Bool?
        /// API 1.1: POST /admin/login-link is available.
        let openLinks: Bool?
        /// API 1.3: /admin/plan is available.
        let plan: Bool?
        /// API 1.4 + Demo plugin 1.1: /admin/demos.
        let demos: Bool?
    }
    struct Plugins: Decodable, Hashable {
        let billing: Bool?
        let site: Bool?
        let whatsapp: Bool?
        let ai: Bool?
        let check: Bool?
        /// API 1.5: Security plugin 1.0.1+.
        let security: Bool?
    }
    struct Site: Decodable, Hashable {
        let name: String?
        let url: String?
        let wordpress: String?
        let hallakCore: String?
        let api: String?
        let plugins: Plugins?
    }

    let user: UserShort?
    let language: String?
    let can: Can?
    let site: Site?
    let generatedAt: String?

    /// false in API 1.0: action buttons stay hidden until 1.1.
    var canWrite: Bool { can?.write ?? false }
    /// Sign-in links (API 1.1). Unknown (older answer) counts as yes: the app falls back if the route is missing.
    var canOpenLinks: Bool { can?.openLinks ?? true }
    // A missing flag counts as "on": the API also leaves out sections whose plugin is off.
    var hasBilling: Bool { site?.plugins?.billing ?? true }
    var hasWhatsApp: Bool { site?.plugins?.whatsapp ?? true }
    var hasAI: Bool { site?.plugins?.ai ?? true }
    var hasCheck: Bool { site?.plugins?.check ?? true }
    var hasSite: Bool { site?.plugins?.site ?? true }
}

/// GET /admin/features
struct Feature: Decodable, Hashable, Identifiable {
    let slug: String
    let label: String?
    let help: String?
    /// false = optional feature, off until switched on for a salon.
    let isDefault: Bool?

    var id: String { slug }

    private enum CodingKeys: String, CodingKey { case slug, label, help, isDefault = "default" }
}
