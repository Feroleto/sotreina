import Foundation
import Testing
@testable import SoTreinaKit

@Suite struct WorkoutClosingTests {
    private let start = Date(timeIntervalSince1970: 0)

    private func set(_ number: Int, _ kg: Double?, _ reps: Int?) -> WorkoutSet {
        WorkoutSet(id: "s\(number)", setNumber: number, weightKg: kg, reps: reps, rpe: nil, setType: "NORMAL", completedAt: start)
    }

    private func exercise(_ id: String, sets target: Int?, logged: [WorkoutSet] = []) -> WorkoutExercise {
        WorkoutExercise(
            id: id, exerciseId: "ex-\(id)", exerciseName: id, order: 1, supersetGroupId: nil,
            target: target.map { ExerciseTarget(sets: $0, repsMin: nil, repsMax: nil) }, sets: logged
        )
    }

    private func workout(_ exercises: [WorkoutExercise]) -> WorkoutDetail {
        WorkoutDetail(id: "w1", startedAt: start, finishedAt: nil, notes: nil, templateId: nil, templateName: nil, exercises: exercises)
    }

    /// the design's example: 1 set of 10 kg × 6 against 3 + 3 + 2 + 3 + 2 planned
    @Test func countsLikeTheProgressHeader() {
        let tally = WorkoutClosing.tally(workout([
            exercise("a", sets: 3, logged: [set(1, 10, 6)]),
            exercise("b", sets: 3), exercise("c", sets: 2), exercise("d", sets: 3), exercise("e", sets: 2),
        ]))
        #expect(tally == WorkoutTally(loggedSets: 1, plannedSets: 13, volumeKg: 60))
        #expect(tally.remainingSets == 12)
    }

    @Test func setsBeyondThePlanAndNoTargetCount() {
        let tally = WorkoutClosing.tally(workout([
            exercise("a", sets: 1, logged: [set(1, 20, 5), set(2, 20, 5)]),
            exercise("b", sets: nil),
        ]))
        // 2 logged over a plan of 1, plus 1 for the exercise without a target
        #expect(tally.plannedSets == 3)
        #expect(tally.remainingSets == 1)
        #expect(tally.volumeKg == 200)
    }

    @Test func pendingSetsCountAndAddVolume() {
        let pending = [WorkoutActivity.PendingSet(workoutExerciseId: "a", weightKg: 12.5, reps: 4, failed: true)]
        let tally = WorkoutClosing.tally(workout([exercise("a", sets: 3, logged: [set(1, 10, 6)])]), pending: pending)
        #expect(tally.loggedSets == 2)
        #expect(tally.volumeKg == 110)
    }

    @Test func setsWithoutWeightOrRepsAddNoVolume() {
        let tally = WorkoutClosing.tally(workout([exercise("a", sets: 2, logged: [set(1, nil, 10), set(2, 30, nil)])]))
        #expect(tally.volumeKg == 0)
        #expect(tally.loggedSets == 2)
    }

    @Test func wholeMinutesNeverNegative() {
        #expect(WorkoutClosing.minutes(startedAt: start, now: Date(timeIntervalSince1970: 59)) == 0)
        #expect(WorkoutClosing.minutes(startedAt: start, now: Date(timeIntervalSince1970: 19 * 60 + 40)) == 19)
        #expect(WorkoutClosing.minutes(startedAt: start, now: Date(timeIntervalSince1970: -30)) == 0)
    }

    @Test func discardMessagePicksTheCase() {
        #expect(WorkoutClosing.discardMessage(loggedSets: 0, minutes: 0) == .empty)
        #expect(WorkoutClosing.discardMessage(loggedSets: 0, minutes: 5) == .minutes(5))
        #expect(WorkoutClosing.discardMessage(loggedSets: 2, minutes: 0) == .sets(2))
        #expect(WorkoutClosing.discardMessage(loggedSets: 1, minutes: 19) == .setsAndMinutes(sets: 1, minutes: 19))
    }

    @Test func finishMessagePicksTheCase() {
        #expect(WorkoutClosing.finishMessage(WorkoutTally(loggedSets: 0, plannedSets: 4, volumeKg: 0)) == .noSets)
        #expect(WorkoutClosing.finishMessage(WorkoutTally(loggedSets: 1, plannedSets: 13, volumeKg: 60)) == .remaining(12))
        #expect(WorkoutClosing.finishMessage(WorkoutTally(loggedSets: 4, plannedSets: 4, volumeKg: 900)) == .allLogged)
    }

    @Test func wholeVolumeGroupsThousandsByLanguage() {
        #expect(WorkoutFormat.volumeWhole(60, unit: .kg, lang: .pt) == "60")
        #expect(WorkoutFormat.volumeWhole(4320, unit: .kg, lang: .pt) == "4.320")
        #expect(WorkoutFormat.volumeWhole(4320, unit: .kg, lang: .en) == "4,320")
        #expect(WorkoutFormat.volumeWhole(1234567, unit: .kg, lang: .en) == "1,234,567")
        #expect(WorkoutFormat.volumeWhole(0, unit: .kg, lang: .pt) == "0")
        // 1814.37 kg = 4000 lb
        #expect(WorkoutFormat.volumeWhole(1814.37, unit: .lb, lang: .en) == "4,000")
    }
}
