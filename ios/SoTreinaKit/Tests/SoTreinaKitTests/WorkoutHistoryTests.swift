import Foundation
import Testing
@testable import SoTreinaKit

private let saoPaulo: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
    return calendar
}()

/// Thursday 2026-10-22 15:00 in São Paulo.
private let now = saoPaulo.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 15))!

private func local(_ day: Int, month: Int = 10, hour: Int = 12) -> Date {
    saoPaulo.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
}

private func stub(_ startedAt: Date, _ volumeKg: Double, template: String? = nil) -> WorkoutHistoryItem {
    WorkoutHistoryItem(
        id: "\(startedAt.timeIntervalSince1970)", startedAt: startedAt, finishedAt: startedAt,
        durationSec: 1800, exerciseCount: 1, volumeKg: volumeKg,
        templateId: template, templateName: template
    )
}

private func set(_ number: Int, _ weightKg: Double?, _ reps: Int?) -> WorkoutSet {
    WorkoutSet(id: "s\(number)", setNumber: number, weightKg: weightKg, reps: reps, rpe: nil, setType: "NORMAL", completedAt: now)
}

// The web's historyBins.test.ts, with the clock and the time zone pinned.
@Suite struct HistoryBinsTests {
    @Test func weeksStartOnMondayInLocalTime() {
        let monday = saoPaulo.startOfDay(for: local(19))
        // Monday 00:30 in São Paulo is still Sunday in UTC: it opens the new week
        #expect(HistoryBins.weekStart(monday.addingTimeInterval(1_800), calendar: saoPaulo) == monday)
        // Sunday night closes it
        #expect(HistoryBins.weekStart(local(25, hour: 23), calendar: saoPaulo) == monday)
        #expect(HistoryBins.weekStart(local(26, hour: 1), calendar: saoPaulo) == saoPaulo.startOfDay(for: local(26)))
    }

    @Test func returnsNWeeksAscendingEndingOnTheCurrentWeek() {
        let bins = HistoryBins.weeklyVolume([], weeks: 12, now: now, calendar: saoPaulo)
        #expect(bins.count == 12)
        #expect(bins.last?.start == saoPaulo.startOfDay(for: local(19)))
        for (previous, next) in zip(bins, bins.dropFirst()) {
            #expect(saoPaulo.dateComponents([.day], from: previous.start, to: next.start).day == 7)
        }
    }

    @Test func zeroFillsWeeksWithNoWorkouts() {
        let bins = HistoryBins.weeklyVolume([], weeks: 4, now: now, calendar: saoPaulo)
        #expect(bins.allSatisfy { $0.volumeKg == 0 })
    }

    @Test func bucketsAWorkoutIntoTheWeekOfItsStart() {
        let bins = HistoryBins.weeklyVolume([stub(local(21), 500)], weeks: 4, now: now, calendar: saoPaulo)
        #expect(bins.last?.volumeKg == 500)
        #expect(bins.dropLast().allSatisfy { $0.volumeKg == 0 })
    }

    @Test func sumsVolumeAcrossWorkoutsOfTheSameWeek() {
        let bins = HistoryBins.weeklyVolume([stub(local(19), 200), stub(local(19), 300)], weeks: 1, now: now, calendar: saoPaulo)
        #expect(bins.first?.volumeKg == 500)
    }

    @Test func noGroupsWithoutWorkouts() {
        #expect(HistoryBins.groupByWeek([], calendar: saoPaulo).isEmpty)
    }

    @Test func groupsTheSameWeekAndSumsVolume() {
        let groups = HistoryBins.groupByWeek([stub(local(21), 300), stub(local(19), 200)], calendar: saoPaulo)
        #expect(groups.count == 1)
        #expect(groups[0].start == saoPaulo.startOfDay(for: local(19)))
        #expect(groups[0].volumeKg == 500)
        #expect(groups[0].workouts.count == 2)
    }

    @Test func mostRecentWeekFirstKeepingOrderInside() {
        // arrives desc by startedAt, as the API returns it
        let items = [stub(local(19), 100), stub(local(15), 50), stub(local(12), 25)]
        let groups = HistoryBins.groupByWeek(items, calendar: saoPaulo)
        #expect(groups.map(\.start) == [saoPaulo.startOfDay(for: local(19)), saoPaulo.startOfDay(for: local(12))])
        #expect(groups[1].workouts.map(\.startedAt) == [local(15), local(12)])
    }

