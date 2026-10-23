import Foundation
import Testing
@testable import SoTreinaKit

// Translated from client/src/features/diet/quantityFormat.test.ts, plus the
// QuantitySheet's input rules and the cart (no web tests for those two).

private let egg = FoodListItem(
    id: "f1", name: "Ovo, de galinha, inteiro, cozido/10minutos", brand: nil, source: "TACO", imageUrl: nil,
    kcal: 146, protein: 13.3, carbs: 0.6, fat: 9.5, fiber: nil, sodium: 140, servingLabel: "unit", servingGrams: 50
)

private let rice = FoodListItem(
    id: "f2", name: "Arroz", brand: nil, source: "TACO", imageUrl: nil,
    kcal: 146, protein: 13.3, carbs: 0.6, fat: 9.5, fiber: nil, sodium: 140, servingLabel: nil, servingGrams: nil
)

private func food(servingLabel: String?, servingGrams: Double?) -> FoodListItem {
    FoodListItem(id: "f3", name: "x", brand: nil, source: "TACO", imageUrl: nil, kcal: 100, protein: 0, carbs: 0, fat: 0, fiber: nil, sodium: nil, servingLabel: servingLabel, servingGrams: servingGrams)
}

/// Stand-in for the strings file: returns the key, so the plural branch shows.
private let key: @Sendable (String) -> String = { $0 }

@Suite struct QuantityFormatTests {
    @Test func hasServingOnlyForAPositiveServingWeight() {
        #expect(Quantity.hasServing(egg))
        #expect(!Quantity.hasServing(rice))
        #expect(!Quantity.hasServing(food(servingLabel: "unit", servingGrams: 0)))
    }

    @Test func defaultsAFoodWithAHouseholdMeasureToExactlyOneOfIt() {
        #expect(Quantity.defaultPortion(egg) == Portion(quantity: 50, enteredAsServing: true))
    }

    @Test func fallsBackToTheFlat100gPortionOtherwise() {
        #expect(Quantity.defaultPortion(rice) == Portion(quantity: 100, enteredAsServing: false))
    }

    @Test func roundTripsWholeServings() {
        #expect(Quantity.servings(fromGrams: 100, servingGrams: 50) == 2)
        #expect(Quantity.grams(fromServings: 2, servingGrams: 50) == 100)
    }

    @Test func handlesHalves() {
        #expect(Quantity.grams(fromServings: 0.5, servingGrams: 25) == 12.5)
        #expect(Quantity.servings(fromGrams: 12.5, servingGrams: 25) == 0.5)
    }

    @Test func roundsANonExactDivisionInsteadOfShowingFloatNoise() {
        #expect(Quantity.servings(fromGrams: 73, servingGrams: 50) == 1.46)
        #expect(Quantity.grams(fromServings: 1.0 / 3, servingGrams: 86) == 28.7)
    }

    @Test func returnsZeroServingsWithoutAUsableServingWeight() {
        #expect(Quantity.servings(fromGrams: 100, servingGrams: 0) == 0)
    }

    @Test func rendersServingsWithTheGramsInParentheses() {
        #expect(Quantity.format(egg, quantity: 100, enteredAsServing: true, lang: .en, resolve: key)
            == "2 diet.quantity.units.unit.other (100 g)")
    }

    @Test func pluralizesByTheCount() {
        #expect(Quantity.format(egg, quantity: 50, enteredAsServing: true, lang: .en, resolve: key)
            == "1 diet.quantity.units.unit.one (50 g)")
    }

    @Test func rendersPlainGramsWhenThePortionWasEnteredInGrams() {
        #expect(Quantity.format(egg, quantity: 73, enteredAsServing: false, lang: .en, resolve: key) == "73 g")
    }

    @Test func rendersPlainGramsForAFoodWithNoHouseholdMeasureEvenIfFlagged() {
        #expect(Quantity.format(rice, quantity: 150, enteredAsServing: true, lang: .en, resolve: key) == "150 g")
    }

    /// The web's `Intl.PluralRules`: in PT "one" covers every count under 2
    /// (0,5 unidade, 1,5 unidade); in EN only exactly 1.
    @Test func usesThePortugueseAndEnglishPluralRules() {
        #expect(Quantity.format(egg, quantity: 25, enteredAsServing: true, lang: .pt, resolve: key)
            == "0,5 diet.quantity.units.unit.one (25 g)")
        #expect(Quantity.format(egg, quantity: 75, enteredAsServing: true, lang: .pt, resolve: key)
            == "1,5 diet.quantity.units.unit.one (75 g)")
        #expect(Quantity.format(egg, quantity: 25, enteredAsServing: true, lang: .en, resolve: key)
            == "0.5 diet.quantity.units.unit.other (25 g)")
    }

    @Test func translatesAKnownSlug() {
        #expect(Quantity.unitLabel("slice", count: 3, lang: .pt, resolve: key) == "diet.quantity.units.slice.other")
    }

    @Test func fallsBackToTheRawSlugForAnUnknownUnit() {
        #expect(Quantity.unitLabel("handful", count: 2, lang: .pt, resolve: key) == "handful")
    }

    @Test func scalesThePer100gValueByThePortion() {
        #expect(Quantity.kcal(egg, quantity: 50) == 73)
        #expect(Quantity.kcal(egg, quantity: 100) == 146)
    }

    /// `Intl.NumberFormat` with at most 2 decimals: trailing zeros go, the
    /// thousands are grouped.
    @Test func formatsNumbersLikeTheWeb() {
        #expect(Quantity.number(2, lang: .pt) == "2")
        #expect(Quantity.number(1.5, lang: .pt) == "1,5")
        #expect(Quantity.number(1.46, lang: .en) == "1.46")
        #expect(Quantity.number(1.456, lang: .en) == "1.46")
        #expect(Quantity.number(1500, lang: .pt) == "1.500")
        #expect(Quantity.number(1250.5, lang: .en) == "1,250.5")
    }
}

