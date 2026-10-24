import Foundation
import Observation
import os
import SoTreinaKit

/// Dieta › Histórico: `GET /food-logs/history?days=7|14`, zero-filled per
/// day in the user's time zone (`X-Time-Zone`). Each range goes through the
/// read cache, so switching 7/14 or reopening the page draws the last answer
/// at once while the fetch runs.
@MainActor
@Observable
final class DietHistoryStore {
    private(set) var points: [DailyHistoryPoint] = []
    private(set) var loadState: WorkoutStore.LoadState = .idle
    private(set) var range = 7
    private let session: SessionStore
    @ObservationIgnored private let log = Logger(subsystem: "com.feroleto.sotreina", category: "diet-history")

    init(session: SessionStore) {
        self.session = session
    }

    private func query(_ days: Int) -> [URLQueryItem] { [URLQueryItem(name: "days", value: String(days))] }

    func select(range days: Int) async {
        guard days != range else { return }
        range = days
        await load(restoring: true)
    }

    /// Every time the page shows: Registros may have come from the web or
    /// from Visão geral since.
    func load() async {
        await load(restoring: loadState == .idle)
    }

    private func load(restoring: Bool) async {
        guard let api = session.cachedAPI else { return }
        let days = range
        if restoring, let hit: ResponseCache.Hit<[DailyHistoryPoint]> = api.cached("food-logs/history", query: query(days)) {
            points = hit.value ?? []
            loadState = .loaded
        }
        if loadState != .loaded { loadState = .loading }
        do {
            let fetched: [DailyHistoryPoint] = try await api.get("food-logs/history", query: query(days)) ?? []
            // a slower answer for the other range must not land on this one
            guard range == days else { return }
            points = fetched
            loadState = .loaded
        } catch {
            // keep what's on screen; only an empty first load shows the error
            if let message = handle(error), points.isEmpty { loadState = .failed(message) }
        }
    }

    private func handle(_ error: Error) -> String? {
        if case APIError.unauthorized = error {
            session.expire()
            return nil
        }
        log.error("request failed: \(String(describing: error), privacy: .public)")
        return WorkoutStore.message(for: error, lang: AppLanguageStore.shared.lang)
    }
}
