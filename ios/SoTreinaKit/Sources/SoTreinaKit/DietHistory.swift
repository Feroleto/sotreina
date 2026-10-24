import Foundation

// MARK: - API model

/// One day of `GET /food-logs/history?days=7|14`: zero-filled, oldest
/// first, the day already cut at local midnight by `X-Time-Zone`.
public struct DailyHistoryPoint: Codable, Hashable, Sendable, Identifiable {
    /// "2026-10-24", the day in the user's calendar
    public let date: String
    public let totalKcal: Double
    public let totalProtein: Double
    public let totalCarbs: Double
    public let totalFat: Double

    public var id: String { date }

    public init(date: String, totalKcal: Double, totalProtein: Double, totalCarbs: Double, totalFat: Double) {
        self.date = date
        self.totalKcal = totalKcal
        self.totalProtein = totalProtein
        self.totalCarbs = totalCarbs
        self.totalFat = totalFat
    }
}

// MARK: - The chart

/// Dieta › Histórico's rules (`DietHistoryPage.tsx`): the bars' scale, the
/// colour of each day, the date labels and which day is selected.
public enum DietHistory {
    /// the two ranges of the segmented control
    public static let ranges = [7, 14]

    public enum Tone: Sendable, Equatable {
        /// full mustard
        case selected
        /// translucent red: strictly above the goal, as the web
        case over
        /// translucent mustard
        case within
    }

    /// The bars' 100%: the period's biggest day, the goal included so the
    /// dashed goal line always fits, never below 1.
    public static func scaleMax(_ points: [DailyHistoryPoint], kcalGoal: Double) -> Double {
        max(points.map(\.totalKcal).max() ?? 0, kcalGoal, 1)
    }

    /// A bar's height as a fraction of the chart; an empty day keeps a 2% stub.
    public static func barFraction(_ kcal: Double, scaleMax: Double) -> Double {
        max(0.02, kcal / scaleMax)
    }

    public static func goalFraction(kcalGoal: Double, scaleMax: Double) -> Double {
        kcalGoal / scaleMax
    }

    public static func isOver(_ point: DailyHistoryPoint, kcalGoal: Double) -> Bool {
        point.totalKcal > kcalGoal
    }

    public static func tone(_ point: DailyHistoryPoint, selected: String?, kcalGoal: Double) -> Tone {
        if point.date == selected { return .selected }
        return isOver(point, kcalGoal: kcalGoal) ? .over : .within
    }

    /// "24/10" under every bar on 7 days, every other bar on 14.
    public static func label(at index: Int, of point: DailyHistoryPoint, range: Int) -> String? {
        let step = range == 14 ? 2 : 1
        guard index % step == 0 else { return nil }
        return shortDate(point.date)
    }

    /// "2026-10-24" → "24/10"
    public static func shortDate(_ date: String) -> String {
        let parts = date.split(separator: "-")
        guard parts.count == 3 else { return date }
        return "\(parts[2])/\(parts[1])"
    }

    /// The selection survives a reload or a switch of range while its day is
    /// still on screen; otherwise it falls to the last day (today).
    public static func keepSelection(_ current: String?, in points: [DailyHistoryPoint]) -> String? {
        if let current, points.contains(where: { $0.date == current }) { return current }
        return points.last?.date
    }

    /// "2026-10-24" as midnight of that day in `calendar`, for the long label.
    public static func day(_ date: String, calendar: Calendar) -> Date? {
        let parts = date.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// "Sábado, 24 de outubro" | "Saturday, October 24"
    public static func longDate(_ date: String, lang: Lang, calendar: Calendar) -> String {
        guard let day = day(date, calendar: calendar) else { return date }
        return DietFormat.dayHeader(day, lang: lang, calendar: calendar)
    }

    /// "P 120g · C 200g · G 50g" (the web keeps "G" in English too). A
    /// no-break space ties each letter to its value, so a wrap at large type
    /// never leaves a lone "P" at the end of a line.
    public static func macros(_ point: DailyHistoryPoint) -> String {
        "P\u{00A0}\(rounded(point.totalProtein))g · C\u{00A0}\(rounded(point.totalCarbs))g · G\u{00A0}\(rounded(point.totalFat))g"
    }

    /// `Math.round`: halves go up, also below zero
    public static func rounded(_ value: Double) -> Int {
        Int((value + 0.5).rounded(.down))
    }
}
