import Foundation

/// One lap of `GET /activities/:id` (`ActivityLap` in the web's types).
/// `avgHr` 0 means "no HR monitor", never null; `avgPaceSecKm` 0 means no pace.
public struct ActivityLap: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var lapIndex: Int
    /// `WARMUP` | `COOLDOWN` | `WORKOUT` | `REST` | `STEADY` | `ACTIVITY`
    public var lapType: String
    public var startSec: Int
    public var endSec: Int
    public var movingDurationSec: Double
    public var distanceM: Double
    public var avgPaceSecKm: Double
    public var avgHr: Double
    public var maxHr: Double?
    public var elevGainM: Double
    public var avgCadence: Double?

    public init(
        id: String, lapIndex: Int, lapType: String, startSec: Int = 0, endSec: Int = 0,
        movingDurationSec: Double, distanceM: Double, avgPaceSecKm: Double,
        avgHr: Double = 0, maxHr: Double? = nil, elevGainM: Double = 0, avgCadence: Double? = nil
    ) {
        self.id = id
        self.lapIndex = lapIndex
        self.lapType = lapType
        self.startSec = startSec
        self.endSec = endSec
        self.movingDurationSec = movingDurationSec
        self.distanceM = distanceM
        self.avgPaceSecKm = avgPaceSecKm
        self.avgHr = avgHr
        self.maxHr = maxHr
        self.elevGainM = elevGainM
        self.avgCadence = avgCadence
    }
}

/// `GET /activities/:id`: the list row plus what only the detail shows.
/// `stravaId` is a string (a BigInt on the server) for "View on Strava".
public struct ActivityDetail: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var stravaId: String
    public var name: String
    public var type: String
    public var workoutType: String
    public var startDate: Date
    public var distanceKm: Double?
    public var movingTimeSec: Int
    public var paceRawSecKm: Double?
    public var elevationGainM: Double?
    public var averageBpm: Double?
    public var maxBpm: Double?
    public var averageCadence: Double?
    public var summaryPolyline: String?
    public var laps: [ActivityLap]

    /// "View on Strava" (brand guidelines: that exact text, linked here)
    public var stravaURL: URL { URL(string: "https://www.strava.com/activities/\(stravaId)")! }

    /// the route, or nil for a treadmill run (no polyline, or too short to draw)
    public var route: [LatLng]? {
        guard let summaryPolyline, !summaryPolyline.isEmpty else { return nil }
        let points = Polyline.decode(summaryPolyline)
        return points.count >= 2 ? points : nil
    }

    /// the fastest lap's pace (the web's `fastestPace`), laps without pace ignored
    public var fastestLapPace: Double? {
        laps.map(\.avgPaceSecKm).filter { $0 > 0 }.min()
    }
}

public struct LatLng: Hashable, Sendable {
    public var lat: Double
    public var lng: Double

    public init(lat: Double, lng: Double) {
        self.lat = lat
        self.lng = lng
    }
}

/// Port of `client/src/lib/polyline.ts`: Google's encoded polyline
/// (precision 1e5), as in Strava's `map.summary_polyline`.
public enum Polyline {
    public static func decode(_ encoded: String) -> [LatLng] {
        let bytes = Array(encoded.utf8)
        var points: [LatLng] = []
        var index = 0
        var lat = 0
        var lng = 0

        func next() -> Int? {
            var result = 0
            var shift = 0
            var byte: Int
            repeat {
                guard index < bytes.count else { return nil }
                byte = Int(bytes[index]) - 63
                index += 1
                result |= (byte & 0x1F) << shift
                shift += 5
            } while byte >= 0x20
            return result & 1 != 0 ? ~(result >> 1) : result >> 1
        }

        while index < bytes.count {
            // a truncated string ends the route instead of reading past it
            guard let dLat = next(), let dLng = next() else { break }
            lat += dLat
            lng += dLng
            points.append(LatLng(lat: Double(lat) / 1e5, lng: Double(lng) / 1e5))
        }
        return points
    }
}

/// A lap's name as an L10n key plus its number per type ("Tiro 2"); a type
/// that occurs once keeps the bare label. Composed into text by the view.
public struct LapLabel: Hashable, Sendable {
    /// `activity.lapType.*`, or the raw lap type when unknown
    public var key: String
    public var number: Int?
}

