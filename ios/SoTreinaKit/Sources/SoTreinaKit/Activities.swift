import Foundation

/// One row of `GET /activities` (`ActivityListItem` in the server). Distance
/// is always km and pace seconds per km: the user's unit is display only.
public struct ActivityListItem: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var type: String
    /// `EASY_OR_LONG` | `INTERVAL` | `HILL_REPEATS`
    public var workoutType: String
    public var startDate: Date
    public var distanceKm: Double?
    public var movingTimeSec: Int
    public var paceRawSecKm: Double?
    public var elevationGainM: Double?
    public var averageBpm: Double?
    public var maxBpm: Double?
    public var averageCadence: Double?

    public init(
        id: String, name: String, type: String, workoutType: String, startDate: Date,
        distanceKm: Double?, movingTimeSec: Int, paceRawSecKm: Double?,
        elevationGainM: Double?, averageBpm: Double?, maxBpm: Double?, averageCadence: Double?
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.workoutType = workoutType
        self.startDate = startDate
        self.distanceKm = distanceKm
        self.movingTimeSec = movingTimeSec
        self.paceRawSecKm = paceRawSecKm
        self.elevationGainM = elevationGainM
        self.averageBpm = averageBpm
        self.maxBpm = maxBpm
        self.averageCadence = averageCadence
    }
}

/// `GET /activities?limit=1000` — the web fetches the whole history once and
/// derives everything on the client, and so does the app.
public struct ActivitiesPage: Codable, Hashable, Sendable {
    public var items: [ActivityListItem]
    public var total: Int
    public var page: Int
    public var limit: Int
}

/// A custom period, both ends at local midnight, `end` included.
public struct DateRange: Codable, Hashable, Sendable {
    public var start: Date
    public var end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

/// One week of runs (`BinWithRuns` in `bins.ts`, weekly granularity only:
/// the monthly chart is desktop).
public struct WeekBin: Hashable, Sendable {
    /// Monday, local midnight
    public var start: Date
    public var km: Double
    public var sec: Int
    public var runs: [ActivityListItem]

    public var count: Int { runs.count }
}

/// Port of `bins.ts` plus the mobile parts of `Dashboard.tsx` and
/// `DateRangePicker.tsx`. Weeks start on Monday, in the device's time zone.
public enum RunBins {
    /// the mobile list shows this many weeks, then "+ N semanas anteriores"
    public static let weeksPerPage = 4

    public static func startOfWeek(_ date: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        // weekday: 1 = Sunday … 7 = Saturday → days since Monday
        let sinceMonday = (calendar.component(.weekday, from: day) + 5) % 7
        return calendar.date(byAdding: .day, value: -sinceMonday, to: day)!
    }

    /// the week's Sunday, for "13/07 – 19/07"
    public static func endOfWeek(_ start: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: 6, to: start)!
    }

    /// `aggregateBins(…, 'week', from, through)`: every week from the one
    /// holding `from` to the one starting at `through`, zero-filled
    public static func weeks(_ activities: [ActivityListItem], from: Date, through: Date, calendar: Calendar) -> [WeekBin] {
        var bins: [WeekBin] = []
        var start = startOfWeek(from, calendar: calendar)
        while start <= through {
            let end = calendar.date(byAdding: .day, value: 7, to: start)!
            let runs = activities.filter { $0.startDate >= start && $0.startDate < end }
            bins.append(WeekBin(
                start: start,
                km: runs.reduce(0) { $0 + ($1.distanceKm ?? 0) },
                sec: runs.reduce(0) { $0 + $1.movingTimeSec },
                runs: runs
            ))
            start = end
        }
        return bins
    }

    /// `aggregateWeeks(activities, n, 'ALL')`: the last `count` weeks, this
    /// (partial) one included, oldest first
    public static func lastWeeks(_ activities: [ActivityListItem], count: Int, now: Date = .now, calendar: Calendar) -> [WeekBin] {
        let monday = startOfWeek(now, calendar: calendar)
        let from = calendar.date(byAdding: .day, value: -7 * (count - 1), to: monday)!
        return weeks(activities, from: from, through: monday, calendar: calendar)
    }

    /// The weeks of a custom range, holding only the runs inside it.
    public static func weeks(in range: DateRange, _ activities: [ActivityListItem], calendar: Calendar) -> [WeekBin] {
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: range.end)!
        let inside = activities.filter { $0.startDate >= range.start && $0.startDate < endExclusive }
        return weeks(inside, from: range.start, through: startOfWeek(range.end, calendar: calendar), calendar: calendar)
    }

    /// days in a range, both ends included
    public static func days(in range: DateRange, calendar: Calendar) -> Int {
        (calendar.dateComponents([.day], from: range.start, to: range.end).day ?? 0) + 1
    }

    /// The list: newest week first, weeks without runs dropped, `pages` × 4
    /// shown (the mobile "load more" appends instead of paging).
    public static func listGroups(_ weeks: [WeekBin], pages: Int) -> (shown: [WeekBin], olderWeeks: Int) {
        let groups = weeks.reversed().filter { $0.count > 0 }
        let limit = max(1, pages) * weeksPerPage
        return (Array(groups.prefix(limit)), max(0, groups.count - limit))
    }

    /// The hero's progress bar: there's no weekly goal on this screen (the
    /// web compares with last week too); nil when last week had no km
    public static func percentOfLastWeek(thisKm: Double, lastKm: Double) -> Int? {
        lastKm > 0 ? Int((thisKm / lastKm * 100).rounded()) : nil
    }

    // MARK: Period picker

    public enum Preset: String, CaseIterable, Hashable, Sendable {
        case thisMonth, lastMonth, last3Months, thisYear, lastYear
    }

    /// `buildPresets()`, minus those longer than `maxMonths` (mobile passes 3)
    public static func presets(now: Date = .now, calendar: Calendar, maxMonths: Int? = nil) -> [(Preset, DateRange)] {
        let today = calendar.startOfDay(for: now)
        let thisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: thisMonth)!
        let year = calendar.component(.year, from: today)
        func lastDay(of month: Date) -> Date {
            calendar.date(byAdding: DateComponents(month: 1, day: -1), to: month)!
        }
        func jan1(_ y: Int) -> Date { calendar.date(from: DateComponents(year: y, month: 1, day: 1))! }

        let all: [(Preset, DateRange)] = [
            (.thisMonth, DateRange(start: thisMonth, end: lastDay(of: thisMonth))),
            (.lastMonth, DateRange(start: lastMonth, end: lastDay(of: lastMonth))),
            (.last3Months, DateRange(start: calendar.date(byAdding: .month, value: -3, to: today)!, end: today)),
            (.thisYear, DateRange(start: jan1(year), end: today)),
            (.lastYear, DateRange(start: jan1(year - 1), end: calendar.date(from: DateComponents(year: year - 1, month: 12, day: 31))!)),
        ]
        guard let maxMonths else { return all }
        let maxSeconds = Double(maxMonths * 31) * 86_400
        return all.filter { $0.1.end.timeIntervalSince($0.1.start) <= maxSeconds }
    }

    /// A picked end no further than `maxMonths` from the start (the web
    /// clamps the second tap the same way).
    public static func cappedEnd(start: Date, end: Date, maxMonths: Int, calendar: Calendar) -> Date {
        let cap = calendar.date(byAdding: .day, value: -1, to: calendar.date(byAdding: .month, value: maxMonths, to: start)!)!
        return min(end, cap)
    }
}
