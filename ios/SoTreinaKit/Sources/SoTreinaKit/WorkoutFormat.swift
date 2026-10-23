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

    /// Weight: "20", "22,5" in PT, "22.5" in EN — never "20.0".
    public static func weight(_ kg: Double, lang: Lang) -> String {
        let rounded = (kg * 100).rounded() / 100
        if rounded == rounded.rounded() { return String(Int(rounded)) }
        let text = String(rounded)
        return lang == .pt ? text.replacingOccurrences(of: ".", with: ",") : text
    }

    /// PT, for `.map(WorkoutFormat.weight)` (a defaulted `lang` doesn't
    /// convert to `(Double) -> String`).
    public static func weight(_ kg: Double) -> String { weight(kg, lang: .pt) }

    /// "20 kg × 5", "× 12" (bodyweight), "20 kg" (reps not logged).
    public static func set(weightKg: Double?, reps: Int?, lang: Lang = .pt) -> String {
        switch (weightKg, reps) {
        case let (kg?, reps?): "\(weight(kg, lang: lang)) kg × \(reps)"
        case let (kg?, nil): "\(weight(kg, lang: lang)) kg"
        case let (nil, reps?): "× \(reps)"
        case (nil, nil): "—"
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

    /// Volume, at most one decimal: "1.820", "12.345,5" in PT; "1,820",
    /// "12,345.5" in EN. Hand-rolled instead of NumberFormatter so it follows
    /// the app's language, not the device locale (and reads the same in
    /// `swift test` on Linux).
    public static func volume(_ kg: Double, lang: Lang = .pt) -> String {
        let (thousands, decimal) = lang == .pt ? (".", ",") : (",", ".")
        let tenths = Int((max(0, kg) * 10).rounded())
        var digits = String(tenths / 10)
        var grouped = ""
        while digits.count > 3 {
            grouped = thousands + digits.suffix(3) + grouped
            digits.removeLast(3)
        }
        grouped = digits + grouped
        return tenths % 10 == 0 ? grouped : "\(grouped)\(decimal)\(tenths % 10)"
    }

    private static func pad(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }
}
