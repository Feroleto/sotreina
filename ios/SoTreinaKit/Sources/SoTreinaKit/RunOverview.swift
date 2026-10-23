import Foundation

/// One row of `GET /personal-bests`: a top-3 effort for a distance.
public struct PersonalBestRecord: Codable, Hashable, Sendable {
    /// Strava's best-effort name ("5K", "1/2 mile"); case varies, compare lowercased
    public var name: String
    /// 1–3, fastest first (derived on the server)
    public var rank: Int
    public var movingTime: Int
    /// meters, as Strava measured the effort
    public var distance: Double
    public var startDate: Date
    public var activityId: String
    /// Strava's rank frozen at upload time: "was a PR back then"
    public var prRank: Int?

    public init(name: String, rank: Int, movingTime: Int, distance: Double, startDate: Date, activityId: String, prRank: Int? = nil) {
        self.name = name
        self.rank = rank
        self.movingTime = movingTime
        self.distance = distance
        self.startDate = startDate
        self.activityId = activityId
        self.prRank = prRank
    }

    /// seconds per km of the effort itself (not the whole run)
    public var paceSecKm: Double { Double(movingTime) / (distance / 1000) }
}

/// One shoe of `GET /gear`.
public struct Gear: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var brandName: String?
    public var modelName: String?
    public var computedDistanceM: Double
    public var runCount: Int
    public var firstUseDate: Date?
    public var lastUseDate: Date?
    public var primary: Bool
    public var retired: Bool

    public init(
        id: String, name: String, brandName: String? = nil, modelName: String? = nil,
        computedDistanceM: Double, runCount: Int, firstUseDate: Date? = nil, lastUseDate: Date? = nil,
        primary: Bool = false, retired: Bool = false
    ) {
        self.id = id
        self.name = name
        self.brandName = brandName
        self.modelName = modelName
        self.computedDistanceM = computedDistanceM
        self.runCount = runCount
        self.firstUseDate = firstUseDate
        self.lastUseDate = lastUseDate
        self.primary = primary
        self.retired = retired
    }
}

// MARK: - Totals

/// The all-time tiles of `RunOverviewPage`.
public struct RunTotals: Hashable, Sendable {
    public var count: Int
    public var earliest: Date
    public var totalKm: Double
    public var kmPerWeek: Double
    public var totalSec: Int
    public var avgPaceSecKm: Double?

    /// nil without runs (the tiles show zeros and no subtitles)
    public static func compute(_ runs: [ActivityListItem], now: Date = .now) -> RunTotals? {
        guard let earliest = runs.map(\.startDate).min() else { return nil }
        let km = runs.reduce(0) { $0 + ($1.distanceKm ?? 0) }
        let sec = runs.reduce(0) { $0 + $1.movingTimeSec }
        let weeks = max(1, now.timeIntervalSince(earliest) / (7 * 24 * 3600))
        return RunTotals(
            count: runs.count, earliest: earliest, totalKm: km, kmPerWeek: km / weeks,
            totalSec: sec, avgPaceSecKm: km > 0 ? Double(sec) / km : nil
        )
    }
}

// MARK: - Calendar

/// One month of `RunCalendar`: Monday-first cells, the runs by day and the
/// month's totals.
public struct RunCalendarMonth: Hashable, Sendable {
    /// the 1st, local midnight
    public var start: Date
    /// leading nils up to the 1st's weekday, then one local midnight per day
    public var cells: [Date?]
    /// keyed by the day's local midnight
    public var runsByDay: [Date: [ActivityListItem]]
    public var count: Int
    public var km: Double

    public static func make(_ month: Date, runs: [ActivityListItem], calendar: Calendar) -> RunCalendarMonth {
        let start = RunCalendar.monthStart(month, calendar: calendar)
        let days = calendar.range(of: .day, in: .month, for: start)!.count
        let offset = (calendar.component(.weekday, from: start) + 5) % 7 // Monday = 0
        var cells: [Date?] = Array(repeating: nil, count: offset)
        for d in 0..<days { cells.append(calendar.date(byAdding: .day, value: d, to: start)!) }

        var byDay: [Date: [ActivityListItem]] = [:]
        for run in runs where calendar.isDate(run.startDate, equalTo: start, toGranularity: .month) {
            byDay[calendar.startOfDay(for: run.startDate), default: []].append(run)
        }
        let inMonth = byDay.values.joined()
        return RunCalendarMonth(
            start: start, cells: cells, runsByDay: byDay,
            count: inMonth.count, km: inMonth.reduce(0) { $0 + ($1.distanceKm ?? 0) }
        )
    }
}

