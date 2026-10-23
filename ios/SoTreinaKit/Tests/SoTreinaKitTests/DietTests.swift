import Foundation
import Testing
@testable import SoTreinaKit

private func fixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try APICoding.makeDecoder().decode(T.self, from: Data(contentsOf: url))
}

private let saoPaulo: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
    return calendar
}()

private func food(kcal: Double) -> FoodListItem {
    FoodListItem(id: "f", name: "Banana", brand: nil, source: "TACO", imageUrl: nil, kcal: kcal, protein: 1, carbs: 20, fat: 0.1, fiber: nil, sodium: nil, servingLabel: nil, servingGrams: nil)
}

private func log(_ id: String, meal: String, kcal: Double, grams: Double) -> FoodLogItem {
    FoodLogItem(id: id, quantity: grams, enteredAsServing: false, mealId: meal, loggedAt: .now, food: food(kcal: kcal))
}

private func summary(kcal: Double, protein: Double = 0, carbs: Double = 0, fat: Double = 0) -> DailySummary {
    DailySummary(totalKcal: kcal, totalProtein: protein, totalCarbs: carbs, totalFat: fat)
}

private let goal = MeSettings(dailyKcalGoal: 2000, dailyProteinGoal: 150, dailyCarbsGoal: 250, dailyFatGoal: 65)

@Suite struct DietDecodingTests {
    @Test func decodesTheDaysEndpoints() throws {
        let meals = try fixture("meals", as: [Meal].self)
        #expect(meals.map(\.type) == [.breakfast, .lunch, .snack, .dinner, .supper])
        #expect(meals[0].logCount == 2)
        #expect(meals.map(\.order) == [1, 2, 3, 4, 5])

        let logs = try fixture("food-logs", as: [FoodLogItem].self)
        #expect(logs.count == 2)
        #expect(logs[0].mealId == meals[0].id)
        #expect(logs[0].food.servingLabel == "unit")
        #expect(logs[0].food.servingGrams == 60)
        #expect(logs[1].food.fiber == nil)

        let day = try fixture("food-logs-summary", as: DailySummary.self)
        #expect(Int(day.totalKcal.rounded()) == 451)
    }

    /// A name a newer server added must not break the whole list (reorder
    /// needs every id).
    @Test func keepsAMealTypeThisBuildDoesntKnow() throws {
        let json = #"[{"id":"m1","type":"BRUNCH","order":1,"logCount":0}]"#
        let meals = try APICoding.makeDecoder().decode([Meal].self, from: Data(json.utf8))
        #expect(meals[0].type.rawValue == "BRUNCH")
        #expect(!MealType.all.contains(meals[0].type))
    }
}

@Suite struct DietDayTests {
    @Test func sumsEachMealFromTheLogsOnTheClient() throws {
        let meals = try fixture("meals", as: [Meal].self)
        let logs = try fixture("food-logs", as: [FoodLogItem].self)
        let day = DietDay(logs: logs, summary: try fixture("food-logs-summary", as: DailySummary.self), goal: goal)

        #expect(day.itemCount(meals[0].id) == 2)
        // 98.25 × 100/100 + 352.67 × 100/100, rounded once at the end
        #expect(day.kcal(meals[0].id) == 451)
        #expect(day.itemCount(meals[1].id) == 0)
        #expect(day.kcal(meals[1].id) == 0)
    }

    @Test func roundsTheMealSumNotEachLog() {
        let day = DietDay(logs: [log("a", meal: "m", kcal: 100, grams: 50.4), log("b", meal: "m", kcal: 100, grams: 50.4)], summary: summary(kcal: 100.8), goal: goal)
        #expect(day.kcal("m") == 101)
    }

    @Test func underTheGoal() {
        let day = DietDay(logs: [], summary: summary(kcal: 1234.4), goal: goal)
        #expect(!day.overGoal)
        #expect(day.remainingKcal == 766)
        #expect(day.percent == 62)
        #expect(day.fraction == 1234.4 / 2000)
    }

