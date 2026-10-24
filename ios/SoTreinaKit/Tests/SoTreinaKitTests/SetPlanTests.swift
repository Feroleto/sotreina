import Foundation
import Testing
@testable import SoTreinaKit

@Suite struct SetPlanTests {
    private func exercise(_ id: String, target: ExerciseTarget?) -> WorkoutExercise {
        WorkoutExercise(
            id: id, exerciseId: "ex-\(id)", exerciseName: id, order: 1,
            supersetGroupId: nil, target: target, sets: []
        )
    }

    private func last(_ sets: [(Double?, Int?)]) -> LastPerformance {
        LastPerformance(
            workoutId: "w0",
            startedAt: Date(timeIntervalSince1970: 0),
            sets: sets.enumerated().map { index, values in
                LastPerformanceSet(
                    id: "s\(index)", setNumber: index + 1, weightKg: values.0,
                    reps: values.1, rpe: nil, setType: "WORKING"
                )
            }
        )
    }

    @Test func noTargetCountsAsOneSet() {
        #expect(SetPlan.target(exercise("a", target: nil)) == 1)
        #expect(SetPlan.target(exercise("a", target: ExerciseTarget(sets: nil, repsMin: 8, repsMax: 12))) == 1)
        #expect(SetPlan.target(exercise("a", target: ExerciseTarget(sets: 4, repsMin: nil, repsMax: nil))) == 4)
    }

    @Test func removeNeverGoesBelowWhatIsDoneNorBelowOne() {
        #expect(SetPlan.canRemove(target: 3, done: 1))
        #expect(SetPlan.canRemove(target: 3, done: 2))
        #expect(!SetPlan.canRemove(target: 3, done: 3))
        #expect(!SetPlan.canRemove(target: 1, done: 0))
        #expect(SetPlan.canRemove(target: 2, done: 0))
    }

    @Test func addStopsAtTheServerCeiling() {
        #expect(SetPlan.canAdd(target: 19))
        #expect(!SetPlan.canAdd(target: 20))
    }

    @Test func lastTimeListsEverySetWithTheUnitOnce() {
        #expect(SetPlan.lastTime(last([(10, 6), (10, 6), (12.5, 4)]), unit: .kg, lang: .pt) == "10×6 · 10×6 · 12,5×4 kg")
        #expect(SetPlan.lastTime(last([(nil, 12), (nil, 10)]), unit: .kg, lang: .pt) == "×12 · ×10")
        #expect(SetPlan.lastTime(last([(nil, nil)]), unit: .kg, lang: .pt) == nil)
    }

    @Test func overridesReplaceThePlannedSetsKeepingRepsAndRest() {
        let workout = WorkoutDetail(
            id: "w1", startedAt: Date(timeIntervalSince1970: 0), finishedAt: nil, notes: nil,
            templateId: nil, templateName: nil,
            exercises: [
                exercise("a", target: ExerciseTarget(sets: 3, repsMin: 8, repsMax: 12, restSeconds: 90)),
                exercise("b", target: nil),
                exercise("c", target: ExerciseTarget(sets: 2, repsMin: nil, repsMax: nil)),
            ]
        )
        let applied = workout.applying(targetSets: ["a": 4, "b": 2])
        #expect(applied.exercises[0].target == ExerciseTarget(sets: 4, repsMin: 8, repsMax: 12, restSeconds: 90))
        #expect(applied.exercises[1].target == ExerciseTarget(sets: 2, repsMin: nil, repsMax: nil))
        #expect(applied.exercises[2].target?.sets == 2)
    }

    @Test func completedOverridesStampAndClearTheDoneMark() {
        let now = Date(timeIntervalSince1970: 100)
        var done = exercise("b", target: nil)
        done.completedAt = Date(timeIntervalSince1970: 50)
        let workout = WorkoutDetail(
            id: "w1", startedAt: Date(timeIntervalSince1970: 0), finishedAt: nil, notes: nil,
            templateId: nil, templateName: nil, exercises: [exercise("a", target: nil), done]
        )
        let applied = workout.applying(completed: ["a": true, "b": false], now: now)
        #expect(applied.exercises[0].completedAt == now)
        #expect(applied.exercises[1].completedAt == nil)
    }
}
