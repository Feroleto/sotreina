import Foundation

/// What the "Cancelar treino?" and "Finalizar treino?" cards say (Claude
/// Design "Treino Academia Foco" 3a/3b): the sets logged against the plan,
/// the volume and the consequence line. The cards read the same counts as
/// the session's progress header, so "1 de 13 séries" and "1/13" agree.
public struct WorkoutTally: Equatable, Sendable {
    /// confirmed sets plus the ones still on their way to the server
    public var loggedSets: Int
    /// planned sets; a set beyond the plan still counts (the header's rule)
    public var plannedSets: Int
    /// sum of weight × reps, the server summary's formula
    public var volumeKg: Double

    public init(loggedSets: Int, plannedSets: Int, volumeKg: Double) {
        self.loggedSets = loggedSets
        self.plannedSets = plannedSets
        self.volumeKg = volumeKg
    }

    /// planned sets with nothing logged — they don't reach the history
    public var remainingSets: Int { max(0, plannedSets - loggedSets) }
}

public enum WorkoutClosing {
    public static func tally(_ workout: WorkoutDetail, pending: [WorkoutActivity.PendingSet] = []) -> WorkoutTally {
        var logged = 0
        var planned = 0
        var volume = 0.0
        for exercise in workout.exercises {
            let mine = pending.filter { $0.workoutExerciseId == exercise.id }
            let count = exercise.sets.count + mine.count
            logged += count
            planned += max(SetPlan.target(exercise), count)
            volume += exercise.sets.reduce(0) { $0 + ($1.weightKg ?? 0) * Double($1.reps ?? 0) }
            volume += mine.reduce(0) { $0 + ($1.weightKg ?? 0) * Double($1.reps ?? 0) }
        }
        return WorkoutTally(loggedSets: logged, plannedSets: planned, volumeKg: volume)
    }

    /// Whole minutes since the start, for "os 19 minutos de treino".
    public static func minutes(startedAt: Date, now: Date) -> Int {
        max(0, Int(now.timeIntervalSince(startedAt)) / 60)
    }

    /// The consequence line of "Cancelar treino?" — one string key per case,
    /// each ending in "Essa ação não pode ser desfeita."
    public enum DiscardMessage: Equatable, Sendable {
        /// nothing logged, under a minute
        case empty
        case minutes(Int)
        case sets(Int)
        case setsAndMinutes(sets: Int, minutes: Int)
    }

    public static func discardMessage(loggedSets: Int, minutes: Int) -> DiscardMessage {
        switch (loggedSets > 0, minutes > 0) {
        case (false, false): .empty
        case (false, true): .minutes(minutes)
        case (true, false): .sets(loggedSets)
        case (true, true): .setsAndMinutes(sets: loggedSets, minutes: minutes)
        }
    }

    /// The consequence line of "Finalizar treino?".
    public enum FinishMessage: Equatable, Sendable {
        /// the workout goes to the history without a set
        case noSets
        /// "Ainda há N séries sem registro"
        case remaining(Int)
        case allLogged
    }

    public static func finishMessage(_ tally: WorkoutTally) -> FinishMessage {
        if tally.loggedSets == 0 { return .noSets }
        return tally.remainingSets > 0 ? .remaining(tally.remainingSets) : .allLogged
    }
}
