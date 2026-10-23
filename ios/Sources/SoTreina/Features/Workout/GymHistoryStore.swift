import Foundation
import Observation
import os
import SoTreinaKit

/// Treino › Histórico: `GET /workouts/history-stats` (finished workouts of the
/// last 180 days) and, per row, `GET /workouts/:id`. Both through the read
/// cache: a finished workout never changes, and the list shows the last
/// answer at once while the fetch runs.
@MainActor
@Observable
final class GymHistoryStore {
    private(set) var items: [WorkoutHistoryItem] = []
    private(set) var loadState: WorkoutStore.LoadState = .idle
    private let session: SessionStore
    private var restoredFromCache = false
    @ObservationIgnored private let log = Logger(subsystem: "com.feroleto.sotreina", category: "history")

    init(session: SessionStore) {
        self.session = session
    }

    var weightUnit: WeightUnit { session.weightUnit }

    /// Every time the page shows (a workout finished since then must appear).
    func load() async {
        guard let api = session.cachedAPI else { return }
        if !restoredFromCache {
            restoredFromCache = true
            if let hit: ResponseCache.Hit<[WorkoutHistoryItem]> = api.cached("workouts/history-stats") {
                items = hit.value ?? []
                loadState = .loaded
            }
        }
        if loadState != .loaded { loadState = .loading }
        do {
            items = try await api.get("workouts/history-stats") ?? []
            loadState = .loaded
        } catch {
            // keep what's on screen; only an empty first load shows the error
            if let message = handle(error), items.isEmpty { loadState = .failed(message) }
        }
    }

    /// The cached copy, to draw before the fetch answers.
    func cachedWorkout(_ id: String) -> WorkoutDetail? {
        let hit: ResponseCache.Hit<WorkoutDetail>? = session.cachedAPI?.cached("workouts/\(id)")
        return hit?.value ?? nil
    }

    /// `GET /workouts/:id`. Throws a message to show, nil on a 401.
    func workout(_ id: String) async -> Result<WorkoutDetail, WorkoutStore.DetailError> {
        guard let api = session.cachedAPI else { return .failure(.init(message: nil)) }
        do {
            guard let detail: WorkoutDetail = try await api.get("workouts/\(id)") else {
                return .failure(.init(message: WorkoutStore.message(for: APIError.http(status: 404), lang: AppLanguageStore.shared.lang)))
            }
            return .success(detail)
        } catch {
            return .failure(.init(message: handle(error)))
        }
    }

    /// `GET /exercises/:id`, best-effort: only the muscle chip needs it.
    func exercise(_ id: String) async -> ExerciseDetail? {
        try? await session.api.get("exercises/\(id)")
    }

    /// Visão geral › Recordes pessoais: `GET /exercises/:id/personal-record`.
    /// `.success(nil)` is "no record yet"; a failure carries the message.
    func personalRecord(exerciseId: String) async -> Result<ExercisePersonalRecord?, WorkoutStore.DetailError> {
        do {
            let record: ExercisePersonalRecord? = try await session.api.get("exercises/\(exerciseId)/personal-record")
            return .success(record)
        } catch {
            return .failure(.init(message: handle(error)))
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