    /// Strict `value > goal`, like the web: exactly at the goal is not over.
    @Test func exactlyAtTheGoalIsNotOver() {
        let day = DietDay(logs: [], summary: summary(kcal: 2000), goal: goal)
        #expect(!day.overGoal)
        #expect(day.remainingKcal == 0)
        #expect(day.percent == 100)
    }

    /// Over by a fraction already counts (the remaining would round to 0).
    @Test func overTheGoalRoundsTheExcessUp() {
        let day = DietDay(logs: [], summary: summary(kcal: 2000.3), goal: goal)
        #expect(day.overGoal)
        #expect(day.overByKcal == 1)
        #expect(day.percent == 100)
        #expect(day.fraction > 1)
    }

    @Test func withoutASummaryTheDayIsEmpty() {
        let day = DietDay(logs: [], summary: nil, goal: nil)
        #expect(day.totalKcal == 0)
        #expect(day.kcalGoal == 2000)
        #expect(day.percent == 0)
        #expect(day.macros.map(\.goal) == [150, 250, 65])
    }

    @Test func macrosCapTheirBarAtTheGoal() {
        let day = DietDay(logs: [], summary: summary(kcal: 0, protein: 200, carbs: 125, fat: 0), goal: goal)
        #expect(day.macros.map(\.macro) == [.protein, .carbs, .fat])
        #expect(day.macros[0].fraction == 1)
        #expect(day.macros[1].fraction == 0.5)
        #expect(day.macros[2].fraction == 0)
        // protein 1 → carbs .7 → fat .45 (Redesign 18c)
        #expect(day.macros.map(\.macro.opacity) == [1, 0.7, 0.45])
    }

    @Test func aZeroGoalDoesntDivide() {
        let zero = MeSettings(dailyKcalGoal: 0, dailyProteinGoal: 0, dailyCarbsGoal: 0, dailyFatGoal: 0)
        let day = DietDay(logs: [], summary: summary(kcal: 10, protein: 10), goal: zero)
        #expect(day.percent == 0)
        #expect(day.macros[0].fraction == 0)
    }
}

@Suite struct MealListTests {
    private let ids = ["a", "b", "c"]

    @Test func movesOneMealAndSendsTheWholeList() {
        #expect(MealList.moving(ids, at: 1, by: -1) == ["b", "a", "c"])
        #expect(MealList.moving(ids, at: 1, by: 1) == ["a", "c", "b"])
    }

    @Test func movingPastTheEndsChangesNothing() {
        #expect(MealList.moving(ids, at: 0, by: -1) == ids)
        #expect(MealList.moving(ids, at: 2, by: 1) == ids)
    }

    @Test func theLastMealCantBeDeleted() {
        #expect(!MealList.canDelete(count: 1))
        #expect(MealList.canDelete(count: 2))
    }

    @Test func theListHasACap() {
        #expect(MealList.canAdd(count: 11))
        #expect(!MealList.canAdd(count: MealList.maxMeals))
    }
}

@Suite struct DietFormatTests {
    /// Thursday 2026-10-22 in São Paulo
    private let thursday = saoPaulo.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 23, minute: 30))!

    @Test func dayHeader() {
        #expect(DietFormat.dayHeader(thursday, lang: .pt, calendar: saoPaulo) == "Quinta-feira, 22 de outubro")
        #expect(DietFormat.dayHeader(thursday, lang: .en, calendar: saoPaulo) == "Thursday, October 22")
    }

    @Test func localDateIsTheDayInTheUsersTimeZone() {
        // 23:30 in São Paulo is already the 23rd in UTC
        #expect(DietFormat.localDate(thursday, calendar: saoPaulo) == "2026-10-22")
    }

    @Test func groupsThousandsByLanguage() {
        #expect(DietFormat.integer(2000, lang: .pt) == "2.000")
        #expect(DietFormat.integer(2000, lang: .en) == "2,000")
        #expect(DietFormat.integer(451, lang: .pt) == "451")
    }
}
