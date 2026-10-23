import Foundation

// Display rules for routines, ported from the web so both read the same:
// client/src/features/gym/relativeTime.ts, routineFormat.ts and the
// `muscles`/`routines` strings of client/src/i18n/locales/{pt,en}/gym.json.
// Every text function takes `lang` (default PT, the app's language until
// every screen passes the user's choice).

public enum MuscleGroup {
    private static let labelsPT: [String: String] = [
        "CHEST": "Peito",
        "BACK": "Costas",
        "LATS": "Dorsais",
        "TRAPS": "Trapézio",
        "SHOULDERS": "Ombros",
        "BICEPS": "Bíceps",
        "TRICEPS": "Tríceps",
        "FOREARMS": "Antebraços",
        "ABDOMINALS": "Abdômen",
        "QUADRICEPS": "Quadríceps",
        "HAMSTRINGS": "Posterior de coxa",
        "GLUTES": "Glúteos",
        "CALVES": "Panturrilhas",
        "ADDUCTORS": "Adutores",
        "ABDUCTORS": "Abdutores",
        "LOWER_BACK": "Lombar",
        "NECK": "Pescoço",
        "CARDIO": "Cardio",
        "FULL_BODY": "Corpo inteiro",
    ]

    private static let labelsEN: [String: String] = [
        "CHEST": "Chest",
        "BACK": "Back",
        "LATS": "Lats",
        "TRAPS": "Traps",
        "SHOULDERS": "Shoulders",
        "BICEPS": "Biceps",
        "TRICEPS": "Triceps",
        "FOREARMS": "Forearms",
        "ABDOMINALS": "Abs",
        "QUADRICEPS": "Quads",
        "HAMSTRINGS": "Hamstrings",
        "GLUTES": "Glutes",
        "CALVES": "Calves",
        "ADDUCTORS": "Adductors",
        "ABDUCTORS": "Abductors",
        "LOWER_BACK": "Lower back",
        "NECK": "Neck",
        "CARDIO": "Cardio",
        "FULL_BODY": "Full body",
    ]

    /// Label for a server `MuscleGroup` value; an unknown one (added on the
    /// server after this build) shows as itself rather than vanishing.
    public static func label(_ raw: String, lang: Lang) -> String {
        (lang == .pt ? labelsPT : labelsEN)[raw] ?? raw
    }

    /// PT, usable as a function reference (`.map(MuscleGroup.label)`), which
    /// a defaulted `lang` parameter wouldn't be.
    public static func label(_ raw: String) -> String {
        label(raw, lang: .pt)
    }
}

public enum RoutineFormat {
    /// "hoje", "ontem", "há 3 dias"… — same buckets as the web's
    /// `relativeTimeFromNow` (elapsed 24h periods, not calendar days).
    public static func lastPerformed(_ date: Date?, now: Date = .now, lang: Lang = .pt) -> String {
        let pt = lang == .pt
        guard let date else { return pt ? "ainda não realizada" : "not done yet" }
        let days = Int(max(0, now.timeIntervalSince(date)) / 86_400)
        switch days {
        case 0: return pt ? "hoje" : "today"
        case 1: return pt ? "ontem" : "yesterday"
        case ..<7: return ago(days, pt ? ("dia", "dias") : ("day", "days"), lang)
        case ..<35: return ago(Int((Double(days) / 7).rounded()), pt ? ("semana", "semanas") : ("week", "weeks"), lang)
        case ..<365: return ago(Int((Double(days) / 30).rounded()), pt ? ("mês", "meses") : ("month", "months"), lang)
        default: return ago(Int((Double(days) / 365).rounded()), pt ? ("ano", "anos") : ("year", "years"), lang)
        }
    }

    /// The routine performed longest ago, so a split (A → B → C) rotates on
    /// its own. Never-performed routines only come up when nothing has been
    /// performed yet — an abandoned one would otherwise stay on top forever.
    public static func nextRoutine(_ templates: [TemplateSummary]) -> TemplateSummary? {
        let performed = templates.filter { $0.lastPerformedAt != nil }
        guard !performed.isEmpty else { return templates.first }
        return performed.min { $0.lastPerformedAt! < $1.lastPerformedAt! }
    }

    private static func ago(_ count: Int, _ unit: (one: String, other: String), _ lang: Lang) -> String {
        let word = count == 1 ? unit.one : unit.other
        return lang == .pt ? "há \(count) \(word)" : "\(count) \(word) ago"
    }
}
