import Foundation
import Observation
import os
import SoTreinaDesign
import SoTreinaKit

/// Corrida's data: the whole history once (`GET /activities?limit=1000`,
/// like the web's `useActivities`), everything else derived on the client.
/// The only sync it drives is the first import after connecting Strava
/// (spec login-app-ios §5.3); the cron keeps it up to date after that.
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

    /// The first import, shown in place of Corrida while there's no run yet
    /// (spec login-app-ios §5.3). Nil once it ends, whatever the outcome:
    /// Corrida then shows what arrived, and the cron fetches the rest.
    private(set) var firstSync: FirstSync?

    enum FirstSync: Equatable {
        case running(SyncStatus)
        /// the server's sync lock was busy (another account's import or the
        /// cron), so nothing started for this account
        case notStarted
    }

    private let session: SessionStore
    private let log = Logger(subsystem: "com.feroleto.sotreina", category: "run")
    @ObservationIgnored private var restoredFromCache = false
    @ObservationIgnored private var restoredOverviewFromCache = false
    /// a validation launch's fixed first-sync status: never polled
    @ObservationIgnored private var previewing = false

    static let query = [URLQueryItem(name: "limit", value: "1000")]

    init(session: SessionStore) {
        self.session = session
        #if DEBUG
        if case .runFirstSync(let paused) = ValidationLaunch.current.destination {
            previewing = true
            firstSync = .running(SyncStatus(
                state: .running, phase: paused ? .rateLimited : .processing, total: 184, processed: 73,
                etaSeconds: 420, processingDate: Calendar.current.date(from: DateComponents(year: 2022, month: 5, day: 8)),
                rateLimitResetAt: paused ? Date.now.addingTimeInterval(9 * 60 + 12) : nil
            ))
        }
        #endif
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
            if activities.isEmpty { await checkFirstSync() }
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

    // MARK: First sync

    /// No run yet: an import running on the server takes over the screen
    /// (a reopen mid-import lands here too). Right after connecting, an idle
    /// status means the callback's sync was skipped, so start one.
    private func checkFirstSync() async {
        guard let status = await syncStatus() else { return }
        if status.state == .running {
            firstSync = .running(status)
        } else if session.stravaJustConnected {
            session.stravaJustConnected = false
            if status.state == .idle { await startFirstSync() }
        }
    }

    /// `POST /strava/sync`; "not running" back means the lock is still busy.
    func startFirstSync() async {
        do {
            let status: SyncStatus? = try await session.api.post("strava/sync")
            if let status, status.state == .running {
                firstSync = .running(status)
            } else {
                firstSync = .notStarted
            }
        } catch APIError.unauthorized {
            session.expire()
        } catch {
            log.error("strava/sync failed: \(String(describing: error), privacy: .public)")
            firstSync = .notStarted
        }
    }

    /// Every 2 s while the screen is up (its `.task`); at the end, the runs
    /// that arrived. A failed poll just waits for the next one.
    func pollFirstSync() async {
        guard !previewing else { return }
        while case .running = firstSync {
            try? await Task.sleep(for: .seconds(2))
            if Task.isCancelled { return }
            guard let status = await syncStatus() else { continue }
            if status.state == .running {
                firstSync = .running(status)
            } else {
                firstSync = nil
                async let activities: Void = load()
                async let overview: Void = loadOverview()
                _ = await (activities, overview)
            }
        }
    }

    private func syncStatus() async -> SyncStatus? {
        do {
            return try await session.api.get("strava/sync/status")
        } catch APIError.unauthorized {
            session.expire()
        } catch {
            log.error("strava/sync/status failed: \(String(describing: error), privacy: .public)")
        }
        return nil
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
