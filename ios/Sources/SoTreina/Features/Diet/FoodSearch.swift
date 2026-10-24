import Foundation
import Observation
import SoTreinaKit

/// The food search under Adicionar and the saved meal editor (`GET
/// /foods/search`, local only, never the Open Food Facts), debounced like
/// the web's 250 ms.
@MainActor
@Observable
final class FoodSearch {
    private(set) var results: [FoodListItem] = []
    private(set) var searching = false

    private let session: SessionStore

    static let debounce: Duration = .milliseconds(250)

    init(session: SessionStore) {
        self.session = session
    }

    /// Called from `.task(id: query)`: a newer query cancels the sleep.
    func run(_ query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            results = []
            searching = false
            return
        }
        searching = true
        do {
            try await Task.sleep(for: Self.debounce)
            let found: [FoodListItem]? = try await session.api.get("foods/search", query: [URLQueryItem(name: "q", value: trimmed)])
            results = found ?? []
        } catch is CancellationError {
            return
        } catch {
            if case APIError.unauthorized = error { session.expire() }
            results = []
        }
        searching = false
    }
}
