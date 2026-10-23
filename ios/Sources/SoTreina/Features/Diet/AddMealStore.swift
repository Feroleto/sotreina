import Foundation
import Observation
import os
import SoTreinaDesign
import SoTreinaKit

/// One meal's "Adicionar" screen (the web's `AddMealPage`): the Registros it
/// already has today, the local cart, and the food search. The cart is sent
/// on "Salvar refeição", one `POST /food-logs` per item, each with its
/// `clientId` — a failed item stays as ⚠ and the next save resends it
/// without duplicating. Saved Registros are edited (`PATCH`, optimistic)
/// and removed (`DELETE`, optimistic) in place.
@MainActor
@Observable
final class AddMealStore {
    let meal: Meal
    private(set) var saved: [FoodLogItem]
    private(set) var cart = MealCart()
    private(set) var results: [FoodListItem] = []
    private(set) var searching = false
    private(set) var saving = false
    /// shown under the list, like the web's `text-neg` line
    var error: String?

    private let session: SessionStore
    @ObservationIgnored private let log = Logger(subsystem: "com.feroleto.sotreina", category: "diet")

    static let searchDebounce: Duration = .milliseconds(250)

    init(meal: Meal, diet: DietStore) {
        self.meal = meal
        session = diet.session
        saved = diet.logs.filter { $0.mealId == meal.id }
    }

    // MARK: Search

    /// Called from `.task(id: query)`: a newer query cancels the sleep.
    func search(_ query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            results = []
            searching = false
            return
        }
        searching = true
        do {
            try await Task.sleep(for: Self.searchDebounce)
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

    // MARK: Cart

    func add(_ food: FoodListItem, _ portion: Portion) {
        cart.add(food, portion)
    }

    func update(_ item: MealCart.Item, _ portion: Portion) {
        cart.update(item.clientId, portion)
    }

    func remove(_ item: MealCart.Item) {
        cart.remove(item.clientId)
    }

    func removeFromCart(foodId: String) {
        cart.remove(foodId: foodId)
    }

    // MARK: Saved Registros

    /// Shows the new amount at once, back if the server refuses.
    func update(_ entry: FoodLogItem, _ portion: Portion) async {
        guard let index = saved.firstIndex(where: { $0.id == entry.id }) else { return }
        saved[index] = entry.with(portion)
        error = nil
        do {
            let updated: FoodLogItem? = try await session.api.patch("food-logs/\(entry.id)", body: UpdateFoodLogRequest(portion))
            if let updated, let current = saved.firstIndex(where: { $0.id == entry.id }) { saved[current] = updated }
        } catch {
            if let current = saved.firstIndex(where: { $0.id == entry.id }) { saved[current] = entry }
            fail(error)
        }
    }

    /// Gone at once, back if the server refuses.
    func remove(_ entry: FoodLogItem) async {
        guard let index = saved.firstIndex(where: { $0.id == entry.id }) else { return }
        saved.remove(at: index)
        error = nil
        do {
            try await session.api.deleteEmpty("food-logs/\(entry.id)")
        } catch {
            saved.insert(entry, at: min(index, saved.count))
            fail(error)
        }
    }

    // MARK: Save

    /// Sends every item not yet on the server, in order. Each success moves
    /// into the saved list; each failure stays as ⚠ with its clientId.
    /// True when nothing is left (the screen goes back).
    func save() async -> Bool {
        guard !saving else { return false }
        guard !cart.isEmpty else { return true }
        saving = true
        error = nil
        let loggedAt = Date.now
        for item in cart.items where item.status != .sending {
            cart.setStatus(item.clientId, .sending)
            let body = CreateFoodLogRequest(
                foodId: item.food.id, quantity: item.quantity, enteredAsServing: item.enteredAsServing,
                mealId: meal.id, loggedAt: loggedAt, clientId: item.clientId
            )
            do {
                guard let created: FoodLogItem = try await session.api.post("food-logs", body: body) else {
                    throw APIError.invalidResponse
                }
                cart.remove(item.clientId)
                saved.append(created)
            } catch {
                cart.setStatus(item.clientId, .failed)
                if case APIError.unauthorized = error {
                    session.expire()
                    break
                }
                log.error("food log failed: \(String(describing: error), privacy: .public)")
            }
        }
        // no reload here: the overview's `.task` refetches the day when it shows again
        saving = false
        if cart.hasFailures {
            error = L10n.string("diet.addMeal.someFailed", lang: AppLanguageStore.shared.lang)
            return false
        }
        return true
    }

    private func fail(_ error: Error) {
        if case APIError.unauthorized = error {
            session.expire()
            return
        }
        log.error("request failed: \(String(describing: error), privacy: .public)")
        self.error = L10n.string("diet.addMeal.error", lang: AppLanguageStore.shared.lang)
    }
}

private extension FoodLogItem {
    func with(_ portion: Portion) -> FoodLogItem {
        FoodLogItem(id: id, quantity: portion.quantity, enteredAsServing: portion.enteredAsServing, mealId: mealId, loggedAt: loggedAt, food: food)
    }
}
