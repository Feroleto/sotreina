import Foundation

// Treino › Visão geral, ported from the web (client/src/features/gym/
// GymOverviewPage.tsx, GymCalendar.tsx, GymPersonalRecordCard.tsx). Same
// local Monday-first weeks as the Histórico (`HistoryBins.weekStart`).

/// `GET /exercises/:id/personal-record`: the heaviest set ever logged for the
/// exercise in a finished workout; an empty body when there's none.
public struct ExercisePersonalRecord: Codable, Equatable, Sendable {
    public var weightKg: Double
    public var reps: Int?
    public var workoutId: String
    public var startedAt: Date
    public var templateName: String?
}

/// The hero: this (partial) week against the one before it. There's no
/// weekly goal here, so last week is what the progress line measures.
public struct GymWeek: Equatable, Sendable {
    /// Monday, local midnight
    public let start: Date
    public let count: Int
    public let lastWeekCount: Int
    public let volumeKg: Double
    public let exercises: Int
    public let durationSec: Int

    /// this week as a share of last week, nil when last week had none
    public var percentOfLastWeek: Int? {
        lastWeekCount > 0 ? Int((Double(count) / Double(lastWeekCount) * 100).rounded()) : nil
    }

    public static func make(_ items: [WorkoutHistoryItem], now: Date = .now, calendar: Calendar = .current) -> GymWeek {
        let start = HistoryBins.weekStart(now, calendar: calendar)
        let end = calendar.date(byAdding: .day, value: 7, to: start)!
        let previous = calendar.date(byAdding: .day, value: -7, to: start)!
        let current = items.filter { $0.startedAt >= start && $0.startedAt < end }
        return GymWeek(
            start: start,
            count: current.count,
            lastWeekCount: items.filter { $0.startedAt >= previous && $0.startedAt < start }.count,
            volumeKg: current.reduce(0) { $0 + $1.volumeKg },
            exercises: current.reduce(0) { $0 + $1.exerciseCount },
            durationSec: current.reduce(0) { $0 + $1.durationSec }
        )
    }
}

/// One month of `GymCalendar`: Monday-first cells, the workouts by day and
/// the month's totals. Navigation bounds are `RunCalendar`'s.
public struct GymCalendarMonth: Equatable, Sendable {
    /// the 1st, local midnight
    public var start: Date
    /// leading nils up to the 1st's weekday, then one local midnight per day
    public var cells: [Date?]
    /// keyed by the day's local midnight, newest first like the input
    public var workoutsByDay: [Date: [WorkoutHistoryItem]]
    public var count: Int
    public var volumeKg: Double

    /// What the line under the grid reads (the web's `footer`).
    public enum Footer: Equatable, Sendable {
        /// one workout that day: its date, routine (nil = free) and volume
        case day(WorkoutHistoryItem)
        /// several that day
        case days(count: Int, volumeKg: Double)
        /// nothing selected: the month's totals
        case month(count: Int, volumeKg: Double)
    }

    public static func make(_ month: Date, items: [WorkoutHistoryItem], calendar: Calendar) -> GymCalendarMonth {
        let start = RunCalendar.monthStart(month, calendar: calendar)
        let days = calendar.range(of: .day, in: .month, for: start)!.count
        let offset = (calendar.component(.weekday, from: start) + 5) % 7 // Monday = 0
        var cells: [Date?] = Array(repeating: nil, count: offset)
        for d in 0..<days { cells.append(calendar.date(byAdding: .day, value: d, to: start)!) }

        var byDay: [Date: [WorkoutHistoryItem]] = [:]
        for item in items where calendar.isDate(item.startedAt, equalTo: start, toGranularity: .month) {
            byDay[calendar.startOfDay(for: item.startedAt), default: []].append(item)
        }
        let inMonth = byDay.values.joined()
        return GymCalendarMonth(
            start: start, cells: cells, workoutsByDay: byDay,
            count: inMonth.count, volumeKg: inMonth.reduce(0) { $0 + $1.volumeKg }
        )
    }

    /// `selectedDay` is a local midnight; a day without workouts reads as
    /// nothing selected.
    public func footer(selectedDay: Date?) -> Footer {
        guard let selectedDay, let list = workoutsByDay[selectedDay], !list.isEmpty else {
            return .month(count: count, volumeKg: volumeKg)
        }
        if list.count == 1 { return .day(list[0]) }
        return .days(count: list.count, volumeKg: list.reduce(0) { $0 + $1.volumeKg })
    }
}
