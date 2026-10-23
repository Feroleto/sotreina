import Foundation

// MARK: - Manual cadastro

/// The web's `AddManualFoodPage` form: name, a free-text portion ("150 g"),
/// an optional household unit, and kcal/macros **for that portion**. `Food`
/// and `POST /foods/custom` are always per 100 g, so the request normalizes.
public struct ManualFoodDraft: Sendable, Equatable {
    public var name = ""
    public var portion = ""
    /// a `Quantity.servingUnits` slug; nil = grams only
    public var unit: String?
    public var kcal = ""
    public var protein = ""
    public var carbs = ""
    public var fat = ""
    /// the scanned code when reached from a scanner 404: links the food to it,
    /// so the next scan of the same code finds it
    public let externalId: String?

    public init(externalId: String? = nil) {
        self.externalId = externalId
    }

    /// Every field filled, every number ≥ 0 (the web's `required` + `min=0`).
    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !portion.trimmingCharacters(in: .whitespaces).isEmpty
            && [kcal, protein, carbs, fat].allSatisfy { Self.number($0) != nil }
    }

    /// The portion's grams, read from the free-text field.
    public var portionGrams: Double { Self.portionGrams(portion) }

    /// nil while the form can't be sent
    public var request: CreateCustomFoodRequest? {
        guard isValid,
              let kcal = Self.number(kcal), let protein = Self.number(protein),
              let carbs = Self.number(carbs), let fat = Self.number(fat)
        else { return nil }
        let grams = portionGrams
        let factor = 100 / grams
        return CreateCustomFoodRequest(
            name: name.trimmingCharacters(in: .whitespaces),
            kcal: kcal * factor,
            protein: protein * factor,
            carbs: carbs * factor,
            fat: fat * factor,
            externalId: externalId,
            servingLabel: unit,
            servingGrams: unit == nil ? nil : grams
        )
    }

    /// `parsePortionGrams`: the leading number of the portion ("150 g" → 150),
    /// 100 when there's none. Unlike the web it also reads a decimal comma
    /// ("1,5 xícara" → 1.5), which the PT keyboard types.
    public static func portionGrams(_ portion: String) -> Double {
        guard let range = portion.range(of: #"\d+([.,]\d+)?"#, options: .regularExpression),
              let grams = Double(portion[range].replacingOccurrences(of: ",", with: ".")),
              grams.isFinite, grams > 0
        else { return Quantity.defaultPortionGrams }
        return grams
    }

    /// A macro field: "12,5" or "12.5", never negative.
    static func number(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(trimmed), value.isFinite, value >= 0 else { return nil }
        return value
    }
}

/// `POST /foods/custom`, always per 100 g. Nil fields are left out.
public struct CreateCustomFoodRequest: Encodable, Equatable, Sendable {
    public let name: String
    public let kcal: Double
    public let protein: Double
    public let carbs: Double
    public let fat: Double
    public let externalId: String?
    public let servingLabel: String?
    public let servingGrams: Double?
}

// MARK: - Scanned codes

/// What the scanner accepts: a product code (EAN-13, EAN-8, UPC-A, UPC-E)
/// whose check digit holds. The camera reads a frame at a time, and a
/// misread digit would cost a lookup that can only 404.
public enum ProductBarcode {
    public enum Kind: Sendable {
        /// also UPC-A, which the scanner may report as an EAN-13 with a leading 0
        case ean13
        case ean8
        case upcA
        /// compressed: its check digit belongs to the expanded UPC-A
        case upcE
    }

    public static func isValid(_ code: String, kind: Kind) -> Bool {
        let digits = code.compactMap(\.wholeNumberValue)
        guard !digits.isEmpty, digits.count == code.count else { return false }
        switch kind {
        case .ean13: return digits.count == 13 && checkDigitHolds(digits)
        case .ean8: return digits.count == 8 && checkDigitHolds(digits)
        case .upcA: return digits.count == 12 && checkDigitHolds(digits)
        case .upcE: return (6...8).contains(digits.count)
        }
    }

    /// GS1 mod 10: weights 3 and 1 from the right, check digit excluded.
    private static func checkDigitHolds(_ digits: [Int]) -> Bool {
        let body = digits.dropLast().reversed()
        let sum = body.enumerated().reduce(0) { $0 + $1.element * ($1.offset.isMultiple(of: 2) ? 3 : 1) }
        return (10 - sum % 10) % 10 == digits.last
    }
}
