import Foundation

/// Text for the workout session, kept here so it's testable on Linux.
public enum WorkoutFormat {
    /// Session clock: "4:05", "12:05", "1:02:05" (no leading zero on the
    /// first unit, like the iOS stopwatch).
    public static func elapsed(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let (h, m, sec) = (s / 3600, s / 60 % 60, s % 60)
        return h > 0
            ? "\(h):\(pad(m)):\(pad(sec))"
            : "\(m):\(pad(sec))"
    }

    /// A stored weight in the display unit (`UnitConversion.display`): "20",
    /// "22,5" in PT, "22.5" in EN — never "20.0". No unit suffix.
    public static func weight(_ kg: Double, unit: WeightUnit = .kg, lang: Lang) -> String {
        let shown = UnitConversion.display(kg: kg, in: unit)
        if shown == shown.rounded() { return String(Int(shown)) }
        let text = String(shown)
        return lang == .pt ? text.replacingOccurrences(of: ".", with: ",") : text
    }

    /// "20 kg × 5", "45 lb × 5", "× 12" (bodyweight), "20 kg" (reps not logged).
    public static func set(weightKg: Double?, reps: Int?, unit: WeightUnit = .kg, lang: Lang = .pt) -> String {
        let label = UnitConversion.label(unit)
        switch (weightKg, reps) {
        case let (kg?, reps?): return "\(weight(kg, unit: unit, lang: lang)) \(label) × \(reps)"
        case let (kg?, nil): return "\(weight(kg, unit: unit, lang: lang)) \(label)"
        case let (nil, reps?): return "× \(reps)"
        case (nil, nil): return "—"
        }
    }

    /// A routine's goal: "3 × 12", "2 × 5–9", "3 séries"; nil when there is
    /// nothing to show (an exercise added ad hoc).
    public static func target(sets: Int?, repsMin: Int?, repsMax: Int?, lang: Lang = .pt) -> String? {
        let pt = lang == .pt
        let reps: String? = switch (repsMin, repsMax) {
        case let (min?, max?) where min == max: "\(min)"
        case let (min?, max?): "\(min)–\(max)"
        case let (min?, nil): "\(min)+"
        case let (nil, max?): pt ? "até \(max)" : "up to \(max)"
        case (nil, nil): nil
        }
        switch (sets, reps) {
        case let (sets?, reps?): return "\(sets) × \(reps)"
        case let (sets?, nil):
            if pt { return sets == 1 ? "1 série" : "\(sets) séries" }
            return sets == 1 ? "1 set" : "\(sets) sets"
        case let (nil, reps?): return "\(reps) reps"
        case (nil, nil): return nil
        }
    }

    public static func target(_ target: ExerciseTarget?, lang: Lang = .pt) -> String? {
        target.flatMap { self.target(sets: $0.sets, repsMin: $0.repsMin, repsMax: $0.repsMax, lang: lang) }
    }

    /// Summary duration, same as the web's `formatDurationShort`: "52min", "1h05".
    public static func durationShort(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600
        let m = Int((Double(s % 3600) / 60).rounded())
        return h > 0 ? "\(h)h\(pad(m))" : "\(m)min"
    }

    /// Training volume like the web's `formatVolume` + `volumeLabel`:
    /// thousands of the display unit, always one decimal — "1,8 t" in PT,
    /// "4.0 k lb" in EN. The separator follows the app's language, not the
    /// device locale.
    public static func volume(_ kg: Double, unit: WeightUnit = .kg, lang: Lang = .pt) -> String {
        let tenths = Int((UnitConversion.volumeThousands(kg: max(0, kg), in: unit) * 10).rounded())
        let decimal = lang == .pt ? "," : "."
        return "\(tenths / 10)\(decimal)\(tenths % 10) \(UnitConversion.volumeLabel(unit))"
    }

    /// Volume of the open workout in whole display units, thousands grouped
    /// by the app's language: "60", "4.320" in PT, "4,320" in EN. No unit
    /// suffix (the "Finalizar treino?" card sets it smaller).
    public static func volumeWhole(_ kg: Double, unit: WeightUnit = .kg, lang: Lang = .pt) -> String {
        let whole = Int(UnitConversion.display(kg: max(0, kg), in: unit).rounded())
        let digits = Array(String(whole))
        let separator: Character = lang == .pt ? "." : ","
        var out: [Character] = []
        for (index, digit) in digits.enumerated() {
            if index > 0, (digits.count - index) % 3 == 0 { out.append(separator) }
            out.append(digit)
        }
        return String(out)
    }

    private static func pad(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }
}
