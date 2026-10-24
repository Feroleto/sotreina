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
    let search: FoodSearch
    private(set) var saving = false
    /// the saved meal whose "Usar" is in flight
    private(set) var applying: String?
    /// a failed "Usar", shown on the Refeições salvas list
    var applyError: String?
    /// shown under the list, like the web's `text-neg` line
    var error: String?

    private let session: SessionStore
    @ObservationIgnored private var applyKeys = SavedMealApplyKeys()
    @ObservationIgnored private let log = Logger(subsystem: "com.feroleto.sotreina", category: "diet")

    init(meal: Meal, diet: DietStore) {
        self.meal = meal
        session = diet.session
        search = FoodSearch(session: diet.session)
        saved = diet.logs.filter { $0.mealId == meal.id }
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

    // MARK: Refeições salvas

    /// "Usar": one call writes a Registro per item into this meal, and they
    /// join "Nesta refeição". A retry after a failure resends the same
    /// clientId, so a response lost after the write doesn't add it twice.
    func apply(_ savedMeal: SavedMealSummary) async -> Bool {
        guard applying == nil, savedMeal.canApply else { return false }
        applying = savedMeal.id
        applyError = nil
        defer { applying = nil }
        let body = ApplySavedMealRequest(mealId: meal.id, loggedAt: .now, clientId: applyKeys.key(for: savedMeal.id))
        do {
            guard let created: [FoodLogItem] = try await session.api.post("saved-meals/\(savedMeal.id)/apply", body: body) else {
                throw APIError.invalidResponse
            }
            applyKeys.succeeded(savedMeal.id)
            // a resend answers with what's stored: never list a Registro twice
            saved.append(contentsOf: created.filter { entry in !saved.contains { $0.id == entry.id } })
            return true
        } catch {
            if case APIError.unauthorized = error {
                session.expire()
                return false
            }
            log.error("apply failed: \(String(describing: error), privacy: .public)")
            applyError = L10n.string("diet.addMeal.error", lang: AppLanguageStore.shared.lang)
            return false
        }
    }

    /// The staged cart, for "Salvar como refeição salva" (grams only).
    var cartAsSavedMealItems: [SavedMealDraft.Item] {
        cart.items.filter(\.isEditable).map { SavedMealDraft.Item(food: $0.food, quantity: $0.quantity) }
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