@Suite struct QuantityInputTests {
    @Test func opensInServingsWhenTheRowWasEnteredSo() {
        let input = QuantityInput(food: egg, initial: Portion(quantity: 100, enteredAsServing: true))
        #expect(input.mode == .serving)
        #expect(input.raw == "2")
        #expect(input.grams == 100)
    }

    @Test func opensInGramsForAFoodWithoutAServingEvenIfFlagged() {
        let input = QuantityInput(food: rice, initial: Portion(quantity: 150, enteredAsServing: true))
        #expect(input.mode == .grams)
        #expect(input.raw == "150")
    }

    /// "2 unidades" switched to grams lands on 100, not on an empty field.
    @Test func switchingModeCarriesTheWeight() {
        var input = QuantityInput(food: egg, initial: Portion(quantity: 100, enteredAsServing: true))
        input.switchMode(.grams)
        #expect(input.raw == "100")
        input.raw = "75"
        input.switchMode(.serving)
        #expect(input.raw == "1.5")
        #expect(input.grams == 75)
    }

    @Test func acceptsACommaAsTheDecimalSeparator() {
        var input = QuantityInput(food: egg, initial: Quantity.defaultPortion(egg))
        input.raw = "1,5"
        #expect(input.isValid)
        #expect(input.grams == 75)
    }

    @Test func aHalfTypedOrEmptyValueIsInvalid() {
        var input = QuantityInput(food: rice, initial: Quantity.defaultPortion(rice))
        input.raw = ""
        #expect(!input.isValid)
        input.raw = "0"
        #expect(!input.isValid)
        #expect(input.portion == nil)
    }

    @Test func stepsByHalfAServingOrTenGramsNeverBelowOneStep() {
        var serving = QuantityInput(food: egg, initial: Quantity.defaultPortion(egg))
        serving.nudge(up: true)
        #expect(serving.raw == "1.5")
        serving.nudge(up: false)
        serving.nudge(up: false)
        serving.nudge(up: false)
        #expect(serving.raw == "0.5")

        var grams = QuantityInput(food: rice, initial: Quantity.defaultPortion(rice))
        grams.nudge(up: true)
        #expect(grams.raw == "110")
        grams.raw = ""
        grams.nudge(up: true)
        #expect(grams.raw == "10")
    }

    @Test func capsTheGramsAt5000() {
        var input = QuantityInput(food: rice, initial: Quantity.defaultPortion(rice))
        input.raw = "9000"
        #expect(input.grams == 5000)
    }

    @Test func confirmsInGramsWithTheDisplayHint() {
        var input = QuantityInput(food: egg, initial: Quantity.defaultPortion(egg))
        input.raw = "3"
        #expect(input.portion == Portion(quantity: 150, enteredAsServing: true))
        input.switchMode(.grams)
        #expect(input.portion == Portion(quantity: 150, enteredAsServing: false))
    }

