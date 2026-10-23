import Foundation

// Treino › Histórico, ported from the web (client/src/features/gym/
// historyBins.ts, GymHistoryPage.tsx, WorkoutDetailPage.tsx,
// ExerciseSessionDetailPage.tsx). Weeks start on Monday in the iPhone's
// time zone, like the web's `startOfBin(…, 'week')`.

/// `GET /workouts/history-stats`: finished workouts of the last 180 days,
/// newest first, with their volume and duration already computed.
public struct WorkoutHistoryItem: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var startedAt: Date
    public var finishedAt: Date
    public var durationSec: Int
    public var exerciseCount: Int
    public var volumeKg: Double
    public var templateId: String?
    public var templateName: String?
}

public enum HistoryBins {
    /// The bar chart and the KPIs look at this many weeks.
    public static let chartWeeks = 12
    /// "Recentes" shows this many week groups, then "+ N semanas anteriores".
    public static let recentWeekGroups = 4

    public struct WeekVolume: Equatable, Sendable {
        public let start: Date
        public let volumeKg: Double
    }

    public struct WeekGroup: Equatable, Sendable {
        public let start: Date
        public var volumeKg: Double
        public var workouts: [WorkoutHistoryItem]
    }

    public struct Summary: Equatable, Sendable {
        public let count: Int
        public let volumeKg: Double
        public let durationSec: Int
        /// workouts per week over the window ("Frequência")
        public let perWeek: Double
    }

    /// Local midnight of the Monday that opens `date`'s week.
    public static func weekStart(_ date: Date, calendar: Calendar = .current) -> Date {
        let day = calendar.startOfDay(for: date)
        // weekday: 1 = Sunday … 7 = Saturday; days back to Monday
        let back = (calendar.component(.weekday, from: day) + 5) % 7
        return calendar.date(byAdding: .day, value: -back, to: day) ?? day
    }

    /// The last `weeks` weeks, oldest first, zero-filled, the current
    /// (partial) week included — the web's `aggregateWeeklyVolume`.
    public static func weeklyVolume(_ items: [WorkoutHistoryItem], weeks: Int, now: Date = .now, calendar: Calendar = .current) -> [WeekVolume] {
        let current = weekStart(now, calendar: calendar)
        return (0..<weeks).reversed().compactMap { back in
            guard let start = calendar.date(byAdding: .day, value: -7 * back, to: current),
                  let end = calendar.date(byAdding: .day, value: 7, to: start) else { return nil }
            let volume = items.filter { $0.startedAt >= start && $0.startedAt < end }.reduce(0) { $0 + $1.volumeKg }
            return WeekVolume(start: start, volumeKg: volume)
        }
    }

    /// Weeks with at least one workout, newest first; `items` already come
    /// newest first, so each group keeps that order (`groupWorkoutsByWeek`).
    public static func groupByWeek(_ items: [WorkoutHistoryItem], calendar: Calendar = .current) -> [WeekGroup] {
        var groups: [WeekGroup] = []
        var indexByStart: [Date: Int] = [:]
        for item in items {
            let start = weekStart(item.startedAt, calendar: calendar)
            if let index = indexByStart[start] {
                groups[index].volumeKg += item.volumeKg
                groups[index].workouts.append(item)
            } else {
                indexByStart[start] = groups.count
                groups.append(WeekGroup(start: start, volumeKg: item.volumeKg, workouts: [item]))
            }
        }
        return groups.sorted { $0.start > $1.start }
    }

    /// The KPIs: workouts, volume and time inside the chart's window.
    public static func summary(_ items: [WorkoutHistoryItem], weeks: Int, now: Date = .now, calendar: Calendar = .current) -> Summary {
        let windowStart = weeklyVolume([], weeks: weeks, now: now, calendar: calendar).first?.start ?? now
        let inWindow = items.filter { $0.startedAt >= windowStart }
        return Summary(
            count: inWindow.count,
            volumeKg: inWindow.reduce(0) { $0 + $1.volumeKg },
            durationSec: inWindow.reduce(0) { $0 + $1.durationSec },
            perWeek: Double(inWindow.count) / Double(max(1, weeks))
        )
    }

    /// One dot color per routine, in first-seen order, cycling through
    /// `routineDotCount` colors (`ROUTINE_DOT_COLORS`). A free workout has no
    /// entry: it gets the neutral dot.
    public static let routineDotCount = 4

    public static func routineDots(_ items: [WorkoutHistoryItem]) -> [String: Int] {
        var dots: [String: Int] = [:]
        for item in items {
            guard let id = item.templateId, dots[id] == nil else { continue }
            dots[id] = dots.count % routineDotCount
        }
        return dots
    }
}

/// Numbers of one exercise's sets in a finished workout.
public enum SetStats {
    /// "3 séries · 21,3 kg · 8 reps": averages over the sets that have the
    /// value (weight to one decimal, reps whole).
    public static func averages(_ sets: [WorkoutSet]) -> (weightKg: Double?, reps: Int?) {
        let weights = sets.compactMap(\.weightKg)
        let reps = sets.compactMap(\.reps)
        return (
            weights.isEmpty ? nil : roundOne(weights.reduce(0, +) / Double(weights.count)),
            reps.isEmpty ? nil : Int((Double(reps.reduce(0, +)) / Double(reps.count)).rounded())
        )
    }

    public static func volume(_ set: WorkoutSet) -> Double {
        (set.weightKg ?? 0) * Double(set.reps ?? 0)
    }

    public static func totalVolume(_ sets: [WorkoutSet]) -> Double {
        sets.reduce(0) { $0 + volume($1) }
    }

    /// "Melhor série": the highest volume; the first one on a tie.
    public static func best(_ sets: [WorkoutSet]) -> WorkoutSet? {
        sets.reduce(nil) { best, set in
            guard let best else { return set }
            return volume(set) > volume(best) ? set : best
        }
    }

    /// Epley, to one decimal: weight × (1 + reps / 30).
    public static func epley1RM(weightKg: Double, reps: Int) -> Double {
        roundOne(weightKg * (1 + Double(reps) / 30))
    }

    private static func roundOne(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }
}

extension WorkoutFormat {
    /// "1h 31min", always both parts (the web's `formatTotalDuration`).
    public static func totalDuration(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return "\(s / 3600)h \(Int((Double(s % 3600) / 60).rounded()))min"
    }

    /// "03/07" (the web's `formatDayMonth`, the same in both languages).
    public static func dayMonth(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.day, .month], from: date)
        return String(format: "%02d/%02d", parts.day ?? 0, parts.month ?? 0)
    }

    /// "Quinta-feira, 22 de outubro" / "Thursday, October 22".
    public static func longDate(_ date: Date, lang: Lang, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: lang.localeIdentifier)
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        let text = formatter.string(from: date)
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}
