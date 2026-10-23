import Foundation

/// The values a new set starts with, so logging the usual set is one tap
/// (spec §6.7 — the Live Activity's "✓" will reuse it in Fase 2).
public struct SetProposal: Codable, Hashable, Sendable {
    public enum Source: String, Codable, Hashable, Sendable {
        /// the same set number, last time this exercise was done
        case lastTime
        /// the set just before it in this workout
        case previousSet
    }

    public var weightKg: Double?
    public var reps: Int?
    public var source: Source

    public init(weightKg: Double?, reps: Int?, source: Source) {
        self.weightKg = weightKg
        self.reps = reps
        self.source = source
    }

    /// Precedence: (1) set `setNumber` from last time; (2) the previous set
    /// of this workout; (3) last time's final set, for a session with more
    /// sets than last time (the web's fallback). nil for an exercise never
    /// done that has no set yet — nothing sensible to propose.
    public static func propose(
        setNumber: Int,
        lastPerformance: LastPerformance?,
        previousInWorkout: (weightKg: Double?, reps: Int?)?
    ) -> SetProposal? {
        let lastSets = (lastPerformance?.sets ?? []).sorted { $0.setNumber < $1.setNumber }
        if let same = lastSets.first(where: { $0.setNumber == setNumber }), same.hasValues {
            return SetProposal(weightKg: same.weightKg, reps: same.reps, source: .lastTime)
        }
        if let previous = previousInWorkout, previous.weightKg != nil || previous.reps != nil {
            return SetProposal(weightKg: previous.weightKg, reps: previous.reps, source: .previousSet)
        }
        if let final = lastSets.last, final.hasValues {
            return SetProposal(weightKg: final.weightKg, reps: final.reps, source: .lastTime)
        }
        return nil
    }
}

private extension LastPerformanceSet {
    var hasValues: Bool { weightKg != nil || reps != nil }
}

/// Parsing what the user types in the set fields (PT keyboards give "22,5").
public enum SetInput {
    /// nil for empty or invalid input; negatives and absurd values are invalid
    public static func weight(_ text: String) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value.isFinite, value >= 0, value < 10_000 else { return nil }
        return value
    }

    public static func reps(_ text: String) -> Int? {
        guard let value = Int(text.trimmingCharacters(in: .whitespaces)), value >= 0, value < 10_000 else { return nil }
        return value
    }

    /// A weight typed in the display unit → what goes into `weightKg`.
    public static func weightKg(_ text: String, unit: WeightUnit) -> Double? {
        weight(text).map { UnitConversion.kg(fromDisplay: $0, in: unit) }
    }

    /// Saving an edited set: the field started as `original` shown in the
    /// display unit, so an untouched field sends `original` back as is — in
    /// lb (1 decimal) the round trip could move it by a few grams.
    public static func editedWeightKg(_ text: String, original: Double?, unit: WeightUnit, lang: Lang) -> Double? {
        if let original, text == WorkoutFormat.weight(original, unit: unit, lang: lang) { return original }
        return weightKg(text, unit: unit)
    }
}
