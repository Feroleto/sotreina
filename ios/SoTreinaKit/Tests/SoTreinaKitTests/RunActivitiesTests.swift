import Foundation
import Testing
@testable import SoTreinaKit

/// Ports of `client/src/features/dashboard/bins.ts`, `DateRangePicker`'s
/// presets and `client/src/lib/activityFormat.ts` (Corrida › Atividades).
private let calendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
    return c
}()

/// local wall-clock time in São Paulo
private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

private func run(_ id: String, _ start: Date, km: Double?, sec: Int, pace: Double? = nil) -> ActivityListItem {
    ActivityListItem(
        id: id, name: "Run \(id)", type: "Run", workoutType: "EASY_OR_LONG", startDate: start,
        distanceKm: km, movingTimeSec: sec, paceRawSecKm: pace,
        elevationGainM: nil, averageBpm: nil, maxBpm: nil, averageCadence: nil
    )
}

@Suite struct RunActivitiesDecodingTests {
    @Test func decodesTheActivitiesPage() throws {
        let url = try #require(Bundle.module.url(forResource: "activities", withExtension: "json", subdirectory: "Fixtures"))
        let page = try APICoding.makeDecoder().decode(ActivitiesPage.self, from: Data(contentsOf: url))
        #expect(page.items.count == 2)
        #expect(page.total == 271)
        let first = page.items[0]
        #expect(first.name == "Night Run")
        #expect(first.workoutType == "EASY_OR_LONG")
        #expect(first.movingTimeSec == 1624)
        #expect(first.distanceKm.map { abs($0 - 4.2582) < 0.0001 } == true)
        #expect(first.averageCadence == 165.6)
    }
}

@Suite struct RunBinsTests {
    @Test func weeksStartOnMondayAtLocalMidnight() {
        // Sunday 2026-10-25 23:30 local belongs to the week of Monday the 19th
        let start = RunBins.startOfWeek(date(2026, 10, 25, 23, 30), calendar: calendar)
        #expect(start == date(2026, 10, 19, 0))
        #expect(RunBins.startOfWeek(date(2026, 10, 19, 0), calendar: calendar) == date(2026, 10, 19, 0))
        #expect(RunBins.endOfWeek(start, calendar: calendar) == date(2026, 10, 25, 0))
    }

    @Test func lastWeeksAreZeroFilledAndAscending() {
        let now = date(2026, 10, 23) // a Friday
        let runs = [
            run("a", date(2026, 10, 20), km: 5, sec: 1500),
            run("b", date(2026, 10, 22), km: 8, sec: 2400),
            run("c", date(2026, 10, 6), km: 10, sec: 3000),
            run("old", date(2026, 9, 1), km: 99, sec: 1), // before the window
        ]
        let weeks = RunBins.lastWeeks(runs, count: 3, now: now, calendar: calendar)
        #expect(weeks.map(\.start) == [date(2026, 10, 5, 0), date(2026, 10, 12, 0), date(2026, 10, 19, 0)])
        #expect(weeks.map(\.km) == [10, 0, 13])
        #expect(weeks.map(\.count) == [1, 0, 2])
        #expect(weeks[2].sec == 3900)
    }

    @Test func aRunWithoutDistanceCountsButAddsNoKm() {
        let weeks = RunBins.lastWeeks([run("t", date(2026, 10, 20), km: nil, sec: 600)], count: 1, now: date(2026, 10, 23), calendar: calendar)
        #expect(weeks[0].count == 1)
        #expect(weeks[0].km == 0)
    }

    /// The list: newest week first, empty weeks dropped, 4 more per tap
    @Test func listGroupsPageFourWeeksAtATime() {
        let now = date(2026, 10, 23)
        let runs = (0..<6).map { run("\($0)", calendar.date(byAdding: .day, value: -7 * $0, to: now)!, km: 5, sec: 1500) }
        let weeks = RunBins.lastWeeks(runs, count: 12, now: now, calendar: calendar)
        let page1 = RunBins.listGroups(weeks, pages: 1)
        #expect(page1.shown.count == 4)
        #expect(page1.shown.first?.start == date(2026, 10, 19, 0))
        #expect(page1.olderWeeks == 2)
        let page2 = RunBins.listGroups(weeks, pages: 2)
        #expect(page2.shown.count == 6)
        #expect(page2.olderWeeks == 0)
    }

    /// The hero's bar: this week against last week, nil without last week
    @Test func progressAgainstLastWeek() {
        #expect(RunBins.percentOfLastWeek(thisKm: 15, lastKm: 20) == 75)
        #expect(RunBins.percentOfLastWeek(thisKm: 30, lastKm: 20) == 150)
        #expect(RunBins.percentOfLastWeek(thisKm: 5, lastKm: 0) == nil)
    }

