import Foundation
import SoTreinaKit

/// `GET`s through the read cache (spec §5.2): `cached` gives the last answer
/// at once, `get` fetches and refreshes it. Writes never go through here —
/// they need the network and their result is stored with `store`.
struct CachedAPI {
    let api: APIClient
    let userId: String

    /// One folder inside Caches/ (the system may purge it; that only costs
    /// one slower launch).
    static let cache = ResponseCache(
        root: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "ResponseCache")
    )

    func cached<Value: Decodable>(_ path: String, query: [URLQueryItem] = []) -> ResponseCache.Hit<Value>? {
        Self.cache.read(Value.self, userId: userId, key: ResponseCache.key(path: path, query: query))
    }

    func get<Value: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> Value? {
        let data = try await api.getData(path, query: query)
        let value: Value? = data.isEmpty ? nil : try APICoding.makeDecoder().decode(Value.self, from: data)
        // only after it decoded: a body this build can't read isn't worth keeping
        Self.cache.write(data, userId: userId, key: ResponseCache.key(path: path, query: query))
        return value
    }

    /// The state a mutation produced, so a relaunch doesn't flash the old one.
    func store<Value: Encodable>(_ value: Value?, as path: String, query: [URLQueryItem] = []) {
        Self.cache.write(value, userId: userId, key: ResponseCache.key(path: path, query: query))
    }
}
