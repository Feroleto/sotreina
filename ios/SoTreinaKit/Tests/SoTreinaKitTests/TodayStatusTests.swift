import Foundation
import Testing
@testable import SoTreinaKit

// Port of client/src/features/today/todayStatus.test.ts.

private let saoPaulo: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
    return calendar
}()

/// Wednesday 2026-10-21, 15:00 local — the week starts Monday the 19th.
private let now = local(21, hour: 15)

private func local(_ day: Int, hour: Int = 9, month: Int = 10) -> Date {
    saoPaulo.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
}

private func run(_ startDate: Date, _ distanceKm: Double) -> ActivityListItem {
    ActivityListItem(
        id: "\(startDate.timeIntervalSince1970)", name: "Run", type: "Run", workoutType: "EASY_OR_LONG",
        startDate: startDate, distanceKm: distanceKm, movingTimeSec: 1800, paceRawSecKm: nil,
        elevationGainM: nil, averageBpm: nil, maxBpm: nil, averageCadence: nil
    )
}

private func workout(_ startedAt: Date, _ templateName: String? = nil) -> WorkoutHistoryItem {
    WorkoutHistoryItem(
        id: "\(startedAt.timeIntervalSince1970)", startedAt: startedAt, finishedAt: startedAt,
        durationSec: 3600, exerciseCount: 6, volumeKg: 5000, templateId: nil, templateName: templateName
    )
}

private func log(_ mealId: String, _ loggedAt: Date, kcalPer100: Double, quantity: Double) -> FoodLogItem {
    FoodLogItem(
        id: "\(mealId)-\(loggedAt.timeIntervalSince1970)-\(quantity)", quantity: quantity, enteredAsServing: false,
        mealId: mealId, loggedAt: loggedAt,
        food: FoodListItem(
            id: "f", name: "Food", brand: nil, source: "TACO", imageUrl: nil, kcal: kcalPer100, protein: 0,
            carbs: 0, fat: 0, fiber: nil, sodium: nil, servingLabel: nil, servingGrams: nil
        )
    )
}

private func point(_ date: String, _ kcal: Double) -> DailyHistoryPoint {
    DailyHistoryPoint(date: date, totalKcal: kcal, totalProtein: 0, totalCarbs: 0, totalFat: 0)
}

@Suite struct TodayDietDoneTests {
    @Test func countsTheDayOnceItReaches90PercentOfTheGoal() {
        #expect(TodayStatus.isDietDone(kcal: 1800, goal: 2000))
        #expect(!TodayStatus.isDietDone(kcal: 1799, goal: 2000))
        #expect(TodayStatus.isDietDone(kcal: 2600, goal: 2000))
    }

    @Test func neverCountsWithAZeroGoal() {
        #expect(!TodayStatus.isDietDone(kcal: 500, goal: 0))
    }
}

@Suite struct TodayPercentTests {
    @Test func roundsAndCapsAtAHundred() {
        #expect(TodayStatus.percent(7.1, of: 20) == 36)
        #expect(TodayStatus.percent(2600, of: 2000) == 100)
        #expect(TodayStatus.percent(5, of: 0) == 0)
    }
}

@Suite struct TodayLastNDaysTests {
    @Test func returnsLocalMidnightsOldestFirstEndingToday() {
        let days = TodayStatus.lastNDays(now, 7, calendar: saoPaulo)
        #expect(days.count == 7)
        #expect(DietFormat.localDate(days[0], calendar: saoPaulo) == "2026-10-15")
        #expect(DietFormat.localDate(days[6], calendar: saoPaulo) == "2026-10-21")
        #expect(days.allSatisfy { saoPaulo.component(.hour, from: $0) == 0 })
    }
}

@Suite struct TodayBuildDaysTests {
    @Test func marksEachAreaPerLocalDay() {
        let days = TodayStatus.buildDays(
            activities: [run(local(21, hour: 7), 7.1), run(local(17), 10)],
            workouts: [workout(local(20, hour: 19))],
            dietPoints: [point("2026-10-21", 1900), point("2026-10-20", 1000)],
            kcalGoal: 2000, now: now, calendar: saoPaulo
        )
        let byDate = Dictionary(uniqueKeysWithValues: days.map { ($0.date, $0) })
        #expect(byDate["2026-10-21"] == .init(date: "2026-10-21", run: true, gym: false, diet: true))
        #expect(byDate["2026-10-20"] == .init(date: "2026-10-20", run: false, gym: true, diet: false))
        #expect(byDate["2026-10-17"]?.run == true)
    }

    @Test func bucketsALateEveningRunIntoItsLocalDayNotTheUTCOne() {
        let days = TodayStatus.buildDays(
            activities: [run(local(20, hour: 23), 5)], workouts: [], dietPoints: [],
            kcalGoal: 2000, now: now, calendar: saoPaulo
        )
        #expect(days.first { $0.date == "2026-10-20" }?.run == true)
        #expect(days.first { $0.date == "2026-10-21" }?.run == false)
    }
}