extension RunFormat {
    private static let lapTypeKeys: [String: String] = [
        "WARMUP": "activity.lapType.warmup",
        "COOLDOWN": "activity.lapType.cooldown",
        "WORKOUT": "activity.lapType.workout",
        "REST": "activity.lapType.rest",
        "RUN": "activity.lapType.run",
        "STEADY": "activity.lapType.steady",
        "ACTIVITY": "activity.lapType.activity",
    ]

    private static let kmLapToleranceM = 100.0

    /// `lapLabels`: "Tiro 1", "Rec. 1", "Km 3", numbered per type. STEADY
    /// laps that aren't ~1 km each (a run lapped by hand on the watch) read
    /// "Volta N" instead of a misleading "Km N"; the last one may be partial.
    public static func lapLabels(_ laps: [ActivityLap]) -> [LapLabel] {
        let steady = laps.filter { $0.lapType == "STEADY" }
        let steadyIsKm = steady.dropLast().allSatisfy { abs($0.distanceM - 1000) <= kmLapToleranceM }

        var perType: [String: Int] = [:]
        for lap in laps { perType[lap.lapType, default: 0] += 1 }
        var counters: [String: Int] = [:]
        return laps.map { lap in
            let key = lap.lapType == "STEADY" && !steadyIsKm
                ? lapTypeKeys["RUN"]!
                : lapTypeKeys[lap.lapType] ?? lap.lapType
            counters[lap.lapType, default: 0] += 1
            return LapLabel(key: key, number: perType[lap.lapType]! > 1 ? counters[lap.lapType] : nil)
        }
    }

    /// `WORKOUT_META` label key: `common.workout.*`, nil for an unknown type
    public static func workoutTypeKey(_ workoutType: String) -> String? {
        switch workoutType {
        case "EASY_OR_LONG": "common.workout.easyLong"
        case "INTERVAL": "common.workout.interval"
        case "HILL_REPEATS": "common.workout.hillRepeats"
        default: nil
        }
    }

    /// `formatMinSec`: "4:32" — lap durations
    public static func minSec(_ seconds: Double) -> String {
        var m = Int(seconds / 60)
        var s = Int(seconds.truncatingRemainder(dividingBy: 60).rounded())
        if s == 60 {
            m += 1
            s = 0
        }
        return "\(m):\(s < 10 ? "0" : "")\(s)"
    }

    /// "1,00" — a lap's distance in the user's unit, two decimals, no suffix
    public static func lapDistance(_ meters: Double, unit: DistanceUnit, lang: Lang) -> String {
        let text = String(format: "%.2f", UnitConversion.display(km: meters / 1000, in: unit))
        return lang == .pt ? text.replacingOccurrences(of: ".", with: ",") : text
    }

    /// `formatDateFull`: "Terça-feira, 04 de agosto · 15:48" |
    /// "Tuesday, August 04 · 03:48 PM" (the web's `toLocale*String` output)
    public static func dateFull(_ date: Date, lang: Lang, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.weekday, .day, .month, .hour, .minute], from: date)
        let weekday = c.weekday! - 1
        let month = c.month! - 1
        let day = String(format: "%02d", c.day!)
        let minute = String(format: "%02d", c.minute!)
        switch lang {
        case .pt:
            return "\(weekdaysPt[weekday]), \(day) de \(monthsLongPtLower[month]) · \(String(format: "%02d", c.hour!)):\(minute)"
        case .en:
            let hour12 = c.hour! % 12 == 0 ? 12 : c.hour! % 12
            let meridiem = c.hour! < 12 ? "AM" : "PM"
            return "\(weekdaysEn[weekday]), \(monthsLongEnNames[month]) \(day) · \(String(format: "%02d", hour12)):\(minute) \(meridiem)"
        }
    }

    // index 0 = Sunday, like Calendar's weekday - 1
    static let weekdaysPt = ["Domingo", "Segunda-feira", "Terça-feira", "Quarta-feira", "Quinta-feira", "Sexta-feira", "Sábado"]
    static let weekdaysEn = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    static let monthsLongPtLower = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"]
    static let monthsLongEnNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
}
