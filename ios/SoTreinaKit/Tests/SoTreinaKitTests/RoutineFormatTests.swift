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
