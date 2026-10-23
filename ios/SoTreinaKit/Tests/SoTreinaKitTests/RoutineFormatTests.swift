import Foundation
import Testing
@testable import SoTreinaKit

@Suite struct RoutineFormatTests {
    private let now = Date(timeIntervalSince1970: 1_792_000_000)
    private func daysAgo(_ days: Double) -> Date { now.addingTimeInterval(-days * 86_400) }

    @Test(arguments: [
        (0.5, "hoje"),
        (1.2, "ontem"),
        (2, "há 2 dias"),
        (6.9, "há 6 dias"),
        (7, "há 1 semana"),
        (20, "há 3 semanas"),
        (35, "há 1 mês"),
        (100, "há 3 meses"),
        (365, "há 1 ano"),
        (800, "há 2 anos"),
    ])
    func lastPerformedBuckets(days: Double, expected: String) {
        #expect(RoutineFormat.lastPerformed(daysAgo(days), now: now) == expected)
    }

    @Test func lastPerformedHandlesNeverAndFutureDates() {
        #expect(RoutineFormat.lastPerformed(nil, now: now) == "ainda não realizada")
        // clock skew between phone and server must not print "há -1 dias"
        #expect(RoutineFormat.lastPerformed(now.addingTimeInterval(3_600), now: now) == "hoje")
    }

    private func template(_ id: String, _ last: Date?) -> TemplateSummary {
        TemplateSummary(
            id: id, name: id, description: nil, exerciseCount: 1,
            exercisePreview: [], muscleGroups: [], lastPerformedAt: last
        )
    }

    @Test func nextRoutineIsTheOnePerformedLongestAgo() {
        let templates = [template("A", daysAgo(2)), template("B", daysAgo(5)), template("C", daysAgo(1))]
        #expect(RoutineFormat.nextRoutine(templates)?.id == "B")
    }

    @Test func nextRoutineIgnoresNeverPerformedOnesOnceAnyWasDone() {
        let templates = [template("new", nil), template("A", daysAgo(3))]
        #expect(RoutineFormat.nextRoutine(templates)?.id == "A")
    }

    @Test func nextRoutineFallsBackToTheFirstWhenNoneWasDone() {
        #expect(RoutineFormat.nextRoutine([template("X", nil), template("Y", nil)])?.id == "X")
        #expect(RoutineFormat.nextRoutine([]) == nil)
    }

    @Test func muscleLabelsFallBackToTheRawValue() {
        #expect(MuscleGroup.label("LATS") == "Dorsais")
        #expect(MuscleGroup.label("NEW_GROUP") == "NEW_GROUP")
    }
}

// Routine and exercise detail (RoutineDetailPage / RoutineExerciseDetailPage).
@Suite struct RoutineDetailFormatTests {
    @Test(arguments: [
        (nil, nil, "—"),
        (8, 12, "8–12"),
        (10, 10, "10"),
        (8, nil, "8"),
        (nil, 12, "12"),
    ] as [(Int?, Int?, String)])
    func repsRange(min: Int?, max: Int?, expected: String) {
        #expect(RoutineFormat.repsRange(min: min, max: max) == expected)
    }

    @Test func restIsMinutesAndPaddedSeconds() {
        #expect(RoutineFormat.rest(seconds: 90) == "1:30")
        #expect(RoutineFormat.rest(seconds: 45) == "0:45")
        #expect(RoutineFormat.rest(seconds: 600) == "10:00")
    }

    @Test func equipmentLabelsFollowTheWebAndKeepUnknownValues() {
        #expect(Equipment.label("BODY_ONLY", lang: .pt) == "Peso corporal")
        #expect(Equipment.label("BODY_ONLY", lang: .en) == "Bodyweight")
        #expect(Equipment.label("HOVERBOARD", lang: .pt) == "HOVERBOARD")
        // no equipment in the library entry
        #expect(Equipment.label(nil, lang: .pt) == "Musculação")
        #expect(Equipment.label(nil, lang: .en) == "Strength training")
    }

    @Test func instructionsJoinNonEmptyStepsElseFallback() {
        #expect(ExerciseDetail.instructionsText(["Suba.", "", "Desça."], lang: .pt) == "Suba. Desça.")
        #expect(ExerciseDetail.instructionsText([], lang: .pt).hasPrefix("Execute o movimento com controle"))
        #expect(ExerciseDetail.instructionsText([""], lang: .en).hasPrefix("Perform the movement with control"))
    }

    @Test func previousWeightIsTheHeaviestSetIgnoringBodyweight() {
        let sets = [
            LastPerformanceSet(id: "a", setNumber: 1, weightKg: 40, reps: 8, rpe: nil, setType: "NORMAL"),
            LastPerformanceSet(id: "b", setNumber: 2, weightKg: nil, reps: 8, rpe: nil, setType: "NORMAL"),
            LastPerformanceSet(id: "c", setNumber: 3, weightKg: 42.5, reps: 6, rpe: nil, setType: "NORMAL"),
        ]
        let last = LastPerformance(workoutId: "w", startedAt: .now, sets: sets)
        #expect(last.heaviestWeightKg == 42.5)
        #expect(LastPerformance(workoutId: "w", startedAt: .now, sets: [sets[1]]).heaviestWeightKg == nil)
    }
}