    @Test func summaryCountsOnlyTheWindow() {
        let items = [stub(local(21), 500), stub(local(10, month: 1), 9_999)]
        let summary = HistoryBins.summary(items, weeks: 12, now: now, calendar: saoPaulo)
        #expect(summary.count == 1)
        #expect(summary.volumeKg == 500)
        #expect(summary.durationSec == 1800)
        #expect(abs(summary.perWeek - 1.0 / 12) < 0.0001)
    }

    @Test func routineDotsFollowFirstSeenOrderAndCycle() {
        let items = ["a", "b", "a", nil, "c", "d", "e"].map { stub(now, 0, template: $0) }
        let dots = HistoryBins.routineDots(items)
        #expect(dots["a"] == 0)
        #expect(dots["b"] == 1)
        #expect(dots["c"] == 2)
        #expect(dots["d"] == 3)
        #expect(dots["e"] == 0) // four colors, then it cycles
        #expect(dots.count == 5)
    }
}

// ExerciseSessionDetailPage / WorkoutDetailPage.
@Suite struct SetStatsTests {
    @Test func averagesRoundWeightToOneDecimalAndRepsToWhole() {
        let averages = SetStats.averages([set(1, 20, 10), set(2, 22.5, 8), set(3, nil, 7)])
        #expect(averages.weightKg == 21.3)
        #expect(averages.reps == 8)
        #expect(SetStats.averages([set(1, nil, nil)]).weightKg == nil)
        #expect(SetStats.averages([]).reps == nil)
    }

    @Test func bestSetIsTheHighestVolumeAndTheFirstOnATie() {
        // 200, 200, 200: the web's strict ">" keeps the first
        #expect(SetStats.best([set(1, 20, 10), set(2, 25, 8), set(3, 40, 5)])?.setNumber == 1)
        #expect(SetStats.best([set(1, 20, 10), set(2, 30, 8)])?.setNumber == 2)
        #expect(SetStats.best([set(1, 20, 10), set(2, 40, 5)])?.setNumber == 1)
        #expect(SetStats.best([]) == nil)
    }

    @Test func epleyRoundsToOneDecimal() {
        #expect(SetStats.epley1RM(weightKg: 100, reps: 5) == 116.7)
        #expect(SetStats.epley1RM(weightKg: 60, reps: 10) == 80)
    }

    @Test func volumeTreatsMissingValuesAsZero() {
        #expect(SetStats.volume(set(1, 20, 10)) == 200)
        #expect(SetStats.volume(set(1, nil, 10)) == 0)
        #expect(SetStats.totalVolume([set(1, 20, 10), set(2, 25, 4)]) == 300)
    }
}

@Suite struct HistoryFormatTests {
    @Test func totalDurationAlwaysShowsBothParts() {
        #expect(WorkoutFormat.totalDuration(0) == "0h 0min")
        #expect(WorkoutFormat.totalDuration(5_430) == "1h 31min")
    }

    @Test func dayMonthIsTwoDigitDayAndMonth() {
        #expect(WorkoutFormat.dayMonth(local(3, month: 7), calendar: saoPaulo) == "03/07")
    }

    @Test func longDateIsCapitalizedWeekdayDayAndMonth() {
        #expect(WorkoutFormat.longDate(local(22), lang: .pt, timeZone: saoPaulo.timeZone) == "Quinta-feira, 22 de outubro")
        #expect(WorkoutFormat.longDate(local(22), lang: .en, timeZone: saoPaulo.timeZone) == "Thursday, October 22")
    }

    @Test func decodesTheHistoryFixture() throws {
        let url = try #require(Bundle.module.url(forResource: "workouts-history-stats", withExtension: "json", subdirectory: "Fixtures"))
        let items = try APICoding.makeDecoder().decode([WorkoutHistoryItem].self, from: Data(contentsOf: url))
        #expect(items.count == 21)
        #expect(items[0].templateName == "Upper")
        #expect(items[0].volumeKg == 102.05)
        #expect(zip(items, items.dropFirst()).allSatisfy { $0.startedAt >= $1.startedAt })
    }
}
