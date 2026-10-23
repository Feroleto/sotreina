import Foundation
import Testing
@testable import SoTreinaKit

/// Corrida › Visão geral: `RunOverviewPage`'s totals, `RunCalendar`,
/// `PersonalRecordsCard` (with `prSnapshot.test.ts` translated) and `ShoesSection`.
private let calendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
    return c
}()

private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
    calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
}

private func run(_ id: String, _ start: Date, km: Double?, sec: Int = 1800) -> ActivityListItem {
    ActivityListItem(
        id: id, name: "Run \(id)", type: "Run", workoutType: "EASY_OR_LONG", startDate: start,
        distanceKm: km, movingTimeSec: sec, paceRawSecKm: nil,
        elevationGainM: nil, averageBpm: nil, maxBpm: nil, averageCadence: nil
    )
}

private func rec(_ name: String, _ rank: Int, _ activityId: String, _ movingTime: Int) -> PersonalBestRecord {
    PersonalBestRecord(name: name, rank: rank, movingTime: movingTime, distance: 5000, startDate: date(2026, 10, 1), activityId: activityId)
}

private func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

@Suite struct RunOverviewDecodingTests {
    @Test func decodesPersonalBests() throws {
        let records = try APICoding.makeDecoder().decode([PersonalBestRecord].self, from: fixture("personal-bests"))
        #expect(records.count == 28)
        let first = records[0]
        #expect(first.name == "10K" && first.rank == 1 && first.movingTime == 2975 && first.prRank == 1)
        // names come in mixed case; the card keys are lowercase
        let byKey = PersonalRecords.byDistance(records)
        #expect(byKey["10k"]?.map(\.rank) == [1, 2, 3])
        #expect(byKey["1/2 mile"] != nil)
        #expect(byKey["marathon"] == nil)
    }

    @Test func decodesGear() throws {
        let gear = try APICoding.makeDecoder().decode([Gear].self, from: fixture("gear"))
        #expect(gear.count == 3)
        #expect(gear[0].modelName == "Novablast 5")
        #expect(gear[0].runCount == 24)
        #expect(gear[0].firstUseDate != nil)
        #expect(Shoes.counts(gear) == (2, 1))
    }
}

@Suite struct RunTotalsTests {
    @Test func noRunsNoTotals() {
        #expect(RunTotals.compute([]) == nil)
    }

    @Test func totalsAndWeeklyAverage() throws {
        let runs = [run("a", date(2026, 10, 1), km: 10, sec: 3000), run("b", date(2026, 10, 8), km: nil, sec: 600), run("c", date(2026, 10, 15), km: 4, sec: 1200)]
        let t = try #require(RunTotals.compute(runs, now: date(2026, 10, 29)))
        #expect(t.count == 3)
        #expect(t.earliest == date(2026, 10, 1))
        #expect(t.totalKm == 14)
        #expect(t.totalSec == 4800)
        #expect(t.kmPerWeek == 3.5) // 14 km over 28 days
        #expect(t.avgPaceSecKm == 4800 / 14.0)
    }

    @Test func aRecentFirstRunStillCountsAsOneWeek() throws {
        let t = try #require(RunTotals.compute([run("a", date(2026, 10, 20), km: 5)], now: date(2026, 10, 22)))
        #expect(t.kmPerWeek == 5)
    }
}

@Suite struct RunCalendarTests {
    @Test func cellsStartOnMonday() {
        // 2026-10-01 is a Thursday: three leading blanks, then 31 days
        let month = RunCalendarMonth.make(date(2026, 10, 23), runs: [], calendar: calendar)
        #expect(month.start == date(2026, 10, 1, 0))
        #expect(month.cells.prefix(3).allSatisfy { $0 == nil })
        #expect(month.cells[3] == date(2026, 10, 1, 0))
        #expect(month.cells.count == 3 + 31)
        // a month starting on Sunday has six blanks
        #expect(RunCalendarMonth.make(date(2026, 11, 5), runs: [], calendar: calendar).cells.prefix(while: { $0 == nil }).count == 6)
    }

    @Test func runsByDayAndMonthTotalsOnlyCountThatMonth() {
        let runs = [
            run("a", date(2026, 10, 5, 7), km: 5),
            run("b", date(2026, 10, 5, 19), km: 3),
            run("c", date(2026, 10, 20), km: nil),
            run("d", date(2026, 9, 30, 23), km: 10), // the night before, in São Paulo
        ]
        let month = RunCalendarMonth.make(date(2026, 10, 1), runs: runs, calendar: calendar)
        #expect(month.runsByDay[date(2026, 10, 5, 0)]?.map(\.id) == ["a", "b"])
        #expect(month.runsByDay[date(2026, 10, 20, 0)]?.count == 1)
        #expect(month.count == 3)
        #expect(month.km == 8)
    }

    @Test func navigationStopsAtTheFirstRunAndTheCurrentMonth() {
        let now = date(2026, 10, 23)
        #expect(!RunCalendar.canGoForward(from: date(2026, 10, 1), now: now, calendar: calendar))
        #expect(RunCalendar.canGoForward(from: date(2026, 9, 1), now: now, calendar: calendar))
        #expect(!RunCalendar.canGoBack(from: date(2023, 7, 1), earliest: date(2023, 7, 20), calendar: calendar))
        #expect(RunCalendar.canGoBack(from: date(2023, 8, 1), earliest: date(2023, 7, 20), calendar: calendar))
        #expect(RunCalendar.canGoBack(from: date(2023, 8, 1), earliest: nil, calendar: calendar))
    }
}

