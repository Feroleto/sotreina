import Foundation
import Testing
@testable import SoTreinaKit

// AddManualFoodPage has no web tests: these pin parsePortionGrams and the
// per-100 g normalization it does inline before POST /foods/custom.

private func filled(portion: String, unit: String? = nil, externalId: String? = nil) -> ManualFoodDraft {
    var draft = ManualFoodDraft(externalId: externalId)
    draft.name = "  Granola caseira "
    draft.portion = portion
    draft.unit = unit
    draft.kcal = "225"
    draft.protein = "5"
    draft.carbs = "30"
    draft.fat = "7,5"
    return draft
}

@Suite struct ManualFoodTests {
    @Test func readsTheLeadingNumberOfThePortion() {
        #expect(ManualFoodDraft.portionGrams("150 g") == 150)
        #expect(ManualFoodDraft.portionGrams("1 fatia de 25g") == 1)
        #expect(ManualFoodDraft.portionGrams("37.5g") == 37.5)
    }

    @Test func readsADecimalComma() {
        #expect(ManualFoodDraft.portionGrams("37,5 g") == 37.5)
    }

    @Test func fallsBackTo100gWithoutAPositiveNumber() {
        #expect(ManualFoodDraft.portionGrams("um pote") == 100)
        #expect(ManualFoodDraft.portionGrams("0 g") == 100)
        #expect(ManualFoodDraft.portionGrams("") == 100)
    }

    @Test func normalizesThePortionsValuesTo100g() throws {
        let request = try #require(filled(portion: "50 g").request)
        #expect(request.name == "Granola caseira")
        #expect(request.kcal == 450)
        #expect(request.protein == 10)
        #expect(request.carbs == 60)
        #expect(request.fat == 15)
        #expect(request.servingLabel == nil)
        #expect(request.servingGrams == nil)
        #expect(request.externalId == nil)
    }

    @Test func aUnitMakesThePortionAHouseholdMeasure() throws {
        let request = try #require(filled(portion: "50 g", unit: "unit").request)
        #expect(request.servingLabel == "unit")
        #expect(request.servingGrams == 50)
    }

    @Test func carriesTheScannedCode() throws {
        let request = try #require(filled(portion: "100 g", externalId: "7891000053508").request)
        #expect(request.externalId == "7891000053508")
    }

    @Test func leavesNilFieldsOutOfTheBody() throws {
        let request = try #require(filled(portion: "100 g").request)
        let json = try #require(String(data: JSONEncoder().encode(request), encoding: .utf8))
        #expect(!json.contains("externalId"))
        #expect(!json.contains("servingLabel"))
        #expect(!json.contains("servingGrams"))
    }

    @Test func needsEveryField() {
        var draft = filled(portion: "100 g")
        #expect(draft.isValid)
        draft.name = "   "
        #expect(!draft.isValid)
        draft = filled(portion: " ")
        #expect(!draft.isValid)
        draft = filled(portion: "100 g")
        draft.fat = ""
        #expect(!draft.isValid)
        #expect(draft.request == nil)
    }

    @Test func rejectsNegativeOrNonNumericMacros() {
        var draft = filled(portion: "100 g")
        draft.kcal = "-1"
        #expect(!draft.isValid)
        draft.kcal = "abc"
        #expect(!draft.isValid)
        draft.kcal = "0"
        #expect(draft.isValid)
    }
}

@Suite struct ProductBarcodeTests {
    @Test func acceptsCodesWhoseCheckDigitHolds() {
        #expect(ProductBarcode.isValid("7891000053508", kind: .ean13))
        #expect(ProductBarcode.isValid("96385074", kind: .ean8))
        #expect(ProductBarcode.isValid("036000291452", kind: .upcA))
        // UPC-A as the scanner may report it
        #expect(ProductBarcode.isValid("0036000291452", kind: .ean13))
    }

    @Test func rejectsAMisreadDigit() {
        #expect(!ProductBarcode.isValid("7891000053509", kind: .ean13))
        #expect(!ProductBarcode.isValid("96385075", kind: .ean8))
        #expect(!ProductBarcode.isValid("036000291453", kind: .upcA))
    }

    @Test func rejectsTheWrongLengthOrNonDigits() {
        #expect(!ProductBarcode.isValid("789100005350", kind: .ean13))
        #expect(!ProductBarcode.isValid("78910000535O8", kind: .ean13))
        #expect(!ProductBarcode.isValid("", kind: .upcE))
    }

    @Test func takesUpcEWithoutItsCheckDigit() {
        #expect(ProductBarcode.isValid("04252614", kind: .upcE))
        #expect(!ProductBarcode.isValid("0425261", kind: .ean8))
    }
}