    @Test func offersThePresetsOfTheMode() {
        var input = QuantityInput(food: egg, initial: Quantity.defaultPortion(egg))
        #expect(input.presets == [0.5, 1, 2, 3])
        input.switchMode(.grams)
        #expect(input.presets == [30, 50, 100, 150, 200])
        input.pick(150)
        #expect(input.raw == "150")
    }

    @Test func previewsTheMacrosOfThePortion() {
        var input = QuantityInput(food: egg, initial: Quantity.defaultPortion(egg))
        input.raw = "2"
        #expect(input.preview == MacroPreview(kcal: 146, protein: 13, carbs: 1, fat: 10))
    }
}

@Suite struct MealCartTests {
    @Test func addsEachPortionAsItsOwnItemEvenForTheSameFood() {
        var cart = MealCart()
        cart.add(egg, Portion(quantity: 50, enteredAsServing: true))
        cart.add(egg, Portion(quantity: 100, enteredAsServing: true))
        #expect(cart.items.count == 2)
        #expect(cart.items[0].clientId != cart.items[1].clientId)
        #expect(cart.contains(foodId: egg.id))
    }

    @Test func updatesOneItemsPortion() {
        var cart = MealCart()
        cart.add(egg, Portion(quantity: 50, enteredAsServing: true))
        let id = cart.items[0].clientId
        cart.update(id, Portion(quantity: 120, enteredAsServing: false))
        #expect(cart.items[0].quantity == 120)
        #expect(!cart.items[0].enteredAsServing)
    }

    /// The ✓ on a search row only knows the food, so it clears every entry of it.
    @Test func removingAFoodDropsEveryEntryOfIt() {
        var cart = MealCart()
        cart.add(egg, Quantity.defaultPortion(egg))
        cart.add(rice, Quantity.defaultPortion(rice))
        cart.add(egg, Quantity.defaultPortion(egg))
        cart.remove(foodId: egg.id)
        #expect(cart.items.map(\.food.id) == [rice.id])
    }

    @Test func totalsTheSavedRegistrosAndTheCart() {
        var cart = MealCart()
        cart.add(egg, Portion(quantity: 50, enteredAsServing: true))
        let saved = FoodLogItem(id: "l1", quantity: 200, enteredAsServing: false, mealId: "m1", loggedAt: .now, food: rice)
        #expect(cart.totalItems(saved: [saved]) == 2)
        #expect(cart.totalKcal(saved: [saved]) == 73 + 292)
    }

    /// A failed item keeps its clientId, so the resend can't duplicate; and
    /// it can't be edited, or the resend would answer with the old amount.
    @Test func aFailedItemKeepsItsClientIdAndIsLocked() {
        var cart = MealCart()
        cart.add(egg, Quantity.defaultPortion(egg))
        let id = cart.items[0].clientId
        cart.setStatus(id, .failed)
        #expect(cart.items[0].clientId == id)
        #expect(!cart.items[0].isEditable)
        cart.update(id, Portion(quantity: 999, enteredAsServing: false))
        #expect(cart.items[0].quantity == 50)
        #expect(cart.hasFailures)
    }

    @Test func aSentItemLeavesTheCart() {
        var cart = MealCart()
        cart.add(egg, Quantity.defaultPortion(egg))
        cart.add(rice, Quantity.defaultPortion(rice))
        cart.remove(cart.items[0].clientId)
        #expect(cart.items.map(\.food.id) == [rice.id])
    }
}

@Suite struct FoodLogRequestTests {
    @Test func encodesTheCreateBodyWithTheClientId() throws {
        let clientId = UUID(uuidString: "6F1C2B7E-3D4A-4B5C-9E8F-0A1B2C3D4E5F")!
        let body = CreateFoodLogRequest(foodId: "f1", quantity: 100, enteredAsServing: true, mealId: "m1",
                                        loggedAt: Date(timeIntervalSince1970: 0), clientId: clientId)
        let json = try JSONSerialization.jsonObject(with: APICoding.makeEncoder().encode(body)) as! [String: Any]
        #expect(json["clientId"] as? String == clientId.uuidString)
        #expect(json["loggedAt"] as? String == "1970-01-01T00:00:00.000Z")
        #expect(json["enteredAsServing"] as? Bool == true)
        #expect(json["mealId"] as? String == "m1")
    }
}

@Suite struct DietDayShortTests {
    @Test func writesTheDayAndMonthPerLanguage() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 12))!
        #expect(DietFormat.dayShort(date, lang: .pt, calendar: calendar) == "23 de outubro")
        #expect(DietFormat.dayShort(date, lang: .en, calendar: calendar) == "October 23")
    }
}
