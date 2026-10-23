import Foundation

/// Read cache for `GET` responses (spec §5.2 of app-ios-completo): the last
/// body of each endpoint, kept per user so opening a screen shows data at
/// once while the fresh copy loads. Stores the response bytes as received
/// (or re-encoded after a mutation), never a schema of its own — the server
/// stays the source of truth, and a new answer always replaces the old.
public struct ResponseCache: Sendable {
    /// A cached answer. `value` is nil when the server answered with an empty
    /// body (e.g. `GET /workouts/active` with no open workout) — which is
    /// different from "nothing cached" (`read` returning nil).
    public struct Hit<Value> {
        public var value: Value?
    }

    private let root: URL

    /// `root` is the cache's own folder (the app passes one inside Caches/).
    public init(root: URL) {
        self.root = root
    }

    /// File name for an endpoint: a readable slug plus a stable hash of the
    /// canonical path+query, so `a/b` and `a_b` never collide and query
    /// order doesn't matter.
    public static func key(path: String, query: [URLQueryItem] = []) -> String {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let sortedQuery = query
            .sorted { ($0.name, $0.value ?? "") < ($1.name, $1.value ?? "") }
            .map { "\($0.name)=\($0.value ?? "")" }
            .joined(separator: "&")
        let canonical = sortedQuery.isEmpty ? trimmed : "\(trimmed)?\(sortedQuery)"
        let slug = String(canonical.map { $0.isLetter || $0.isNumber || $0 == "-" ? $0 : "_" }.prefix(60))
        return "\(slug)-\(fnv1a(canonical))"
    }

    public func read(userId: String, key: String) -> Data? {
        try? Data(contentsOf: file(userId: userId, key: key))
    }

    /// Decodes a cached body; a file that no longer decodes (the model changed
    /// in an update) reads as a miss rather than an error.
    public func read<Value: Decodable>(_ type: Value.Type, userId: String, key: String) -> Hit<Value>? {
        guard let data = read(userId: userId, key: key) else { return nil }
        if data.isEmpty { return Hit(value: nil) }
        guard let value = try? APICoding.makeDecoder().decode(Value.self, from: data) else { return nil }
        return Hit(value: value)
    }

    /// Best-effort: a cache that can't be written is just a slower next launch.
    public func write(_ data: Data, userId: String, key: String) {
        let url = file(userId: userId, key: key)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    /// After a mutation: the new state, so a relaunch doesn't show the old one.
    /// nil stores an empty body (same as the server's "nothing here").
    public func write<Value: Encodable>(_ value: Value?, userId: String, key: String) {
        let data = value.flatMap { try? APICoding.makeEncoder().encode($0) } ?? Data()
        write(data, userId: userId, key: key)
    }

    /// Logout and 401: nothing of the leaving account stays on the device.
    public func clearAll() {
        try? FileManager.default.removeItem(at: root)
    }

    private func file(userId: String, key: String) -> URL {
        // userId is a cuid from the server; sanitized anyway since it names a folder
        let folder = String(userId.map { $0.isLetter || $0.isNumber ? $0 : "_" })
        return root.appending(path: folder).appending(path: "\(key).json")
    }

    /// 64-bit FNV-1a: stable across launches, unlike `hashValue`.
    private static func fnv1a(_ text: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(hash, radix: 16)
    }
}
