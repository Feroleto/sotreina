import Foundation

// MARK: - API models

/// The closed vocabulary of meal *names* (`MealType` on the server). Not an
/// enum: a name a newer server adds must decode, or the whole list fails and
/// the reorder (which sends every id) can't be built.
public struct MealType: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let breakfast = MealType(rawValue: "BREAKFAST")
    public static let lunch = MealType(rawValue: "LUNCH")
    public static let snack = MealType(rawValue: "SNACK")
    public static let dinner = MealType(rawValue: "DINNER")
    public static let supper = MealType(rawValue: "SUPPER")

    /// The picker's options, in the web's order (`MEAL_TYPES`).
    public static let all: [MealType] = [.breakfast, .lunch, .snack, .dinner, .supper]
}

/// One slot of the user's day (`GET /meals`), configured once for every
/// date. Two slots may share a name, so a Registro points at `id`.
public struct Meal: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let type: MealType
    public let order: Int
    /// Registros of this meal across every day — the delete confirmation
    public let logCount: Int

    public init(id: String, type: MealType, order: Int, logCount: Int) {
        self.id = id
        self.type = type
        self.order = order
        self.logCount = logCount
    }
}

/// A food as lists return it — always per 100 g.
public struct FoodListItem: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let brand: String?
    /// `TACO` | `OFF` | `CUSTOM`
    public let source: String
    public let imageUrl: String?
    public let kcal: Double
    public let protein: Double
    public let carbs: Double
    public let fat: Double
    public let fiber: Double?
    public let sodium: Double?
    /// closed slug (`unit`, `slice`…), nil for grams-only foods
    public let servingLabel: String?
    public let servingGrams: Double?

    public init(id: String, name: String, brand: String?, source: String, imageUrl: String?, kcal: Double, protein: Double, carbs: Double, fat: Double, fiber: Double?, sodium: Double?, servingLabel: String?, servingGrams: Double?) {
        self.id = id
        self.name = name
        self.brand = brand
        self.source = source
        self.imageUrl = imageUrl
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.sodium = sodium
        self.servingLabel = servingLabel
        self.servingGrams = servingGrams
    }
}

/// A Registro (`GET /food-logs?date=`).
public struct FoodLogItem: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    /// always grams, whatever unit was picked
    public let quantity: Double
    /// display hint: show as servings instead of grams
    public let enteredAsServing: Bool
    public let mealId: String
    public let loggedAt: Date
    public let food: FoodListItem

    public init(id: String, quantity: Double, enteredAsServing: Bool, mealId: String, loggedAt: Date, food: FoodListItem) {
        self.id = id
        self.quantity = quantity
        self.enteredAsServing = enteredAsServing
        self.mealId = mealId
        self.loggedAt = loggedAt
        self.food = food
    }
}

/// `GET /food-logs/summary?date=`
public struct DailySummary: Codable, Hashable, Sendable {
    public let totalKcal: Double
    public let totalProtein: Double
    public let totalCarbs: Double
    public let totalFat: Double

    public init(totalKcal: Double, totalProtein: Double, totalCarbs: Double, totalFat: Double) {
        self.totalKcal = totalKcal
        self.totalProtein = totalProtein
        self.totalCarbs = totalCarbs
        self.totalFat = totalFat
    }
}

// MARK: - The day

/// Dieta › Visão geral's numbers (`DietOverviewPage.tsx`): the day's kcal
/// against the goal, the three macros and each meal's sum — the meals add
/// up the Registros on the client, there's no endpoint per meal.
public struct DietDay: Sendable {
    public enum Macro: Sendable, Hashable {
        case protein
        case carbs
        case fat

        /// one accent, told apart by opacity (Redesign 18c)
        public var opacity: Double {
            switch self {
            case .protein: 1
            case .carbs: 0.7
            case .fat: 0.45
            }
        }
    }

    public struct MacroProgress: Sendable, Hashable {
        public let macro: Macro
        public let grams: Double
        public let goal: Int
        /// the bar, never past full
        public let fraction: Double
    }

    public let totalKcal: Double
    public let kcalGoal: Int
    public let macros: [MacroProgress]
    private let logs: [FoodLogItem]

