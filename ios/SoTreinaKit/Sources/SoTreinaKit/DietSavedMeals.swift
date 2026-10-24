import Foundation

// Refeições salvas, ported from the web (client/src/features/diet/
// useSavedMealEditor.ts, SavedMealsListPage.tsx, SavedMealEditPage.tsx): a
// named list of foods and grams, built in memory and sent in one call on
// Salvar, and applied to a meal of the day in one call (`POST
// /saved-meals/:id/apply`), which writes one Registro per item.

// MARK: - API models

/// A row of `GET /saved-meals` (most recently updated first).
public struct SavedMealSummary: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let itemCount: Int
    /// the first three food names
    public let itemPreview: [String]
    public let totalKcal: Double

    public init(id: String, name: String, itemCount: Int, itemPreview: [String], totalKcal: Double) {
        self.id = id
        self.name = name
        self.itemCount = itemCount
        self.itemPreview = itemPreview
        self.totalKcal = totalKcal
    }

    /// "Usar" needs something to write: the server refuses an empty one.
    public var canApply: Bool { itemCount > 0 }
}

/// One food of `GET /saved-meals/:id`. Grams only: a saved meal has no
/// unit column, so the sheet is just a way of typing them.
public struct SavedMealItemDetail: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let quantity: Double
    public let order: Int
    public let food: FoodListItem

    public init(id: String, quantity: Double, order: Int, food: FoodListItem) {
        self.id = id
        self.quantity = quantity
        self.order = order
        self.food = food
    }
}

/// `GET /saved-meals/:id`, and the answer of `POST`/`PATCH`.
public struct SavedMealDetail: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let items: [SavedMealItemDetail]

    public init(id: String, name: String, items: [SavedMealItemDetail]) {
        self.id = id
        self.name = name
        self.items = items
    }
}

/// `POST /saved-meals` and `PATCH /saved-meals/:id`: the name and the whole
/// list, which the server replaces wholesale (`order` from the position).
public struct SavedMealWriteRequest: Encodable, Equatable, Sendable {
    public struct Item: Encodable, Equatable, Sendable {
        public let foodId: String
        /// grams
        public let quantity: Double
    }

    public let name: String
    public let items: [Item]
}

/// `POST /saved-meals/:id/apply`. `clientId` makes a resend after a lost
/// response answer with the Registros already written instead of a second
/// copy of the whole saved meal.
public struct ApplySavedMealRequest: Encodable, Equatable, Sendable {
    public let mealId: String
    public let loggedAt: Date
    public let clientId: UUID

    public init(mealId: String, loggedAt: Date, clientId: UUID) {
        self.mealId = mealId
        self.loggedAt = loggedAt
        self.clientId = clientId
    }
}

// MARK: - The editor

/// "Nova refeição salva" / "Editar refeição salva" (`useSavedMealEditor`).
public struct SavedMealDraft: Equatable, Sendable {
    /// `id` only tells rows apart on screen (the server row id when loaded,
    /// a fresh one when added); the request carries foodId and grams.
    public struct Item: Equatable, Sendable, Identifiable {
        public let id: String
        public let food: FoodListItem
        /// grams
        public var quantity: Double

        public init(id: String = UUID().uuidString, food: FoodListItem, quantity: Double) {
            self.id = id
            self.food = food
            self.quantity = quantity
        }
    }

    public var name: String
    public private(set) var items: [Item]
    /// the meal as loaded, to compare against; nil when creating
    private let baseline: Baseline?

    private struct Baseline: Equatable, Sendable {
        let name: String
        let signature: [Signature]
    }

    /// The web's `itemsSignature`: order and grams count, row identity doesn't.
    private struct Signature: Equatable, Sendable {
        let foodId: String
        let quantity: Double
    }

    /// "Nova refeição salva", empty or seeded from the cart ("Salvar como
    /// refeição salva"). Seeded items count as changes: closing asks first.
    public init(items: [Item] = []) {
        name = ""
        self.items = items
        baseline = nil
    }

    /// "Editar refeição salva"
    public init(meal: SavedMealDetail) {
        let loaded = meal.items.sorted { $0.order < $1.order }.map {
            Item(id: $0.id, food: $0.food, quantity: $0.quantity)
        }
        name = meal.name
        items = loaded
        baseline = Baseline(name: meal.name, signature: loaded.map(Self.signature))
    }

    public var isEdit: Bool { baseline != nil }

    /// Creating: anything typed or added. Editing: differs from what loaded.
    public var isDirty: Bool {
        guard let baseline else {
            return !name.trimmingCharacters(in: .whitespaces).isEmpty || !items.isEmpty
        }
        return name != baseline.name || items.map(Self.signature) != baseline.signature
    }

    /// The server requires a name; an empty list is allowed (it just can't
    /// be applied).
    public var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    public var totalKcal: Double {
        items.reduce(0) { $0 + Quantity.kcal($1.food, quantity: $1.quantity) }
    }

    /// The web's "+" on a result: one household measure when the food has
    /// one, the flat 100 g otherwise. The same food may go in twice.
    public mutating func add(_ food: FoodListItem) {
        items.append(Item(food: food, quantity: Quantity.defaultPortion(food).quantity))
    }

    /// grams from the QuantitySheet, whichever mode it was typed in
    public mutating func update(_ id: String, quantity: Double) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].quantity = quantity
    }

    public mutating func remove(_ id: String) {
        items.removeAll { $0.id == id }
    }

    public var request: SavedMealWriteRequest {
        SavedMealWriteRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            items: items.map { .init(foodId: $0.food.id, quantity: $0.quantity) }
        )
    }

    private static func signature(_ item: Item) -> Signature {
        Signature(foodId: item.food.id, quantity: item.quantity)
    }
}

// MARK: - Applying

/// One `clientId` per saved meal while its "Usar" hasn't been confirmed:
/// tapping again after a failure (maybe a timeout after the server wrote)
/// resends the same key and gets the stored Registros back. A success
/// forgets it, so using the same saved meal again later adds it again.
public struct SavedMealApplyKeys: Sendable {
    private var pending: [String: UUID] = [:]

    public init() {}

    public mutating func key(for savedMealId: String) -> UUID {
        if let key = pending[savedMealId] { return key }
        let key = UUID()
        pending[savedMealId] = key
        return key
    }

    public mutating func succeeded(_ savedMealId: String) {
        pending[savedMealId] = nil
    }
}
