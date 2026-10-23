import Foundation
import Observation
import os
import SoTreinaKit

/// Dieta's data for today: the meals (`GET /meals`, a per-user setting for
/// every date), the day's Registros and their summary (`GET /food-logs` and
/// `/summary?date=`, cut at local midnight by `X-Time-Zone`). Reads go
/// through the cache; every meal mutation answers with the whole list.
@MainActor
@Observable
final class DietStore {
    private(set) var meals: [Meal] = []
    private(set) var logs: [FoodLogItem] = []
    private(set) var summary: DailySummary?
    private(set) var loadState: WorkoutStore.LoadState = .idle
    /// the `?date=` on screen; a load after midnight moves to the new day
    private(set) var date = DietFormat.localDate(.now, calendar: .current)
    /// a failed meal mutation, shown as an alert
    var actionError: String?

    let session: SessionStore
    @ObservationIgnored private var restoredDate: String?
    @ObservationIgnored private let log = Logger(subsystem: "com.feroleto.sotreina", category: "diet")

    init(session: SessionStore) {
        self.session = session
    }

    private func dayQuery(_ date: String) -> [URLQueryItem] { [URLQueryItem(name: "date", value: date)] }

    /// Every time the page shows and on returning to the foreground.
    func load() async {
        guard let api = session.cachedAPI else { return }
        let today = DietFormat.localDate(.now, calendar: .current)
        if restoredDate != today {
            restoredDate = today
            restore(api, date: today)
        }
        date = today
        if loadState != .loaded { loadState = .loading }

        async let fetchedMeals: [Meal]? = api.get("meals")
        async let fetchedLogs: [FoodLogItem]? = api.get("food-logs", query: dayQuery(today))
        async let fetchedSummary: DailySummary? = api.get("food-logs/summary", query: dayQuery(today))
        do {
            let (newMeals, newLogs, newSummary) = try await (fetchedMeals, fetchedLogs, fetchedSummary)
            // a slower load of the previous day must not land on the new one
            guard date == today else { return }
            meals = newMeals ?? []
            logs = newLogs ?? []
            summary = newSummary
            loadState = .loaded
        } catch {
            // keep what's on screen; only an empty first load shows the error
            if let message = handle(error), meals.isEmpty { loadState = .failed(message) }
        }
    }

    /// The cached day at once; a new day starts empty rather than showing yesterday.
    private func restore(_ api: CachedAPI, date: String) {
        if let hit: ResponseCache.Hit<[Meal]> = api.cached("meals") { meals = hit.value ?? [] }
        let cachedLogs: ResponseCache.Hit<[FoodLogItem]>? = api.cached("food-logs", query: dayQuery(date))
        let cachedSummary: ResponseCache.Hit<DailySummary>? = api.cached("food-logs/summary", query: dayQuery(date))
        logs = cachedLogs?.value ?? []
        summary = cachedSummary?.value ?? nil
        if !meals.isEmpty, cachedLogs != nil { loadState = .loaded }
    }

    // MARK: Meals

    func add(_ type: MealType) async {
        await mutate { try await $0.post("meals", body: TypeBody(type: type)) }
    }

    func rename(_ mealId: String, to type: MealType) async {
        await mutate { try await $0.patch("meals/\(mealId)", body: TypeBody(type: type)) }
    }

    /// Moves at once, back if the server refuses.
    func move(at index: Int, by delta: Int) async {
        let ids = MealList.moving(meals.map(\.id), at: index, by: delta)
        guard ids != meals.map(\.id) else { return }
        let previous = meals
        meals = ids.compactMap { id in previous.first { $0.id == id } }
        let ok = await mutate { try await $0.put("meals/order", body: OrderBody(ids: ids)) }
        if !ok { meals = previous }
    }

    /// Deletes the meal and its Registros on every day (cascade), then
    /// refetches the day, whose totals just dropped.
    func remove(_ mealId: String) async {
        guard await mutate({ try await $0.delete("meals/\(mealId)") }) else { return }
        await load()
    }

    @discardableResult
    private func mutate(_ request: (APIClient) async throws -> [Meal]?) async -> Bool {
        do {
            guard let next = try await request(session.api) else { throw APIError.invalidResponse }
            meals = next
            session.cachedAPI?.store(next, as: "meals")
            return true
        } catch {
            if let message = handle(error) { actionError = message }
            return false
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

    private struct TypeBody: Encodable { let type: MealType }
    private struct OrderBody: Encodable { let ids: [String] }
}
