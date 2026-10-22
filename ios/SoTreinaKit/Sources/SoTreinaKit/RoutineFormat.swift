import Foundation

// Display rules for routines, ported from the web so both read the same:
// client/src/features/gym/relativeTime.ts, routineFormat.ts and the
// `muscles` labels of client/src/i18n/locales/pt/gym.json.

public enum MuscleGroup {
    private static let labels: [String: String] = [
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

    /// PT label for a server `MuscleGroup` value; an unknown one (added on
    /// the server after this build) shows as itself rather than vanishing.
    public static func label(_ raw: String) -> String {
        labels[raw] ?? raw
    }
}

public enum RoutineFormat {
    /// "hoje", "ontem", "há 3 dias"… — same buckets as the web's
    /// `relativeTimeFromNow` (elapsed 24h periods, not calendar days).
    public static func lastPerformed(_ date: Date?, now: Date = .now) -> String {
        guard let date else { return "ainda não realizada" }
        let days = Int(max(0, now.timeIntervalSince(date)) / 86_400)
        switch days {
        case 0: return "hoje"
        case 1: return "ontem"
        case ..<7: return plural(days, "dia", "dias")
        case ..<35: return plural(Int((Double(days) / 7).rounded()), "semana", "semanas")
        case ..<365: return plural(Int((Double(days) / 30).rounded()), "mês", "meses")
        default: return plural(Int((Double(days) / 365).rounded()), "ano", "anos")
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

    private static func plural(_ count: Int, _ one: String, _ other: String) -> String {
        "há \(count) \(count == 1 ? one : other)"
    }
}
