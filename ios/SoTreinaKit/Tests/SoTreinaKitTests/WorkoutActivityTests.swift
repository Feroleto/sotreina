import Foundation
import Testing
@testable import SoTreinaKit

@Suite struct WorkoutActivityTests {
    private let t0 = Date(timeIntervalSince1970: 1_792_000_000)

    private func set(_ number: Int, _ kg: Double?, _ reps: Int?, at minute: Double) -> WorkoutSet {
        WorkoutSet(
            id: "s\(number)-\(minute)", setNumber: number, weightKg: kg, reps: reps, rpe: nil,
            setType: "WORKING", completedAt: t0.addingTimeInterval(minute * 60)
        )
    }

    private func exercise(_ id: String, order: Int, target: Int?, sets: [WorkoutSet] = []) -> WorkoutExercise {
        WorkoutExercise(
            id: id, exerciseId: "ex-\(id)", exerciseName: "Exercício \(id)", order: order,
            supersetGroupId: nil,
            target: target.map { ExerciseTarget(sets: $0, repsMin: 8, repsMax: 12) },
            sets: sets
        )
    }

    private func workout(_ exercises: [WorkoutExercise]) -> WorkoutDetail {
        WorkoutDetail(
            id: "w1", startedAt: t0, finishedAt: nil, notes: nil,
            templateId: "t1", templateName: "Upper", exercises: exercises
        )
    }

    // MARK: cursor

