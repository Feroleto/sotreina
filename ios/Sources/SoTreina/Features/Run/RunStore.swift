import Foundation
import Observation
import os
import SoTreinaDesign
import SoTreinaKit

/// Corrida's data: the whole history once (`GET /activities?limit=1000`,
/// like the web's `useActivities`), everything else derived on the client.
/// Read only — syncing with Strava stays on the web (spec §4).
@MainActor
@Observable
final class RunStore {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var activities: [ActivityListItem] = []
    private(set) var loadState: LoadState = .idle

    private let session: SessionStore
    private let log = Logger(subsystem: "com.feroleto.sotreina", category: "run")
    @ObservationIgnored private var restoredFromCache = false

    static let query = [URLQueryItem(name: "limit", value: "1000")]

    init(session: SessionStore) {
        self.session = session
    }

    func load() async {
        guard let api = session.cachedAPI else { return }
        restoreFromCacheOnce(api)
        if activities.isEmpty, loadState != .loaded { loadState = .loading }
        do {
            let page: ActivitiesPage? = try await api.get("activities", query: Self.query)
            activities = page?.items ?? []
            loadState = .loaded
        } catch APIError.unauthorized {
            session.expire()
        } catch {
            log.error("activities failed: \(String(describing: error), privacy: .public)")
            // keep what's on screen; only an empty first load shows the error
            if activities.isEmpty {
                loadState = .failed(WorkoutStore.message(for: error, lang: AppLanguageStore.shared.lang))
            }
        }
    }

    /// First load only: the last answer at once (spec §5.2), replaced by the fetch.
    private func restoreFromCacheOnce(_ api: CachedAPI) {
        guard !restoredFromCache else { return }
        restoredFromCache = true
        if let hit: ResponseCache.Hit<ActivitiesPage> = api.cached("activities", query: Self.query) {
            activities = hit.value?.items ?? []
            loadState = .loaded
        }
    }
}
