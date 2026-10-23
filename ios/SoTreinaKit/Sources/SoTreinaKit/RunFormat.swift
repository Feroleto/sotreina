import Foundation

/// Port of the parts of `client/src/lib/activityFormat.ts` the run screens
/// use. Numbers follow the app's language ("12,4" in PT), not the device
/// locale — the web writes "12.4" in both, a `toFixed` quirk the app doesn't copy.
public enum RunFormat {
    /// "12,4" — km in, the user's unit out, one decimal, no suffix
    public static func distance(_ km: Double, unit: DistanceUnit, lang: Lang) -> String {
        let text = String(format: "%.1f", UnitConversion.display(km: km, in: unit))
        return lang == .pt ? text.replacingOccurrences(of: ".", with: ",") : text
    }

    /// "5:12" — pace in the user's unit, no suffix; "—" without a pace
    public static func paceValue(_ secPerKm: Double?, unit: DistanceUnit) -> String {
        guard let secPerKm, secPerKm > 0, secPerKm.isFinite else { return "—" }
        let perUnit = UnitConversion.pace(secondsPerKm: secPerKm, in: unit)
        var min = Int(perUnit / 60)
        var sec = Int((perUnit.truncatingRemainder(dividingBy: 60)).rounded())
        if sec == 60 {
            min += 1
            sec = 0
        }
        return "\(min):\(sec < 10 ? "0" : "")\(sec)"
    }

    /// "5:12 /km" | "8:23 /mi"
    public static func pace(_ secPerKm: Double?, unit: DistanceUnit) -> String {
        let value = paceValue(secPerKm, unit: unit)
        return value == "—" ? value : "\(value) /\(UnitConversion.label(unit))"
    }

    /// "05/03" (DD/MM in both languages, like the web)
    public static func dayMonth(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.day, .month], from: date)
        return String(format: "%02d/%02d", c.day ?? 0, c.month ?? 0)
    }

    /// "set" | "Sep" — under the first bar of each month
    public static func monthShort(_ date: Date, lang: Lang, calendar: Calendar) -> String {
        let names = lang == .pt ? monthsShortPt : monthsShortEn
        return names[calendar.component(.month, from: date) - 1]
    }

    /// "Outubro de 2026" | "October 2026"
    public static func monthLong(_ date: Date, lang: Lang, calendar: Calendar) -> String {
        let month = calendar.component(.month, from: date) - 1
        let year = calendar.component(.year, from: date)
        return lang == .pt ? "\(monthsLongPt[month]) de \(year)" : "\(monthsLongEn[month]) \(year)"
    }

    /// `formatRangeLabel`: a whole calendar month reads as the month,
    /// anything else as "23/07 – 23/10"
    public static func rangeLabel(_ range: DateRange, lang: Lang, calendar: Calendar) -> String {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: range.start))!
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)!
        if range.start == monthStart, calendar.isDate(range.end, inSameDayAs: monthEnd) {
            return monthLong(range.start, lang: lang, calendar: calendar)
        }
        return "\(dayMonth(range.start, calendar: calendar)) – \(dayMonth(range.end, calendar: calendar))"
    }

    /// "13/07 – 19/07"
    public static func weekRange(_ start: Date, calendar: Calendar) -> String {
        "\(dayMonth(start, calendar: calendar)) – \(dayMonth(RunBins.endOfWeek(start, calendar: calendar), calendar: calendar))"
    }

    private static let monthsShortPt = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]
    private static let monthsShortEn = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    private static let monthsLongPt = ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"]
    private static let monthsLongEn = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
}
