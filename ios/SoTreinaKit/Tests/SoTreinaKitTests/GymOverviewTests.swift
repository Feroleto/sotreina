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

private func stub(_ startedAt: Date, _ volumeKg: Double, exercises: Int = 4, duration: Int = 3600, template: String? = nil) -> WorkoutHistoryItem {
    WorkoutHistoryItem(
        id: "\(startedAt.timeIntervalSince1970)", startedAt: startedAt, finishedAt: startedAt,
        durationSec: duration, exerciseCount: exercises, volumeKg: volumeKg,
        templateId: template, templateName: template
    )
}

@Suite struct GymWeekTests {
    @Test func sumsTheCurrentWeekAndCountsTheOneBefore() {
        let week = GymWeek.make([
            stub(local(22), 1000, exercises: 5, duration: 3000),
            stub(local(19, hour: 7), 500, exercises: 3, duration: 2000),
            // last week: Monday 12 → Sunday 18
            stub(local(18, hour: 23), 9999),
            stub(local(13), 9999),
            stub(local(12, hour: 1), 9999),
            // two weeks back: neither
            stub(local(11, hour: 23), 9999),
        ], now: now, calendar: saoPaulo)

        #expect(week.start == saoPaulo.startOfDay(for: local(19)))
        #expect(week.count == 2)
        #expect(week.lastWeekCount == 3)
        #expect(week.volumeKg == 1500)
        #expect(week.exercises == 8)
        #expect(week.durationSec == 5000)
        #expect(week.percentOfLastWeek == 67)
    }

    @Test func noPercentWithoutLastWeek() {
        let week = GymWeek.make([stub(local(20), 100)], now: now, calendar: saoPaulo)
        #expect(week.lastWeekCount == 0)
        #expect(week.percentOfLastWeek == nil)
    }

    @Test func percentCanPassAHundred() {
        let week = GymWeek.make([stub(local(20), 1), stub(local(21), 1), stub(local(14), 1)], now: now, calendar: saoPaulo)
        #expect(week.percentOfLastWeek == 200)
    }
}

@Suite struct GymCalendarMonthTests {
    @Test func cellsStartOnMonday() {
        // 2026-10-01 is a Thursday: three empty cells
        let month = GymCalendarMonth.make(local(22), items: [], calendar: saoPaulo)
        #expect(month.start == saoPaulo.startOfDay(for: local(1)))
        #expect(month.cells.prefix(3).allSatisfy { $0 == nil })
        #expect(month.cells[3] == saoPaulo.startOfDay(for: local(1)))
        #expect(month.cells.compactMap { $0 }.count == 31)
    }

    @Test func groupsByLocalDayInsideTheMonthOnly() {
        let items = [
            stub(local(22, hour: 20), 300, template: "A"),
            stub(local(22, hour: 7), 200, template: "B"),
            stub(local(5), 100),
            stub(local(30, month: 9), 9999),
            stub(local(1, month: 11, hour: 1), 9999),
        ]
        let month = GymCalendarMonth.make(local(10), items: items, calendar: saoPaulo)
        #expect(month.count == 3)
        #expect(month.volumeKg == 600)
        #expect(month.workoutsByDay[saoPaulo.startOfDay(for: local(22))]?.map(\.templateId) == ["A", "B"])
    }

    @Test func footerReadsTheSelectedDayOrTheMonth() {
        let items = [stub(local(22, hour: 20), 300, template: "A"), stub(local(22, hour: 7), 200), stub(local(5), 100)]
        let month = GymCalendarMonth.make(local(10), items: items, calendar: saoPaulo)

        #expect(month.footer(selectedDay: nil) == .month(count: 3, volumeKg: 600))
        #expect(month.footer(selectedDay: saoPaulo.startOfDay(for: local(22))) == .days(count: 2, volumeKg: 500))
        #expect(month.footer(selectedDay: saoPaulo.startOfDay(for: local(5))) == .day(items[2]))
        // a day without workouts falls back to the month
        #expect(month.footer(selectedDay: saoPaulo.startOfDay(for: local(6))) == .month(count: 3, volumeKg: 600))
    }
}

@Suite struct ExercisePersonalRecordDecodingTests {
    // derived by hand from ExercisesService.personalRecord (server/src/exercises)
    @Test func decodesAFreeWorkoutRecord() throws {
        let json = #"{"weightKg":82.5,"reps":null,"workoutId":"w1","startedAt":"2026-10-20T10:00:00.000Z","templateName":null}"#
        let record = try APICoding.makeDecoder().decode(ExercisePersonalRecord.self, from: Data(json.utf8))
        #expect(record.weightKg == 82.5)
        #expect(record.reps == nil)
        #expect(record.templateName == nil)
    }
}
