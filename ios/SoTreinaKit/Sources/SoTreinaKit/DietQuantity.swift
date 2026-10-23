import Foundation

// MARK: - Portion

/// What a Registro sends: grams, plus how the user expressed it.
public struct Portion: Hashable, Sendable {
    /// always grams
    public var quantity: Double
    /// display hint only — never affects the stored macros
    public var enteredAsServing: Bool

    public init(quantity: Double, enteredAsServing: Bool) {
        self.quantity = quantity
        self.enteredAsServing = enteredAsServing
    }
}

/// The web's `quantityFormat.ts`: household measures ("1 unidade" = 50 g)
/// against grams, and how a portion reads on a row.
public enum Quantity {
    /// fallback portion for foods with no known household measure
    public static let defaultPortionGrams: Double = 100

    /// Mirror of `SERVING_UNITS` (server/src/foods/serving-units.ts): the
    /// server sends the slug, the label comes from the strings file.
    public static let servingUnits = ["unit", "slice", "serving", "tablespoon", "teaspoon", "cup", "scoop"]

    public static func hasServing(_ food: FoodListItem) -> Bool {
        (food.servingGrams ?? 0) > 0
    }

    /// One household measure when the food has one (1 ovo, 1 fatia), the flat
    /// 100 g otherwise — what a search row previews and the sheet opens on.
    public static func defaultPortion(_ food: FoodListItem) -> Portion {
        if hasServing(food), let grams = food.servingGrams {
            return Portion(quantity: grams, enteredAsServing: true)
        }
        return Portion(quantity: defaultPortionGrams, enteredAsServing: false)
    }

    /// grams → servings, two decimals for the input field
    public static func servings(fromGrams grams: Double, servingGrams: Double) -> Double {
        guard servingGrams > 0 else { return 0 }
        return round(grams / servingGrams, decimals: 2)
    }

    /// servings → grams, the only direction that reaches the API
    public static func grams(fromServings servings: Double, servingGrams: Double) -> Double {
        round(servings * servingGrams, decimals: 1)
    }

    /// `Math.round(value * 10^d) / 10^d` — the values are never negative
    public static func round(_ value: Double, decimals: Int) -> Double {
        let factor = pow(10, Double(decimals))
        return (value * factor).rounded() / factor
    }

    /// `Intl.NumberFormat` with at most two decimals: "1,5", "2", "1.500".
    public static func number(_ value: Double, lang: Lang) -> String {
        let rounded = Int((value * 100).rounded())
        let whole = DietFormat.integer(rounded / 100, lang: lang)
        var fraction = String(format: "%02d", abs(rounded % 100))
        while fraction.hasSuffix("0") { fraction.removeLast() }
        return fraction.isEmpty ? whole : "\(whole)\(lang == .pt ? "," : ".")\(fraction)"
    }

    public enum PluralCategory: String, Sendable {
        case one
        case other
    }

    /// `Intl.PluralRules`, which the web's i18next uses: in PT "one" is any
    /// count with integer part 0 or 1 (0,5 unidade, 1,5 unidade); in EN only 1.
    public static func plural(_ count: Double, lang: Lang) -> PluralCategory {
        switch lang {
        case .pt: count >= 0 && count < 2 ? .one : .other
        case .en: count == 1 ? .one : .other
        }
    }

    /// The unit's name for a count, via `resolve` (the strings file):
    /// `diet.quantity.units.unit.one`. A slug this build doesn't know shows
    /// as sent instead of blank.
    public static func unitLabel(_ slug: String, count: Double, lang: Lang, resolve: (String) -> String) -> String {
        guard servingUnits.contains(slug) else { return slug }
        return resolve("diet.quantity.units.\(slug).\(plural(count, lang: lang).rawValue)")
    }

    /// A row's subtitle: "2 unidades (100 g)" when entered in servings,
    /// plain "150 g" otherwise.
    public static func format(_ food: FoodListItem, quantity: Double, enteredAsServing: Bool, lang: Lang, resolve: (String) -> String) -> String {
        let grams = "\(number(round(quantity, decimals: 1), lang: lang)) g"
        guard enteredAsServing, hasServing(food), let label = food.servingLabel, let servingGrams = food.servingGrams else {
            return grams
        }
        let servings = servings(fromGrams: quantity, servingGrams: servingGrams)
        return "\(number(servings, lang: lang)) \(unitLabel(label, count: servings, lang: lang, resolve: resolve)) (\(grams))"
    }

    /// every macro on a food is per 100 g
    public static func kcal(_ food: FoodListItem, quantity: Double) -> Double {
        food.kcal * quantity / 100
    }
}

// MARK: - The sheet's input

/// The QuantitySheet's line under the field: kcal and macros of the portion,
/// each rounded.
public struct MacroPreview: Hashable, Sendable {
    public let kcal: Int
    public let protein: Int
    public let carbs: Int
    public let fat: Int
}

/// The web's `QuantitySheet` state: servings or grams, a text field that
/// may hold a half-typed value, −/+ steps, presets and the portion it
/// confirms (always grams).
public struct QuantityInput: Sendable {
    public enum Mode: Sendable {
        case serving
        case grams
    }

    public static let servingPresets: [Double] = [0.5, 1, 2, 3]
    public static let gramPresets: [Double] = [30, 50, 100, 150, 200]
    public static let servingStep = 0.5
    public static let gramStep: Double = 10
    public static let maxGrams: Double = 5000

