import Foundation

/// The planned sets of an exercise in an open workout (`target.sets`, which
/// the server answers with the workout's own `targetSets` — copied from the
/// routine on start, 1 for an exercise added mid-workout, edited live).
public enum SetPlan {
    /// the server's ceiling for `targetSets`
    public static let maxSets = 20

    /// Planned sets — only a visual guide, the exercise is done when the
    /// lifter marks it (`completedAt`). No target (a workout opened before
    /// planned sets existed, or a routine without one) shows as one.
    public static func target(_ exercise: WorkoutExercise) -> Int {
        exercise.target?.sets ?? 1
    }


    /// A planned set can go only while it isn't done yet, and at least one
    /// stays (to drop the whole exercise there's "Remover exercício").
    public static func canRemove(target: Int, done: Int) -> Bool { target > max(done, 1) }

    public static func canAdd(target: Int) -> Bool { target < maxSets }

    /// "10×6 · 10×6 · 12,5×4 kg": every set of the last session, compact,
    /// with the unit once at the end (only when some set carries a weight).
    public static func lastTime(_ last: LastPerformance, unit: WeightUnit, lang: Lang) -> String? {
        let parts: [String] = last.sets.sorted { $0.setNumber < $1.setNumber }.compactMap { set in
            switch (set.weightKg, set.reps) {
            case let (kg?, reps?): "\(WorkoutFormat.weight(kg, unit: unit, lang: lang))×\(reps)"
            case let (kg?, nil): WorkoutFormat.weight(kg, unit: unit, lang: lang)
            case let (nil, reps?): "×\(reps)"
            case (nil, nil): nil
            }
        }
        guard !parts.isEmpty else { return nil }
        let joined = parts.joined(separator: " · ")
        return last.sets.contains { $0.weightKg != nil } ? "\(joined) \(UnitConversion.label(unit))" : joined
    }
}

extension WorkoutDetail {
    /// The workout with the edits the app made but the server hasn't
    /// answered yet (keyed by workout exercise id): planned sets and the done
    /// mark, so the screen moves at the tap instead of after the round trip.
    public func applying(targetSets: [String: Int] = [:], completed: [String: Bool] = [:], now: Date = Date()) -> WorkoutDetail {
        guard !targetSets.isEmpty || !completed.isEmpty else { return self }
        var copy = self
        for index in copy.exercises.indices {
            let id = copy.exercises[index].id
            if let sets = targetSets[id] {
                var target = copy.exercises[index].target ?? ExerciseTarget(sets: nil, repsMin: nil, repsMax: nil)
                target.sets = sets
                copy.exercises[index].target = target
            }
            if let done = completed[id] {
                copy.exercises[index].completedAt = done ? (copy.exercises[index].completedAt ?? now) : nil
            }
        }
        return copy
    }
}
