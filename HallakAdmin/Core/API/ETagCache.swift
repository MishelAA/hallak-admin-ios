import CryptoKit
import Foundation

/// The last answer and its ETag for each URL, kept on disk in Caches so screens open instantly.
/// Only API answers are stored here: never the login.
actor ETagCache {
    struct Entry: Codable, Equatable {
        let etag: String?
        let body: Data
        let savedAt: Date
    }

    private let folder: URL?
    private var memory: [String: Entry] = [:]

    /// `folder == nil` keeps everything in memory only (tests).
    init(folder: URL? = ETagCache.defaultFolder) {
        self.folder = folder
        if let folder {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }

    static var defaultFolder: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("hallak-api", isDirectory: true)
    }

    /// The key includes the language: labels in the answer differ between en and ar.
    static func key(url: URL, language: String) -> String {
        let digest = SHA256.hash(data: Data("\(language)|\(url.absoluteString)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func entry(for key: String) -> Entry? {
        if let e = memory[key] { return e }
        guard let file = fileURL(key), let data = try? Data(contentsOf: file),
              let e = try? JSONDecoder().decode(Entry.self, from: data) else { return nil }
        memory[key] = e
        return e
    }

    func store(_ entry: Entry, for key: String) {
        memory[key] = entry
        guard let file = fileURL(key), let data = try? JSONEncoder().encode(entry) else { return }
        try? data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    /// Log out: forget everything.
    func clear() {
        memory.removeAll()
        guard let folder else { return }
        try? FileManager.default.removeItem(at: folder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    private func fileURL(_ key: String) -> URL? {
        folder?.appendingPathComponent(key + ".json")
    }
}
