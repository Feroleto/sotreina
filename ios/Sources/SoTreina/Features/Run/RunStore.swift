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

    /// Visão geral: `GET /personal-bests` (empty on a failure, like the web)
    private(set) var records: [PersonalBestRecord] = []
    /// `GET /gear`; nil until it answers, so the section doesn't flash "no shoes"
    private(set) var gear: [Gear]?
    /// distances whose top 1 changed since this device last saw the records;
    /// kept for the rest of the launch, so the "Novo" badge doesn't vanish on a reload
    private(set) var newRecordKeys: Set<String> = []

    private let session: SessionStore
    private let log = Logger(subsystem: "com.feroleto.sotreina", category: "run")
    @ObservationIgnored private var restoredFromCache = false
    @ObservationIgnored private var restoredOverviewFromCache = false

    static let query = [URLQueryItem(name: "limit", value: "1000")]

    init(session: SessionStore) {
        self.session = session
    }

    /// Records and shoes, in parallel; the activities come from `load()`.
    func loadOverview() async {
        guard let api = session.cachedAPI else { return }
        if !restoredOverviewFromCache {
            restoredOverviewFromCache = true
            if let hit: ResponseCache.Hit<[PersonalBestRecord]> = api.cached("personal-bests") { records = hit.value ?? [] }
            if let hit: ResponseCache.Hit<[Gear]> = api.cached("gear") { gear = hit.value ?? [] }
        }
        async let fetchedRecords: [PersonalBestRecord]? = api.get("personal-bests")
        async let fetchedGear: [Gear]? = api.get("gear")
        do {
            let fresh = try await fetchedRecords ?? []
            records = fresh
            celebrate(fresh, userId: api.userId)
        } catch APIError.unauthorized {
            session.expire()
            return
        } catch {
            log.error("personal-bests failed: \(String(describing: error), privacy: .public)")
        }
        do {
            gear = try await fetchedGear ?? []
        } catch {
            log.error("gear failed: \(String(describing: error), privacy: .public)")
            if gear == nil { gear = [] }
        }
    }

    /// Only a successful fetch moves the snapshot: writing the empty list of
    /// a failed one would make every record "new" next time (prSnapshot.ts).
    private func celebrate(_ records: [PersonalBestRecord], userId: String) {
        let key = PrSnapshot.storageKey(userId: userId)
        let defaults = UserDefaults.standard
        let previous = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(PrSnapshot.Snapshot.self, from: $0) }
        let next = PrSnapshot.topIdentities(records)
        newRecordKeys.formUnion(PrSnapshot.newKeys(previous: previous, next: next))
        if let data = try? JSONEncoder().encode(next) { defaults.set(data, forKey: key) }
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

    /// The cached detail, to draw before the fetch answers.
    func cachedDetail(_ id: String) -> ActivityDetail? {
        let hit: ResponseCache.Hit<ActivityDetail>? = session.cachedAPI?.cached("activities/\(id)")
        return hit?.value ?? nil
    }

    /// `GET /activities/:id`. The failure carries a message to show, nil on a 401.
    func detail(_ id: String) async -> Result<ActivityDetail, WorkoutStore.DetailError> {
        guard let api = session.cachedAPI else { return .failure(.init(message: nil)) }
        let lang = AppLanguageStore.shared.lang
        do {
            guard let detail: ActivityDetail = try await api.get("activities/\(id)") else {
                return .failure(.init(message: WorkoutStore.message(for: APIError.http(status: 404), lang: lang)))
            }
            return .success(detail)
        } catch APIError.unauthorized {
            session.expire()
            return .failure(.init(message: nil))
        } catch {
            log.error("activity \(id, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            return .failure(.init(message: WorkoutStore.message(for: error, lang: lang)))
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
