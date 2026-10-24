import Foundation
import Testing
@testable import SoTreinaKit

private func point(_ date: String, kcal: Double, protein: Double = 0, carbs: Double = 0, fat: Double = 0) -> DailyHistoryPoint {
    DailyHistoryPoint(date: date, totalKcal: kcal, totalProtein: protein, totalCarbs: carbs, totalFat: fat)
}

private let saoPaulo: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
    return calendar
}()

@Suite struct DietHistoryTests {
    @Test func decodesTheHistory() throws {
        let url = try #require(Bundle.module.url(forResource: "food-logs-history", withExtension: "json", subdirectory: "Fixtures"))
        let points = try APICoding.makeDecoder().decode([DailyHistoryPoint].self, from: Data(contentsOf: url))
        #expect(points.count == 7)
        // oldest first, and zero-filled: a week without any Registro still has seven days
        #expect(points.map(\.date) == points.map(\.date).sorted())
        #expect(points.allSatisfy { $0.totalKcal == 0 })
    }

    @Test func theScaleIncludesTheGoal() {
        let points = [point("2026-10-23", kcal: 1500), point("2026-10-24", kcal: 1800)]
        #expect(DietHistory.scaleMax(points, kcalGoal: 2000) == 2000)
        #expect(DietHistory.scaleMax(points + [point("2026-10-25", kcal: 2500)], kcalGoal: 2000) == 2500)
        // never divides by zero
        #expect(DietHistory.scaleMax([point("2026-10-24", kcal: 0)], kcalGoal: 0) == 1)
    }

    @Test func anEmptyDayKeepsAStub() {
        #expect(DietHistory.barFraction(0, scaleMax: 2000) == 0.02)
        #expect(DietHistory.barFraction(1000, scaleMax: 2000) == 0.5)
        #expect(DietHistory.goalFraction(kcalGoal: 2000, scaleMax: 2500) == 0.8)
    }

    @Test func toneIsSelectedThenOverThenWithin() {
        let over = point("2026-10-23", kcal: 2001)
        let atGoal = point("2026-10-24", kcal: 2000)
        #expect(DietHistory.tone(over, selected: "2026-10-23", kcalGoal: 2000) == .selected)
        #expect(DietHistory.tone(over, selected: nil, kcalGoal: 2000) == .over)
        // strictly above, like the web
        #expect(DietHistory.tone(atGoal, selected: nil, kcalGoal: 2000) == .within)
        #expect(!DietHistory.isOver(atGoal, kcalGoal: 2000))
    }

    @Test func labelsEveryBarOn7DaysAndEveryOtherOn14() {
        let p = point("2026-10-04", kcal: 0)
        #expect(DietHistory.label(at: 1, of: p, range: 7) == "04/10")
        #expect(DietHistory.label(at: 0, of: p, range: 14) == "04/10")
        #expect(DietHistory.label(at: 1, of: p, range: 14) == nil)
    }

    @Test func selectionSurvivesWhileItsDayIsOnScreen() {
        let week = (18...24).map { point("2026-10-\($0)", kcal: 0) }
        #expect(DietHistory.keepSelection(nil, in: week) == "2026-10-24")
        #expect(DietHistory.keepSelection("2026-10-20", in: week) == "2026-10-20")
        #expect(DietHistory.keepSelection("2026-10-11", in: week) == "2026-10-24")
        #expect(DietHistory.keepSelection("2026-10-20", in: []) == nil)
    }

    @Test func longDateAndMacros() {
        #expect(DietHistory.longDate("2026-10-24", lang: .pt, calendar: saoPaulo) == "Sábado, 24 de outubro")
        #expect(DietHistory.longDate("2026-10-24", lang: .en, calendar: saoPaulo) == "Saturday, October 24")
        #expect(DietHistory.macros(point("2026-10-24", kcal: 0, protein: 120.5, carbs: 199.4, fat: 0)) == "P\u{00A0}121g · C\u{00A0}199g · G\u{00A0}0g")
    }
}