@Suite struct TodayTotalsTests {
    @Test func sumsTodayAndTheMondayStartWeekSeparately() {
        let totals = TodayStatus.buildTotals(
            activities: [
                run(local(21, hour: 7), 7.1),
                run(local(19), 10),
                // Sunday the 18th belongs to last week
                run(local(18), 20),
            ],
            workouts: [workout(local(21, hour: 6), "Treino A"), workout(local(20)), workout(local(18))],
            now: now, calendar: saoPaulo
        )
        #expect(abs(totals.runKmToday - 7.1) < 0.001)
        #expect(abs(totals.runKmWeek - 17.1) < 0.001)
        #expect(totals.workoutsToday.map(\.templateName) == ["Treino A"])
        #expect(totals.workoutsWeek == 2)
    }
}

@Suite struct TodayFeedTests {
    let meals = [
        Meal(id: "m1", type: .breakfast, order: 1, logCount: 0),
        Meal(id: "m2", type: .lunch, order: 2, logCount: 0),
        Meal(id: "m3", type: .snack, order: 3, logCount: 0),
    ]

    @Test func mergesTheThreeAreasNewestFirstOneRowPerMealWithLogs() {
        let feed = TodayStatus.buildFeed(
            activities: [run(local(21, hour: 7), 7.1)],
            workouts: [workout(local(20, hour: 19), "Treino C")],
            meals: meals,
            todayLogs: [
                log("m1", local(21, hour: 8), kcalPer100: 200, quantity: 100),
                log("m2", local(21, hour: 12), kcalPer100: 150, quantity: 200),
                log("m2", local(21, hour: 13), kcalPer100: 100, quantity: 100),
            ]
        )
        #expect(feed.map(\.area) == [.diet, .diet, .run, .gym])
        #expect(feed[0] == .diet(id: "m2", at: local(21, hour: 13), mealType: .lunch, itemCount: 2, kcal: 400))
    }

    @Test func capsTheList() {
        let feed = TodayStatus.buildFeed(
            activities: (0..<8).map { run(local(10 + $0), 5) }, workouts: [], meals: [], todayLogs: [], limit: 3
        )
        #expect(feed.count == 3)
        #expect(feed[0].at == local(17))
    }

    @Test func dropsTheAreasTheUserTurnedOff() {
        let feed = TodayStatus.buildFeed(
            activities: [run(local(21, hour: 7), 7.1)],
            workouts: [workout(local(20, hour: 19))],
            meals: meals,
            todayLogs: [log("m1", local(21, hour: 8), kcalPer100: 200, quantity: 100)],
            areas: [.run, .gym]
        )
        #expect(feed.map(\.area) == [.run, .gym])
    }
}

@Suite struct TodayCountDoneTests {
    let day = TodayStatus.Day(date: "2026-10-21", run: true, gym: false, diet: true)

    @Test func countsOnlyTheEnabledAreas() {
        #expect(TodayStatus.countDone(day, areas: [.run, .gym, .diet]) == 2)
        #expect(TodayStatus.countDone(day, areas: [.run, .gym]) == 1)
        #expect(TodayStatus.countDone(day, areas: [.gym]) == 0)
    }
}

@Suite struct TodayDailyValuesTests {
    @Test func sumsKmPerLocalDayForCorridaZeroFilledOldestFirst() {
        let days = TodayStatus.buildDailyValues(
            area: .run,
            activities: [run(local(21, hour: 7), 7.1), run(local(21, hour: 18), 2), run(local(17), 16.2)],
            workouts: [], dietPoints: [], now: now, calendar: saoPaulo
        )
        #expect(days.count == 7)
        #expect(days[0].date == "2026-10-15")
        #expect(days[6].date == "2026-10-21")
        #expect(abs(days[6].value - 9.1) < 0.001)
        #expect(days[2] == .init(date: "2026-10-17", value: 16.2))
        #expect(days[1].value == 0)
    }

    @Test func countsWorkoutsPerDayForTreino() {
        let days = TodayStatus.buildDailyValues(
            area: .gym, activities: [], workouts: [workout(local(20, hour: 8)), workout(local(20, hour: 19))],
            dietPoints: [], now: now, calendar: saoPaulo
        )
        #expect(days[5] == .init(date: "2026-10-20", value: 2))
    }

    @Test func readsKcalOffTheDietHistoryForDieta() {
        let days = TodayStatus.buildDailyValues(
            area: .diet, activities: [], workouts: [], dietPoints: [point("2026-10-21", 1540)],
            now: now, calendar: saoPaulo
        )
        #expect(days[6].value == 1540)
    }
}

@Suite struct TodayCalendarDaysAgoTests {
    @Test func countsCalendarDaysNot24hSpans() {
        #expect(TodayStatus.calendarDaysAgo(local(21, hour: 1), now: now, calendar: saoPaulo) == 0)
        #expect(TodayStatus.calendarDaysAgo(local(20, hour: 23), now: now, calendar: saoPaulo) == 1)
        #expect(TodayStatus.calendarDaysAgo(local(14), now: now, calendar: saoPaulo) == 7)
    }
}
