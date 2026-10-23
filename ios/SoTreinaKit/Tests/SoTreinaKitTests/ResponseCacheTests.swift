import Foundation
import Testing
@testable import SoTreinaKit

@Suite struct ResponseCacheTests {
    private let root = FileManager.default.temporaryDirectory.appending(path: "ResponseCacheTests-\(UUID().uuidString)")
    private var cache: ResponseCache { ResponseCache(root: root) }

    private struct Item: Codable, Equatable {
        var name: String
        var at: Date
    }

    @Test func keyIgnoresQueryOrderAndSlashes() {
        let a = ResponseCache.key(path: "/exercises", query: [
            URLQueryItem(name: "search", value: "supino"), URLQueryItem(name: "limit", value: "40"),
        ])
        let b = ResponseCache.key(path: "exercises/", query: [
            URLQueryItem(name: "limit", value: "40"), URLQueryItem(name: "search", value: "supino"),
        ])
        #expect(a == b)
        #expect(a.hasPrefix("exercises_limit_40_search_supino-"))
    }

    @Test func keysThatSlugTheSameStillDiffer() {
        #expect(ResponseCache.key(path: "a/b") != ResponseCache.key(path: "a_b"))
        #expect(ResponseCache.key(path: "workouts/active") != ResponseCache.key(path: "workouts/activ"))
    }

    @Test func keyIsStableAcrossCalls() {
        #expect(ResponseCache.key(path: "workout-templates") == ResponseCache.key(path: "workout-templates"))
        #expect(!ResponseCache.key(path: String(repeating: "x", count: 200)).isEmpty)
    }

    @Test func roundTripsRawBytesAndDecodes() throws {
        let key = ResponseCache.key(path: "items")
        let json = Data(#"{"name":"Upper","at":"2026-10-22T20:00:15.273Z"}"#.utf8)
        cache.write(json, userId: "u1", key: key)

        #expect(cache.read(userId: "u1", key: key) == json)
        let hit = try #require(cache.read(Item.self, userId: "u1", key: key))
        #expect(hit.value?.name == "Upper")
    }

    @Test func missEmptyBodyAndUndecodableAreDistinct() {
        let key = ResponseCache.key(path: "workouts/active")
        #expect(cache.read(Item.self, userId: "u1", key: key) == nil)

        cache.write(Data(), userId: "u1", key: key)
        let empty = cache.read(Item.self, userId: "u1", key: key)
        #expect(empty != nil)
        #expect(empty?.value == nil)

        // a body from an older model that no longer decodes is a miss, not a crash
        cache.write(Data(#"{"other":1}"#.utf8), userId: "u1", key: key)
        #expect(cache.read(Item.self, userId: "u1", key: key) == nil)
    }

    @Test func writingAValueReadsBackTheSame() throws {
        let key = ResponseCache.key(path: "items")
        let item = Item(name: "Push", at: Date(timeIntervalSince1970: 1_792_000_000))
        cache.write(item, userId: "u1", key: key)
        #expect(try #require(cache.read(Item.self, userId: "u1", key: key)).value == item)

        cache.write(Item?.none, userId: "u1", key: key)
        #expect(try #require(cache.read(Item.self, userId: "u1", key: key)).value == nil)
    }

    @Test func usersAreIsolatedAndClearAllWipesEverything() {
        let key = ResponseCache.key(path: "items")
        cache.write(Data("1".utf8), userId: "u1", key: key)
        cache.write(Data("2".utf8), userId: "u2", key: key)
        #expect(cache.read(userId: "u1", key: key) == Data("1".utf8))
        #expect(cache.read(userId: "u2", key: key) == Data("2".utf8))

        cache.clearAll()
        #expect(cache.read(userId: "u1", key: key) == nil)
        #expect(cache.read(userId: "u2", key: key) == nil)
        // and writing again afterwards still works
        cache.write(Data("3".utf8), userId: "u1", key: key)
        #expect(cache.read(userId: "u1", key: key) == Data("3".utf8))
    }
}