    /// The custom range drives the bars and the list: its weeks, and only
    /// the runs inside the range (end day inclusive)
    @Test func rangeKeepsOnlyRunsInsideIt() {
        let range = DateRange(start: date(2026, 10, 1, 0), end: date(2026, 10, 10, 0))
        let runs = [
            run("in-first", date(2026, 10, 1, 6), km: 5, sec: 1),
            run("in-last", date(2026, 10, 10, 23, 59), km: 5, sec: 1),
            run("before", date(2026, 9, 30, 23), km: 5, sec: 1),
            run("after", date(2026, 10, 11, 0, 1), km: 5, sec: 1),
        ]
        let weeks = RunBins.weeks(in: range, runs, calendar: calendar)
        // 2026-10-01 is a Thursday: weeks of Sep 28 and Oct 5
        #expect(weeks.map(\.start) == [date(2026, 9, 28, 0), date(2026, 10, 5, 0)])
        #expect(weeks.flatMap(\.runs).map(\.id).sorted() == ["in-first", "in-last"])
        #expect(RunBins.days(in: range, calendar: calendar) == 10)
    }

    /// `DateRangePicker` with `maxMonths = 3` (mobile): presets longer than
    /// ~3 months are dropped
    @Test func presetsOnMobile() {
        let presets = RunBins.presets(now: date(2026, 10, 23, 15), calendar: calendar, maxMonths: 3)
        #expect(presets.map(\.0) == [.thisMonth, .lastMonth, .last3Months])
        let byKind = Dictionary(uniqueKeysWithValues: presets)
        #expect(byKind[.thisMonth] == DateRange(start: date(2026, 10, 1, 0), end: date(2026, 10, 31, 0)))
        #expect(byKind[.lastMonth] == DateRange(start: date(2026, 9, 1, 0), end: date(2026, 9, 30, 0)))
        #expect(byKind[.last3Months] == DateRange(start: date(2026, 7, 23, 0), end: date(2026, 10, 23, 0)))
        // in January "This year" is short enough to stay
        let january = RunBins.presets(now: date(2026, 1, 20), calendar: calendar, maxMonths: 3).map(\.0)
        #expect(january.contains(.thisYear))
        #expect(!january.contains(.lastYear))
    }

    /// A picked range can't span more than `maxMonths` from its start
    @Test func rangeEndIsCappedAtMaxMonths() {
        let start = date(2026, 1, 15, 0)
        #expect(RunBins.cappedEnd(start: start, end: date(2026, 9, 1, 0), maxMonths: 3, calendar: calendar) == date(2026, 4, 14, 0))
        #expect(RunBins.cappedEnd(start: start, end: date(2026, 2, 1, 0), maxMonths: 3, calendar: calendar) == date(2026, 2, 1, 0))
    }
}

@Suite struct RunFormatTests {
    @Test func distanceHasOneDecimalInTheUserUnit() {
        #expect(RunFormat.distance(12.44, unit: .km, lang: .en) == "12.4")
        #expect(RunFormat.distance(12.44, unit: .km, lang: .pt) == "12,4")
        #expect(RunFormat.distance(0, unit: .km, lang: .pt) == "0,0")
        #expect(RunFormat.distance(10, unit: .mi, lang: .en) == "6.2")
    }

    /// `formatPaceValue`: seconds roll over into the next minute
    @Test func paceValue() {
        #expect(RunFormat.paceValue(312, unit: .km) == "5:12")
        #expect(RunFormat.paceValue(299.6, unit: .km) == "5:00")
        #expect(RunFormat.paceValue(359.7, unit: .km) == "6:00")
        #expect(RunFormat.paceValue(300, unit: .mi) == "8:03")
        #expect(RunFormat.paceValue(nil, unit: .km) == "—")
        #expect(RunFormat.paceValue(0, unit: .km) == "—")
        #expect(RunFormat.pace(312, unit: .km) == "5:12 /km")
        #expect(RunFormat.pace(300, unit: .mi) == "8:03 /mi")
        #expect(RunFormat.pace(nil, unit: .mi) == "—")
    }

    @Test func dayMonthAndMonthNames() {
        #expect(RunFormat.dayMonth(date(2026, 3, 5), calendar: calendar) == "05/03")
        #expect(RunFormat.monthShort(date(2026, 9, 1), lang: .pt, calendar: calendar) == "set")
        #expect(RunFormat.monthShort(date(2026, 9, 1), lang: .en, calendar: calendar) == "Sep")
        #expect(RunFormat.monthLong(date(2026, 10, 1), lang: .pt, calendar: calendar) == "Outubro de 2026")
        #expect(RunFormat.monthLong(date(2026, 10, 1), lang: .en, calendar: calendar) == "October 2026")
    }

    /// `formatRangeLabel`: a whole calendar month reads as the month
    @Test func rangeLabel() {
        let october = DateRange(start: date(2026, 10, 1, 0), end: date(2026, 10, 31, 0))
        #expect(RunFormat.rangeLabel(october, lang: .pt, calendar: calendar) == "Outubro de 2026")
        let custom = DateRange(start: date(2026, 7, 23, 0), end: date(2026, 10, 23, 0))
        #expect(RunFormat.rangeLabel(custom, lang: .pt, calendar: calendar) == "23/07 – 23/10")
    }
}
