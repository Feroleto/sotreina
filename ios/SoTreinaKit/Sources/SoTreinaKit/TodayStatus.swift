import Foundation

// Hoje, ported from the web (client/src/features/today/todayStatus.ts).
// Every input is a payload another area already fetches, so nothing here
// needs an endpoint of its own. Every day is a local day: runs and workouts
// are bucketed here in the device's calendar, and the diet history arrives
// already cut at local midnight (`X-Time-Zone`).

public enum TodayStatus {
    /// Dieta counts as done once the day reaches 90% of the kcal goal.
    public static let dietDoneRatio = 0.9

    public static func isDietDone(kcal: Double, goal: Int) -> Bool {
        goal > 0 && kcal >= Double(goal) * dietDoneRatio
    }

    /// The web's `pctOf`: 0…100, rounded, 0 without a goal.
    public static func percent(_ value: Double, of goal: Int) -> Int {
        goal > 0 ? min(100, Int((value / Double(goal) * 100).rounded())) : 0
    }

    // MARK: Last 7 days

    public struct Day: Equatable, Sendable {
        /// local "2026-10-21"
        public let date: String
        public let run: Bool
        public let gym: Bool
        public let diet: Bool

        public init(date: String, run: Bool, gym: Bool, diet: Bool) {
            self.date = date
            self.run = run
            self.gym = gym
            self.diet = diet
        }

        public func done(_ area: Area) -> Bool {
            switch area {
            case .run: run
            case .gym: gym
            case .diet: diet
            }
        }
    }

    /// The last `n` local midnights, oldest first, ending today.
    public static func lastNDays(_ now: Date, _ n: Int, calendar: Calendar) -> [Date] {
        let today = calendar.startOfDay(for: now)
        return (0..<n).map { calendar.date(byAdding: .day, value: -(n - 1 - $0), to: today)! }
    }

    public static func buildDays(
        activities: [ActivityListItem], workouts: [WorkoutHistoryItem], dietPoints: [DailyHistoryPoint],
        kcalGoal: Int, now: Date, n: Int = 7, calendar: Calendar
    ) -> [Day] {
        let key = { DietFormat.localDate($0, calendar: calendar) }
        let runDays = Set(activities.map { key($0.startDate) })
        // history-stats only lists finished workouts, so every item counts
        let gymDays = Set(workouts.map { key($0.startedAt) })
        let kcalByDay = Dictionary(dietPoints.map { ($0.date, $0.totalKcal) }, uniquingKeysWith: { a, _ in a })
        return lastNDays(now, n, calendar: calendar).map { day in
            let date = key(day)
            return Day(
                date: date,
                run: runDays.contains(date),
                gym: gymDays.contains(date),
                diet: isDietDone(kcal: kcalByDay[date] ?? 0, goal: kcalGoal)
            )
        }
    }

    /// How many of the user's enabled areas were completed that day.
    public static func countDone(_ day: Day, areas: [Area]) -> Int {
        areas.filter(day.done).count
    }

    // MARK: One area (Redesign 21c)

    public struct DayValue: Equatable, Sendable {
        /// local "2026-10-21"
        public let date: String
        public let value: Double

        public init(date: String, value: Double) {
            self.date = date
            self.value = value
        }
    }

    /// One number per local day for the single-area Hoje: km run, workouts
    /// finished or kcal eaten — the last `n` days, oldest first.
    public static func buildDailyValues(
        area: Area, activities: [ActivityListItem], workouts: [WorkoutHistoryItem],
        dietPoints: [DailyHistoryPoint], now: Date, n: Int = 7, calendar: Calendar
    ) -> [DayValue] {
        var byDay: [String: Double] = [:]
        switch area {
        case .run:
            for a in activities { byDay[DietFormat.localDate(a.startDate, calendar: calendar), default: 0] += a.distanceKm ?? 0 }
        case .gym:
            for w in workouts { byDay[DietFormat.localDate(w.startedAt, calendar: calendar), default: 0] += 1 }
        case .diet:
            for p in dietPoints { byDay[p.date, default: 0] += p.totalKcal }
        }
        return lastNDays(now, n, calendar: calendar).map { day in
            let date = DietFormat.localDate(day, calendar: calendar)
            return DayValue(date: date, value: byDay[date] ?? 0)
        }
    }