@Suite struct PersonalRecordsTests {
    @Test func twelveDistancesInTheWebsOrder() {
        #expect(PersonalRecords.distances.count == 12)
        #expect(PersonalRecords.distances.first?.key == "400m")
        #expect(PersonalRecords.distances.last?.key == "marathon")
        #expect(PersonalRecords.distances.filter { PersonalRecords.headlineKeys.contains($0.key) }.map(\.chip) == ["1K", "5K", "10K"])
    }

    @Test func longestRunIgnoresRunsWithoutDistance() {
        let runs = [run("a", date(2026, 1, 1), km: 21), run("b", date(2026, 2, 1), km: nil), run("c", date(2026, 3, 1), km: 21.5)]
        #expect(PersonalRecords.longestRun(runs)?.id == "c")
        #expect(PersonalRecords.longestRun([run("x", date(2026, 1, 1), km: nil)]) == nil)
    }

    @Test func effortPace() {
        #expect(rec("5k", 1, "a", 1300).paceSecKm == 260)
    }
}

@Suite struct PrSnapshotTests {
    @Test func keepsOnlyRankOnePerDistanceKeyedByLowercasedName() {
        #expect(PrSnapshot.topIdentities([rec("5k", 1, "a1", 1300), rec("5k", 2, "a2", 1320), rec("10K", 1, "a3", 2900)])
            == ["5k": "a1:1300", "10k": "a3:2900"])
    }

    @Test func celebratesNothingOnTheFirstVisit() {
        #expect(PrSnapshot.newKeys(previous: nil, next: ["5k": "a1:1300"]).isEmpty)
    }

    @Test func flagsADistanceWhoseTopOneChangedOrAppeared() {
        #expect(PrSnapshot.newKeys(
            previous: ["5k": "a1:1300", "10k": "a3:2900"],
            next: ["5k": "a9:1280", "10k": "a3:2900", "1k": "a4:230"]
        ) == ["5k", "1k"])
    }

    @Test func flagsNothingWhenEveryTopOneIsUnchanged() {
        #expect(PrSnapshot.newKeys(previous: ["5k": "a1:1300"], next: ["5k": "a1:1300"]).isEmpty)
    }

    @Test func storageKeyMatchesTheWebsShape() {
        #expect(PrSnapshot.storageKey(userId: "u1") == "pr-snapshot:u1")
    }
}

@Suite struct ShoesTests {
    private func shoe(_ m: Double, primary: Bool = false, retired: Bool = false, first: Date? = nil, last: Date? = nil) -> Gear {
        Gear(id: "g", name: "Shoe", computedDistanceM: m, runCount: 7, firstUseDate: first, lastUseDate: last, primary: primary, retired: retired)
    }

    @Test func wearIsCappedAndTiered() {
        #expect(Shoes.wear(shoe(400_000)) == 0.5)
        #expect(Shoes.wear(shoe(900_000)) == 1)
        #expect(Shoes.bar(shoe(400_000)) == .normal)
        #expect(Shoes.bar(shoe(690_000)) == .worn) // above 85%
        #expect(Shoes.bar(shoe(690_000, retired: true)) == .muted)
    }

    @Test func badgeAndMeta() {
        #expect(Shoes.badge(shoe(1, primary: true)) == .primary)
        #expect(Shoes.badge(shoe(1, retired: true)) == .retired)
        #expect(Shoes.badge(shoe(1)) == nil)
        let a = date(2025, 5, 1), b = date(2026, 1, 1)
        #expect(Shoes.meta(shoe(1, retired: true, first: a, last: b)) == .dateRange(a, b))
        #expect(Shoes.meta(shoe(1, retired: true, first: a)) == .runsSince(7, a))
        #expect(Shoes.meta(shoe(1)) == .runsOnly(7))
    }
}

@Suite struct RunOverviewFormatTests {
    @Test func longDurationLikeFormatDuration() {
        #expect(RunFormat.durationLong(758_760) == "210h 46m")
        #expect(RunFormat.durationLong(3600 + 5 * 60) == "1h 05m")
        #expect(RunFormat.durationLong(52 * 60) == "52min")
    }

    @Test func hmsShowsHoursOnlyFromOneHour() {
        #expect(RunFormat.hms(1306) == "21:46")
        #expect(RunFormat.hms(4902) == "1:21:42")
        #expect(RunFormat.hms(81) == "1:21")
    }

    @Test func monthDatesInTheWebsOrder() {
        let d = date(2026, 5, 10)
        #expect(RunFormat.monthShortYear(d, lang: .pt, calendar: calendar) == "mai 2026")
        #expect(RunFormat.monthDayYear(d, lang: .pt, calendar: calendar) == "mai 10, 2026")
        #expect(RunFormat.monthDayYear(d, lang: .en, calendar: calendar) == "May 10, 2026")
        #expect(RunFormat.monthDay(d, lang: .en, calendar: calendar) == "May 10")
    }

    @Test func calendarTitleAndMonthName() {
        let d = date(2026, 10, 1)
        #expect(RunFormat.calendarTitle(d, lang: .pt, calendar: calendar) == "outubro de 2026")
        #expect(RunFormat.calendarTitle(d, lang: .en, calendar: calendar) == "October 2026")
        #expect(RunFormat.monthName(d, lang: .pt, calendar: calendar) == "outubro")
        #expect(RunFormat.monthName(d, lang: .en, calendar: calendar) == "October")
        #expect(RunCalendar.weekdayInitials(.pt) == ["S", "T", "Q", "Q", "S", "S", "D"])
    }
}