public enum RunCalendar {
    public static func monthStart(_ date: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
    }

    /// back to the month of the first run, never before
    public static func canGoBack(from month: Date, earliest: Date?, calendar: Calendar) -> Bool {
        guard let earliest else { return true }
        return monthStart(month, calendar: calendar) > monthStart(earliest, calendar: calendar)
    }

    /// up to the current month, never into the future
    public static func canGoForward(from month: Date, now: Date = .now, calendar: Calendar) -> Bool {
        monthStart(month, calendar: calendar) < monthStart(now, calendar: calendar)
    }

    /// "S T Q Q S S D" | "M T W T F S S"
    public static func weekdayInitials(_ lang: Lang) -> [String] {
        lang == .pt ? ["S", "T", "Q", "Q", "S", "S", "D"] : ["M", "T", "W", "T", "F", "S", "S"]
    }
}

// MARK: - Personal records

/// The 12 distances of `PersonalRecordsCard`, in its order.
public struct RecordDistance: Hashable, Sendable {
    /// Strava's best-effort name, lowercased
    public var key: String
    public var chip: String
    /// `overview.records.distances.*`
    public var titleKey: String
}

public enum PersonalRecords {
    public static let distances: [RecordDistance] = [
        .init(key: "400m", chip: "400M", titleKey: "overview.records.distances.400m"),
        .init(key: "1/2 mile", chip: "½ MI", titleKey: "overview.records.distances.halfMile"),
        .init(key: "1k", chip: "1K", titleKey: "overview.records.distances.1k"),
        .init(key: "1 mile", chip: "1 MI", titleKey: "overview.records.distances.1mile"),
        .init(key: "2 mile", chip: "2 MI", titleKey: "overview.records.distances.2mile"),
        .init(key: "5k", chip: "5K", titleKey: "overview.records.distances.5k"),
        .init(key: "10k", chip: "10K", titleKey: "overview.records.distances.10k"),
        .init(key: "15k", chip: "15K", titleKey: "overview.records.distances.15k"),
        .init(key: "10 mile", chip: "10 MI", titleKey: "overview.records.distances.10mile"),
        .init(key: "20k", chip: "20K", titleKey: "overview.records.distances.20k"),
        .init(key: "half-marathon", chip: "HM", titleKey: "overview.records.distances.halfMarathon"),
        .init(key: "marathon", chip: "MAR", titleKey: "overview.records.distances.marathon"),
    ]

    /// the mobile card shows only these (plus the longest run); "Ver todos" shows all
    public static let headlineKeys: Set<String> = ["1k", "5k", "10k"]

    /// records per distance key, fastest first
    public static func byDistance(_ records: [PersonalBestRecord]) -> [String: [PersonalBestRecord]] {
        Dictionary(grouping: records) { $0.name.lowercased() }.mapValues { $0.sorted { $0.rank < $1.rank } }
    }

    /// "Corrida mais longa": the run with the greatest distance
    public static func longestRun(_ runs: [ActivityListItem]) -> ActivityListItem? {
        runs.reduce(nil) { best, run in
            (run.distanceKm ?? 0) > (best?.distanceKm ?? 0) ? run : best
        }
    }
}

/// Port of `prSnapshot.ts`: distance key → identity of its current top-1
/// effort. The app keeps its own copy (per user, `UserDefaults`), so a new
/// record celebrates once on the web and once in the app.
public enum PrSnapshot {
    public typealias Snapshot = [String: String]

    /// the top-1 effort per distance, identified by activity + time
    public static func topIdentities(_ records: [PersonalBestRecord]) -> Snapshot {
        var snapshot: Snapshot = [:]
        for r in records where r.rank == 1 {
            snapshot[r.name.lowercased()] = "\(r.activityId):\(r.movingTime)"
        }
        return snapshot
    }

    /// Distances whose top-1 changed since the last snapshot. No previous
    /// snapshot (first visit, new device) celebrates nothing.
    public static func newKeys(previous: Snapshot?, next: Snapshot) -> Set<String> {
        guard let previous else { return [] }
        return Set(next.keys.filter { next[$0] != previous[$0] })
    }