    @Test func startsOnTheFirstExerciseByOrder() throws {
        let cursor = try #require(WorkoutActivity.cursor(
            in: workout([exercise("b", order: 2, target: 3), exercise("a", order: 1, target: 3)]),
            pending: []
        ))
        #expect(cursor.exercise.id == "a")
        #expect(cursor.setNumber == 1)
    }

    @Test func staysOnTheLatestExerciseUntilItsTargetIsMet() throws {
        let w = workout([
            exercise("a", order: 1, target: 3, sets: [set(1, 20, 5, at: 1)]),
            exercise("b", order: 2, target: 3, sets: [set(1, 40, 8, at: 5)]),
        ])
        let cursor = try #require(WorkoutActivity.cursor(in: w, pending: []))
        // b was touched last and isn't done: stay there, even though a isn't done either
        #expect(cursor.exercise.id == "b")
        #expect(cursor.setNumber == 2)
    }

    @Test func movesToTheFirstUnfinishedExerciseOnceTheTargetIsMet() throws {
        let w = workout([
            exercise("a", order: 1, target: 2, sets: [set(1, 20, 5, at: 1), set(2, 20, 5, at: 2)]),
            exercise("b", order: 2, target: 2),
        ])
        let cursor = try #require(WorkoutActivity.cursor(in: w, pending: []))
        #expect(cursor.exercise.id == "b")
        #expect(cursor.setNumber == 1)
    }

    @Test func pendingSetsCountAndMarkTheLastTouchedExercise() throws {
        let w = workout([exercise("a", order: 1, target: 3), exercise("b", order: 2, target: 3)])
        let pending = [WorkoutActivity.PendingSet(workoutExerciseId: "b", weightKg: 40, reps: 8, failed: false)]
        let cursor = try #require(WorkoutActivity.cursor(in: w, pending: pending))
        #expect(cursor.exercise.id == "b")
        #expect(cursor.setNumber == 2)
    }

    @Test func anAdHocExerciseWithoutTargetStaysCurrentWhileBeingWorked() throws {
        let w = workout([
            exercise("a", order: 1, target: 1, sets: [set(1, 20, 5, at: 1)]),
            exercise("x", order: 2, target: nil, sets: [set(1, 10, 12, at: 3), set(2, 10, 12, at: 4)]),
        ])
        let cursor = try #require(WorkoutActivity.cursor(in: w, pending: []))
        #expect(cursor.exercise.id == "x")
        #expect(cursor.setNumber == 3)
    }

    @Test func everythingDoneStaysOnTheLastTouched() throws {
        let w = workout([
            exercise("a", order: 1, target: 1, sets: [set(1, 20, 5, at: 2)]),
            exercise("b", order: 2, target: 1, sets: [set(1, 40, 8, at: 1)]),
        ])
        let cursor = try #require(WorkoutActivity.cursor(in: w, pending: []))
        #expect(cursor.exercise.id == "a")
        #expect(cursor.setNumber == 2)
    }

    @Test func noExercisesNoCursor() {
        #expect(WorkoutActivity.cursor(in: workout([]), pending: []) == nil)
    }

    // MARK: snapshot

    @Test func snapshotCarriesProposalRestAndALogLink() throws {
        let w = workout([exercise("a", order: 1, target: 3, sets: [set(1, 20, 5, at: 1)])])
        let rest = RestTimer.Active(endsAt: t0.addingTimeInterval(200), duration: 90)
        let clientId = UUID()

        let snapshot = WorkoutActivity.snapshot(
            workout: w, pending: [], lastPerformance: [:], rest: rest, clientId: clientId, now: t0.addingTimeInterval(150)
        )

        #expect(snapshot.exerciseName == "Exercício a")
        #expect(snapshot.setLabel == "Série 2 de 3")
        #expect(snapshot.restEndsAt == rest.endsAt)
        #expect(snapshot.proposal == SetProposal(weightKg: 20, reps: 5, source: .previousSet))
        let link = try #require(snapshot.logSetURL.flatMap(ActivityLink.init(url:)))
        #expect(link == .logSet(workoutId: "w1", workoutExerciseId: "a", weightKg: 20, reps: 5, clientId: clientId))
    }

    @Test func snapshotCarriesTheWeightUnitForTheProposal() throws {
        let w = workout([exercise("a", order: 1, target: 3, sets: [set(1, 20.41, 5, at: 1)])])
        let snapshot = WorkoutActivity.snapshot(
            workout: w, pending: [], lastPerformance: [:], rest: nil, clientId: UUID(),
            lang: .en, weightUnit: .lb, now: t0
        )
        #expect(snapshot.weightUnit == .lb)
        #expect(snapshot.proposalText == "45 lb × 5")
        // the "✓" link still carries kg: it goes straight to the API
        let link = try #require(snapshot.logSetURL.flatMap(ActivityLink.init(url:)))
        guard case let .logSet(_, _, weightKg, _, _) = link else { Issue.record("not a logSet link"); return }
        #expect(weightKg == 20.41)
    }

    @Test func snapshotDropsAnElapsedRestAndFlagsFailedSets() {
        let w = workout([exercise("a", order: 1, target: 3)])
        let rest = RestTimer.Active(endsAt: t0, duration: 90)
        let pending = [WorkoutActivity.PendingSet(workoutExerciseId: "a", weightKg: 20, reps: 5, failed: true)]

        let snapshot = WorkoutActivity.snapshot(
            workout: w, pending: pending, lastPerformance: [:], rest: rest, clientId: UUID(), now: t0.addingTimeInterval(1)
        )

        #expect(snapshot.restEndsAt == nil)
        #expect(snapshot.hasFailedSet)
        // the failed set still counts and seeds the proposal
        #expect(snapshot.setNumber == 2)
        #expect(snapshot.proposal?.weightKg == 20)
    }

    @Test func snapshotWithoutProposalHasNoLogLink() {
        let snapshot = WorkoutActivity.snapshot(
            workout: workout([exercise("a", order: 1, target: 3)]), pending: [], lastPerformance: [:],
            rest: nil, clientId: UUID()
        )
        #expect(snapshot.proposal == nil)
        #expect(snapshot.logSetURL == nil)
    }

    @Test func setLabelPastTheTarget() {
        var snapshot = WorkoutActivity.snapshot(
            workout: workout([exercise("a", order: 1, target: nil)]), pending: [], lastPerformance: [:],
            rest: nil, clientId: UUID()
        )
        #expect(snapshot.setLabel == "Série 1")
        snapshot.targetSets = 3
        snapshot.setNumber = 4
        #expect(snapshot.setLabel == "Série 4")
    }

    // MARK: links

    @Test func linksRoundTrip() {
        let links: [ActivityLink] = [
            .addRest(seconds: 15),
            .skipRest,
            .logSet(workoutId: "w1", workoutExerciseId: "we1", weightKg: 22.5, reps: 8, clientId: UUID()),
            .logSet(workoutId: "w1", workoutExerciseId: "we1", weightKg: nil, reps: 12, clientId: UUID()),
        ]
        for link in links {
            #expect(ActivityLink(url: link.url) == link)
        }
    }

    @Test func rejectsForeignOrIncompleteLinks() {
        #expect(ActivityLink(url: URL(string: "https://www.sotreina.com/rest/skip")!) == nil)
        #expect(ActivityLink(url: URL(string: "sotreina://rest/add")!) == nil)
        #expect(ActivityLink(url: URL(string: "sotreina://set/log?workout=w&exercise=e&reps=5")!) == nil)
        #expect(ActivityLink(url: URL(string: "sotreina://set/log?workout=w&exercise=e&client=\(UUID().uuidString)")!) == nil)
    }
}