    /// Without the goal yet, the web's defaults (2000/150/250/65).
    public init(logs: [FoodLogItem], summary: DailySummary?, goal: MeSettings?) {
        let goal = goal ?? MeSettings()
        self.logs = logs
        totalKcal = summary?.totalKcal ?? 0
        kcalGoal = goal.dailyKcalGoal
        macros = [
            Self.progress(.protein, summary?.totalProtein ?? 0, goal.dailyProteinGoal),
            Self.progress(.carbs, summary?.totalCarbs ?? 0, goal.dailyCarbsGoal),
            Self.progress(.fat, summary?.totalFat ?? 0, goal.dailyFatGoal),
        ]
    }

    /// Strict `value > goal`, the same rule as the history's bars — not
    /// `remaining < 0`, whose rounding would disagree right at the goal.
    public var overGoal: Bool { totalKcal > Double(kcalGoal) }

    /// "faltam N"
    public var remainingKcal: Int { Int((Double(kcalGoal) - totalKcal).rounded()) }

    /// "N acima", rounded up: 0.3 over already reads as 1
    public var overByKcal: Int { Int((totalKcal - Double(kcalGoal)).rounded(.up)) }

    public var percent: Int {
        kcalGoal > 0 ? Int((totalKcal / Double(kcalGoal) * 100).rounded()) : 0
    }

    /// The progress line; past 1 it turns `--neg` (`ProgressLine`).
    public var fraction: Double {
        kcalGoal > 0 ? totalKcal / Double(kcalGoal) : 0
    }

    public func itemCount(_ mealId: String) -> Int {
        logs.count { $0.mealId == mealId }
    }

    /// Rounded once, after the sum.
    public func kcal(_ mealId: String) -> Int {
        Int(logs.filter { $0.mealId == mealId }.reduce(0) { $0 + $1.food.kcal * $1.quantity / 100 }.rounded())
    }

    private static func progress(_ macro: Macro, _ grams: Double, _ goal: Int) -> MacroProgress {
        MacroProgress(macro: macro, grams: grams, goal: goal, fraction: goal > 0 ? min(1, grams / Double(goal)) : 0)
    }
}

// MARK: - Editing the meals

/// The rules of the meals' edit mode, mirrored from `MealsService`.
public enum MealList {
    /// `MAX_MEALS` on the server
    public static let maxMeals = 12

    /// The server derives `order` from the array, so moving one meal sends
    /// the whole reordered list of ids (`PUT /meals/order`).
    public static func moving(_ ids: [String], at index: Int, by delta: Int) -> [String] {
        let target = index + delta
        guard ids.indices.contains(index), ids.indices.contains(target) else { return ids }
        var next = ids
        next.insert(next.remove(at: index), at: target)
        return next
    }

    /// The server refuses to delete the last one (an empty day would bring
    /// the defaults back).
    public static func canDelete(count: Int) -> Bool { count > 1 }

    public static func canAdd(count: Int) -> Bool { count < maxMeals }
}

// MARK: - Format

public enum DietFormat {
    /// "Quinta-feira, 22 de outubro" | "Thursday, October 22"
    public static func dayHeader(_ date: Date, lang: Lang, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.weekday, .day, .month], from: date)
        let weekday = c.weekday! - 1
        let month = c.month! - 1
        switch lang {
        case .pt: return "\(RunFormat.weekdaysPt[weekday]), \(c.day!) de \(RunFormat.monthsLongPtLower[month])"
        case .en: return "\(RunFormat.weekdaysEn[weekday]), \(RunFormat.monthsLongEnNames[month]) \(c.day!)"
        }
    }

    /// `?date=` — the day in the user's calendar, "2026-10-22"
    public static func localDate(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    /// "2.000" | "2,000"
    public static func integer(_ value: Int, lang: Lang) -> String {
        let text = String(value.magnitude)
        let grouped = text.enumerated().map { index, digit in
            index > 0 && (text.count - index) % 3 == 0 ? "\(lang == .pt ? "." : ",")\(digit)" : "\(digit)"
        }.joined()
        return value < 0 ? "-\(grouped)" : grouped
    }
}