    // MARK: Totals

    public struct Totals: Equatable, Sendable {
        /// km run today
        public let runKmToday: Double
        /// km run in the current Monday-start week
        public let runKmWeek: Double
        /// workouts finished today, newest first like the input
        public let workoutsToday: [WorkoutHistoryItem]
        /// workouts finished in the current Monday-start week
        public let workoutsWeek: Int
    }

    public static func buildTotals(
        activities: [ActivityListItem], workouts: [WorkoutHistoryItem], now: Date, calendar: Calendar
    ) -> Totals {
        let weekStart = HistoryBins.weekStart(now, calendar: calendar)
        let isToday = { calendar.isDate($0, inSameDayAs: now) }
        var runKmToday = 0.0
        var runKmWeek = 0.0
        for a in activities {
            let km = a.distanceKm ?? 0
            if isToday(a.startDate) { runKmToday += km }
            if a.startDate >= weekStart { runKmWeek += km }
        }
        return Totals(
            runKmToday: runKmToday,
            runKmWeek: runKmWeek,
            workoutsToday: workouts.filter { isToday($0.startedAt) },
            workoutsWeek: workouts.filter { $0.startedAt >= weekStart }.count
        )
    }

    // MARK: Feed

    public enum FeedItem: Equatable, Sendable, Identifiable {
        case run(id: String, at: Date, name: String, durationSec: Int, distanceKm: Double)
        /// `name` is nil for a free workout (no routine)
        case gym(id: String, at: Date, name: String?, exerciseCount: Int, durationSec: Int)
        /// one meal of today, timestamped by its latest Registro
        case diet(id: String, at: Date, mealType: MealType, itemCount: Int, kcal: Int)

        public var area: Area {
            switch self {
            case .run: .run
            case .gym: .gym
            case .diet: .diet
            }
        }

        public var at: Date {
            switch self {
            case .run(_, let at, _, _, _), .gym(_, let at, _, _, _), .diet(_, let at, _, _, _): at
            }
        }

        public var id: String {
            switch self {
            case .run(let id, _, _, _, _): "run:\(id)"
            case .gym(let id, _, _, _, _): "gym:\(id)"
            case .diet(let id, _, _, _, _): "diet:\(id)"
            }
        }
    }

    /// The most recent entries across the enabled areas, newest first. Diet
    /// only contributes today's meals (one day of Registros is loaded): one
    /// row per meal that has Registros.
    public static func buildFeed(
        activities: [ActivityListItem], workouts: [WorkoutHistoryItem], meals: [Meal], todayLogs: [FoodLogItem],
        areas: [Area] = Area.allCases, limit: Int = 5
    ) -> [FeedItem] {
        var items: [FeedItem] = []
        if areas.contains(.run) {
            items += activities.map {
                .run(id: $0.id, at: $0.startDate, name: $0.name, durationSec: $0.movingTimeSec, distanceKm: $0.distanceKm ?? 0)
            }
        }
        if areas.contains(.gym) {
            items += workouts.map {
                .gym(id: $0.id, at: $0.finishedAt, name: $0.templateName, exerciseCount: $0.exerciseCount, durationSec: $0.durationSec)
            }
        }
        if areas.contains(.diet) {
            for meal in meals {
                let logs = todayLogs.filter { $0.mealId == meal.id }
                guard let latest = logs.map(\.loggedAt).max() else { continue }
                let kcal = logs.reduce(0.0) { $0 + $1.food.kcal * $1.quantity / 100 }
                items.append(.diet(id: meal.id, at: latest, mealType: meal.type, itemCount: logs.count, kcal: Int(kcal.rounded())))
            }
        }
        // stable like the web's sort: equal times keep their input order
        return items.enumerated()
            .sorted { $0.element.at != $1.element.at ? $0.element.at > $1.element.at : $0.offset < $1.offset }
            .prefix(limit)
            .map(\.element)
    }

    /// Whole local calendar days between `date` and `now`: 0 today, 1 yesterday.
    public static func calendarDaysAgo(_ date: Date, now: Date, calendar: Calendar) -> Int {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        return max(0, days)
    }
}
