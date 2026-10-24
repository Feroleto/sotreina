import Foundation

/// The planned sets of an exercise in an open workout (`target.sets`, which
/// the server answers with the workout's own `targetSets` — copied from the
/// routine on start, 1 for an exercise added mid-workout, edited live).
public enum SetPlan {
    /// the server's ceiling for `targetSets`
    public static let maxSets = 20

    /// Planned sets; an exercise with no target (a workout opened before
    /// planned sets existed, or a routine without one) counts as one — the
    /// same rule as the Live Activity's cursor (done once it has a set).
    public static func target(_ exercise: WorkoutExercise) -> Int {
        exercise.target?.sets ?? 1
    }

    /// Done = logged + unconfirmed sets reached the plan.
    public static func isDone(target: Int, done: Int) -> Bool { done >= target }

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
    /// The workout with planned sets the app changed but the server hasn't
    /// answered yet (keyed by workout exercise id), so the screen moves at
    /// the tap instead of after the round trip.
    public func applyingTargetSets(_ overrides: [String: Int]) -> WorkoutDetail {
        guard !overrides.isEmpty else { return self }
        var copy = self
        for index in copy.exercises.indices {
            guard let sets = overrides[copy.exercises[index].id] else { continue }
            var target = copy.exercises[index].target ?? ExerciseTarget(sets: nil, repsMin: nil, repsMax: nil)
            target.sets = sets
            copy.exercises[index].target = target
        }
        return copy
    }
}