    public static func storageKey(userId: String) -> String { "pr-snapshot:\(userId)" }
}

// MARK: - Shoes

public enum Shoes {
    /// Strava exposes no per-shoe mileage goal: the web's fixed placeholder
    public static let lifespanM = 800_000.0

    /// worn fraction, capped at 1
    public static func wear(_ gear: Gear) -> Double { min(1, gear.computedDistanceM / lifespanM) }

    public enum Bar: Sendable { case muted, worn, normal }

    /// retired shoes in muted, above 85% in the negative color, else mustard
    public static func bar(_ gear: Gear) -> Bar {
        gear.retired ? .muted : wear(gear) > 0.85 ? .worn : .normal
    }

    public enum Badge: Sendable { case primary, retired }

    /// "Padrão" | "Aposentado" | nothing (Strava has no tier in between)
    public static func badge(_ gear: Gear) -> Badge? {
        gear.primary ? .primary : gear.retired ? .retired : nil
    }

    public enum Meta: Hashable, Sendable {
        /// a retired shoe: "mai 2025 – jan 2026"
        case dateRange(Date, Date)
        /// "24 corridas · desde mai 2026"
        case runsSince(Int, Date)
        case runsOnly(Int)
    }

    public static func meta(_ gear: Gear) -> Meta {
        if gear.retired, let first = gear.firstUseDate, let last = gear.lastUseDate { return .dateRange(first, last) }
        if let first = gear.firstUseDate { return .runsSince(gear.runCount, first) }
        return .runsOnly(gear.runCount)
    }

    public static func counts(_ gear: [Gear]) -> (active: Int, retired: Int) {
        (gear.filter { !$0.retired }.count, gear.filter(\.retired).count)
    }
}

// MARK: - Formatting

extension RunFormat {
    /// `formatDuration`: "210h 46m" | "52min" (the web's long form, for totals)
    public static func durationLong(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = Int((Double(seconds % 3600) / 60).rounded())
        return h > 0 ? "\(h)h \(m < 10 ? "0" : "")\(m)m" : "\(m)min"
    }

    /// `formatHms`: "21:46" | "1:21:42" — hours only from 1 h
    public static func hms(_ seconds: Int) -> String {
        let h = seconds / 3600
        guard h > 0 else { return minSec(Double(seconds)) }
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return "\(h):\(m < 10 ? "0" : "")\(m):\(s < 10 ? "0" : "")\(s)"
    }

    /// `formatMonthShortYear`: "jul 2023" | "Jul 2023"
    public static func monthShortYear(_ date: Date, lang: Lang, calendar: Calendar) -> String {
        "\(monthShort(date, lang: lang, calendar: calendar)) \(calendar.component(.year, from: date))"
    }

    /// `formatMonthDay`: "mai 10" | "May 10" (the web's order in both languages)
    public static func monthDay(_ date: Date, lang: Lang, calendar: Calendar) -> String {
        "\(monthShort(date, lang: lang, calendar: calendar)) \(calendar.component(.day, from: date))"
    }

    /// `formatMonthDayYear`: "mai 10, 2026" | "May 10, 2026"
    public static func monthDayYear(_ date: Date, lang: Lang, calendar: Calendar) -> String {
        "\(monthDay(date, lang: lang, calendar: calendar)), \(calendar.component(.year, from: date))"
    }

    /// the calendar's title, `toLocaleDateString({month:'long', year:'numeric'})`:
    /// "outubro de 2026" | "October 2026"
    public static func calendarTitle(_ date: Date, lang: Lang, calendar: Calendar) -> String {
        lang == .pt
            ? "\(monthName(date, lang: lang, calendar: calendar)) de \(calendar.component(.year, from: date))"
            : "\(monthName(date, lang: lang, calendar: calendar)) \(calendar.component(.year, from: date))"
    }

    /// `toLocaleDateString({month:'long'})`: "outubro" | "October"
    public static func monthName(_ date: Date, lang: Lang, calendar: Calendar) -> String {
        let long = monthLong(date, lang: lang, calendar: calendar)
        // monthLong is "Outubro de 2026" / "October 2026": keep the month word
        let word = String(long.prefix { $0 != " " })
        return lang == .pt ? word.lowercased() : word
    }
}
