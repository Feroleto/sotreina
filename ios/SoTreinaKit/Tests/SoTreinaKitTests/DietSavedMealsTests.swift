import Foundation
import Testing
@testable import SoTreinaKit

// The web has no tests for useSavedMealEditor (a React hook); these pin the
// same rules: dirty-check by order and grams, default portion on add, the
// trimmed request, and the apply key that survives a failure.

private let egg = FoodListItem(
    id: "egg", name: "Ovo", brand: nil, source: "TACO", imageUrl: nil,
    kcal: 146, protein: 13.3, carbs: 0.6, fat: 9.5, fiber: nil, sodium: nil, servingLabel: "unit", servingGrams: 50
)

private let bread = FoodListItem(
    id: "bread", name: "Pão francês", brand: nil, source: "TACO", imageUrl: nil,
    kcal: 300, protein: 8, carbs: 58, fat: 3, fiber: nil, sodium: nil, servingLabel: nil, servingGrams: nil
)

private let loaded = SavedMealDetail(id: "s1", name: "Café de sempre", items: [
    // out of order on purpose: the draft sorts by `order`
    SavedMealItemDetail(id: "i2", quantity: 100, order: 2, food: egg),
    SavedMealItemDetail(id: "i1", quantity: 50, order: 1, food: bread),
])

@Suite struct SavedMealDraftTests {
    @Test func anEmptyNewDraftIsCleanAndCantSave() {
        let draft = SavedMealDraft()
        #expect(!draft.isEdit)
        #expect(!draft.isDirty)
        #expect(!draft.canSave)
    }

    @Test func aNewDraftIsDirtyOnceANameIsTypedOrAFoodAdded() {
        var named = SavedMealDraft()
        named.name = "  "
        #expect(!named.isDirty)
        named.name = "Lanche"
        #expect(named.isDirty)
        #expect(named.canSave)

        var withFood = SavedMealDraft()
        withFood.add(bread)
        #expect(withFood.isDirty)
        #expect(!withFood.canSave)
    }

    @Test func aDraftSeededFromTheCartAsksBeforeClosing() {
        let draft = SavedMealDraft(items: [.init(food: egg, quantity: 100)])
        #expect(draft.isDirty)
    }

    @Test func loadingSortsByOrderAndStartsClean() {
        let draft = SavedMealDraft(meal: loaded)
        #expect(draft.isEdit)
        #expect(draft.name == "Café de sempre")
        #expect(draft.items.map(\.id) == ["i1", "i2"])
        #expect(!draft.isDirty)
    }

    @Test func editingIsDirtyByNameOrGramsAndCleanAgainWhenUndone() {
        var draft = SavedMealDraft(meal: loaded)
        draft.update("i2", quantity: 150)
        #expect(draft.isDirty)
        draft.update("i2", quantity: 100)
        #expect(!draft.isDirty)
        draft.name = "Outro"
        #expect(draft.isDirty)
    }

    @Test func removingAndAddingBackTheSameFoodIsClean() {
        // row identity doesn't count, only foodId and grams in order
        var draft = SavedMealDraft(meal: loaded)
        draft.remove("i2")
        #expect(draft.isDirty)
        draft.add(egg)
        draft.update(draft.items[1].id, quantity: 100)
        #expect(!draft.isDirty)
    }

    @Test func addUsesOneHouseholdMeasureOrTheFlat100g() {
        var draft = SavedMealDraft()
        draft.add(egg)
        draft.add(bread)
        draft.add(egg)
        #expect(draft.items.map(\.quantity) == [50, 100, 50])
        #expect(Set(draft.items.map(\.id)).count == 3)
    }

    @Test func totalsTheKcalOfEveryItem() {
        let draft = SavedMealDraft(meal: loaded)
        // 300 × 0,5 + 146 × 1
        #expect(draft.totalKcal == 296)
    }

    @Test func theRequestTrimsTheNameAndKeepsTheOrder() {
        var draft = SavedMealDraft(meal: loaded)
        draft.name = "  Café  "
        #expect(draft.request == SavedMealWriteRequest(name: "Café", items: [
            .init(foodId: "bread", quantity: 50),
            .init(foodId: "egg", quantity: 100),
        ]))
    }
}

@Suite struct SavedMealApplyTests {
    @Test func theSameKeyComesBackUntilItSucceeds() {
        var keys = SavedMealApplyKeys()
        let first = keys.key(for: "s1")
        #expect(keys.key(for: "s1") == first)
        #expect(keys.key(for: "s2") != first)
        keys.succeeded("s1")
        #expect(keys.key(for: "s1") != first)
    }

    @Test func anEmptySavedMealCantBeApplied() {
        let empty = SavedMealSummary(id: "s", name: "Vazia", itemCount: 0, itemPreview: [], totalKcal: 0)
        #expect(!empty.canApply)
    }

    @Test func encodesTheApplyBody() throws {
        let clientId = UUID(uuidString: "6F1C2B7E-3D4A-4B5C-9E8F-0A1B2C3D4E5F")!
        let body = ApplySavedMealRequest(mealId: "m1", loggedAt: Date(timeIntervalSince1970: 0), clientId: clientId)
        let json = try JSONSerialization.jsonObject(with: APICoding.makeEncoder().encode(body)) as! [String: Any]
        #expect(json["mealId"] as? String == "m1")
        #expect(json["loggedAt"] as? String == "1970-01-01T00:00:00.000Z")
        #expect(json["clientId"] as? String == clientId.uuidString)
    }

    @Test func decodesTheListAndTheDetail() throws {
        // derived by hand from SavedMealsService.list/findById
        let list = """
        [{"id":"s1","name":"Café","itemCount":2,"itemPreview":["Pão","Ovo"],"totalKcal":296.4}]
        """
        let summaries = try APICoding.makeDecoder().decode([SavedMealSummary].self, from: Data(list.utf8))
        #expect(summaries.first?.itemPreview == ["Pão", "Ovo"])

        let detail = """
        {"id":"s1","name":"Café","items":[{"id":"i1","quantity":50,"order":1,"food":{"id":"bread","name":"Pão","brand":null,"source":"TACO","imageUrl":null,"kcal":300,"protein":8,"carbs":58,"fat":3,"fiber":null,"sodium":null,"servingLabel":null,"servingGrams":null}}]}
        """
        let meal = try APICoding.makeDecoder().decode(SavedMealDetail.self, from: Data(detail.utf8))
        #expect(meal.items.first?.food.kcal == 300)
    }
}