    public let food: FoodListItem
    public private(set) var mode: Mode
    /// the field's text; a string so "1," or an empty box survives mid-edit
    public var raw: String
    /// how the app writes a value into the field ("," on a PT keypad)
    private let separator: Character

    public init(food: FoodListItem, initial: Portion, separator: Character = ".") {
        self.food = food
        self.separator = separator
        let serving = initial.enteredAsServing && Quantity.hasServing(food)
        mode = serving ? .serving : .grams
        raw = ""
        raw = text(serving ? Quantity.servings(fromGrams: initial.quantity, servingGrams: servingGrams) : initial.quantity)
    }

    public var servingAvailable: Bool { Quantity.hasServing(food) }

    private var servingGrams: Double { food.servingGrams ?? 0 }

    public var value: Double? {
        Double(raw.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

    public var isValid: Bool {
        guard let value else { return false }
        return value.isFinite && value > 0
    }

    /// what the field means in grams, capped at 5 kg
    public var grams: Double {
        guard isValid, let value else { return 0 }
        let grams = mode == .serving
            ? Quantity.grams(fromServings: value, servingGrams: servingGrams)
            : Quantity.round(value, decimals: 1)
        return min(grams, Self.maxGrams)
    }

    /// nil while the field can't be confirmed
    public var portion: Portion? {
        guard isValid, grams > 0 else { return nil }
        return Portion(quantity: grams, enteredAsServing: mode == .serving)
    }

    public var step: Double { mode == .serving ? Self.servingStep : Self.gramStep }

    public var presets: [Double] { mode == .serving ? Self.servingPresets : Self.gramPresets }

    /// The unit's count for its label: the typed value, 1 while invalid.
    public var labelCount: Double { isValid ? value ?? 1 : 1 }

    public var preview: MacroPreview {
        let factor = grams / 100
        return MacroPreview(
            kcal: Int(Quantity.kcal(food, quantity: grams).rounded()),
            protein: Int((food.protein * factor).rounded()),
            carbs: Int((food.carbs * factor).rounded()),
            fat: Int((food.fat * factor).rounded())
        )
    }

    /// One step, never below one step.
    public mutating func nudge(up: Bool) {
        let current = isValid ? value ?? 0 : 0
        raw = text(Quantity.round(max(step, current + (up ? step : -step)), decimals: 2))
    }

    public mutating func pick(_ preset: Double) {
        raw = text(preset)
    }

    /// Carries the current weight across instead of resetting.
    public mutating func switchMode(_ next: Mode) {
        guard next != mode else { return }
        let grams = grams
        raw = text(next == .serving ? Quantity.servings(fromGrams: grams, servingGrams: servingGrams) : grams)
        mode = next
    }

    /// `String(roundTo(value, 2))`: "1.5", "2", "100"
    private func text(_ value: Double) -> String {
        let rounded = Quantity.round(value, decimals: 2)
        var text = rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
        if separator != "." { text = text.replacingOccurrences(of: ".", with: String(separator)) }
        return text
    }
}

// MARK: - The cart

/// Adicionar Registros' local cart (`AddMealPage`): foods staged with their
/// portion until "Salvar refeição", one `POST /food-logs` per item. Each item's
/// `clientId` is its identity and the request's idempotency key.
public struct MealCart: Sendable {
    public enum Status: Sendable, Hashable {
        case staged
        case sending
        /// ⚠: resend with the same clientId
        case failed
    }

    public struct Item: Sendable, Hashable, Identifiable {
        public let clientId: UUID
        public let food: FoodListItem
        public var quantity: Double
        public var enteredAsServing: Bool
        public var status: Status = .staged

        public var id: UUID { clientId }
        public var portion: Portion { Portion(quantity: quantity, enteredAsServing: enteredAsServing) }
        /// Only an item never sent: a failed one may already be on the
        /// server, and a resend answers with the stored amount.
        public var isEditable: Bool { status == .staged }
    }

    public private(set) var items: [Item] = []

    public init() {}

    public var isEmpty: Bool { items.isEmpty }

    public var hasFailures: Bool { items.contains { $0.status == .failed } }

    public func contains(foodId: String) -> Bool {
        items.contains { $0.food.id == foodId }
    }

    public mutating func add(_ food: FoodListItem, _ portion: Portion) {
        items.append(Item(clientId: UUID(), food: food, quantity: portion.quantity, enteredAsServing: portion.enteredAsServing))
    }

    public mutating func update(_ clientId: UUID, _ portion: Portion) {
        guard let index = items.firstIndex(where: { $0.clientId == clientId }), items[index].isEditable else { return }
        items[index].quantity = portion.quantity
        items[index].enteredAsServing = portion.enteredAsServing
    }

    public mutating func setStatus(_ clientId: UUID, _ status: Status) {
        guard let index = items.firstIndex(where: { $0.clientId == clientId }) else { return }
        items[index].status = status
    }

    public mutating func remove(_ clientId: UUID) {
        items.removeAll { $0.clientId == clientId }
    }

    /// The ✓ on a search row knows only the food: drops every entry of it.
    public mutating func remove(foodId: String) {
        items.removeAll { $0.food.id == foodId && $0.isEditable }
    }

    public func totalItems(saved: [FoodLogItem]) -> Int {
        saved.count + items.count
    }

    public func totalKcal(saved: [FoodLogItem]) -> Double {
        saved.reduce(0) { $0 + Quantity.kcal($1.food, quantity: $1.quantity) }
            + items.reduce(0) { $0 + Quantity.kcal($1.food, quantity: $1.quantity) }
    }
}
