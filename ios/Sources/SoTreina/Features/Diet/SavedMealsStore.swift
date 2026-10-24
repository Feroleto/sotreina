import Foundation
import Observation
import os
import SoTreinaDesign
import SoTreinaKit

/// Refeições salvas (the web's `useSavedMeals` plus `useSavedMealEditor`'s
/// calls): the list through the read cache, deleting, loading one into the
/// editor and saving it back in one call. Applying lives on `AddMealStore`,
/// which knows the target meal and shows the Registros it writes.
@MainActor
@Observable
final class SavedMealsStore {
    private(set) var meals: [SavedMealSummary] = []
    private(set) var loadState: WorkoutStore.LoadState = .idle
    /// a failed delete, shown under the list
    var actionError: String?

    let session: SessionStore
    @ObservationIgnored private var restored = false
    @ObservationIgnored private let log = Logger(subsystem: "com.feroleto.sotreina", category: "diet")

    init(session: SessionStore) {
        self.session = session
    }

    func load() async {
        guard let api = session.cachedAPI else { return }
        if !restored {
            restored = true
            if let hit: ResponseCache.Hit<[SavedMealSummary]> = api.cached("saved-meals") {
                meals = hit.value ?? []
                loadState = .loaded
            }
        }
        if loadState != .loaded { loadState = .loading }
        do {
            let fetched: [SavedMealSummary]? = try await api.get("saved-meals")
            meals = fetched ?? []
            loadState = .loaded
        } catch {
            if let message = handle(error), meals.isEmpty { loadState = .failed(message) }
        }
    }

    /// Gone at once, back if the server refuses.
    func remove(_ meal: SavedMealSummary) async {
        guard let index = meals.firstIndex(of: meal) else { return }
        meals.remove(at: index)
        actionError = nil
        do {
            let _: OkBody? = try await session.api.delete("saved-meals/\(meal.id)")
            session.cachedAPI?.store(meals, as: "saved-meals")
        } catch {
            meals.insert(meal, at: min(index, meals.count))
            if let message = handle(error) { actionError = message }
        }
    }

    /// The editor's starting point; not cached, the editor needs it fresh.
    func detail(_ id: String) async -> Result<SavedMealDetail, ActionError> {
        do {
            guard let meal: SavedMealDetail = try await session.api.get("saved-meals/\(id)") else {
                throw APIError.invalidResponse
            }
            return .success(meal)
        } catch {
            return .failure(ActionError(message: handle(error)))
        }
    }

    /// `POST` when new, `PATCH` with the whole list when editing; the list
    /// reloads after, its preview and kcal come from the server.
    func save(_ draft: SavedMealDraft, id: String?) async -> Result<SavedMealDetail, ActionError> {
        do {
            let saved: SavedMealDetail? = if let id {
                try await session.api.patch("saved-meals/\(id)", body: draft.request)
            } else {
                try await session.api.post("saved-meals", body: draft.request)
            }
            guard let saved else { throw APIError.invalidResponse }
            await load()
            return .success(saved)
        } catch {
            return .failure(ActionError(message: handle(error)))
        }
    }

    /// nil message = the session expired, the app is going back to login
    struct ActionError: Error {
        let message: String?
    }

    private func handle(_ error: Error) -> String? {
        if case APIError.unauthorized = error {
            session.expire()
            return nil
        }
        log.error("saved meals request failed: \(String(describing: error), privacy: .public)")
        return WorkoutStore.message(for: error, lang: AppLanguageStore.shared.lang)
    }

    private struct OkBody: Decodable { let ok: Bool }
}
