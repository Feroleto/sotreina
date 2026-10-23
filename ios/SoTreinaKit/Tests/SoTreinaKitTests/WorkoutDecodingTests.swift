import Foundation
import Testing
@testable import SoTreinaKit

// Fixtures are real responses from the local API (captured 2026-10-22), except
// workout-active.json and the `summary` in workout-finished.json, which were
// derived from workout-detail.json by hand to cover cases the captured data
// didn't have (open workout, decimal weight, missing reps, ad hoc exercise).
private func fixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try APICoding.makeDecoder().decode(T.self, from: Data(contentsOf: url))
}

@Suite struct WorkoutDecodingTests {
    @Test func decodesTemplateSummaries() throws {
        let templates = try fixture("workout-templates", as: [TemplateSummary].self)

        #expect(templates.count == 2)
        #expect(templates[0].name == "Upper")
        #expect(templates[0].muscleGroups == ["LATS", "CHEST"])
        #expect(templates[0].lastPerformedAt != nil)
        // never performed: null, not a missing key
        #expect(templates[1].lastPerformedAt == nil)
    }

    @Test func decodesTemplateDetail() throws {
        let template = try fixture("workout-template", as: TemplateDetail.self)

        #expect(template.exercises.map(\.order) == [1, 2, 3])
        #expect(template.exercises[1].targetRepsMin == 5)
        #expect(template.exercises[1].targetRepsMax == 9)
        // captured before restSeconds existed: an absent key decodes as nil
        #expect(template.exercises[1].restSeconds == nil)
    }

    @Test func decodesFinishedWorkoutDetail() throws {
        let workout = try fixture("workout-detail", as: WorkoutDetail.self)

        #expect(workout.finishedAt != nil)
        #expect(workout.templateName == "Upper")
        #expect(workout.exercises.count == 3)
        #expect(workout.exercises[0].target == ExerciseTarget(sets: 3, repsMin: 12, repsMax: 12))
        #expect(workout.exercises[2].sets.map(\.weightKg) == [80, 80])
    }

    @Test func decodesOpenWorkoutEdgeCases() throws {
        let workout = try fixture("workout-active", as: WorkoutDetail.self)

        #expect(workout.finishedAt == nil)
        let set = try #require(workout.exercises[1].sets.first)
        #expect(set.weightKg == 22.5)
        #expect(set.reps == nil)
        let adHoc = workout.exercises[2]
        #expect(adHoc.target == nil)
        #expect(adHoc.sets.isEmpty)
    }

    @Test func decodesFinishResponseAsDetailPlusSummary() throws {
        let finished = try fixture("workout-finished", as: FinishedWorkout.self)

        #expect(finished.detail.exercises.count == 3)
        #expect(finished.summary.setCount == 7)
        #expect(finished.summary.volumeKg == 1820)
        let record = try #require(finished.summary.personalRecords.first)
        #expect(record.previousWeightKg == 17.5)
        #expect(record.previousReps == nil)
    }

    @Test func decodesExerciseSearchPage() throws {
        let page = try fixture("exercises-search", as: ExercisePage.self)

        #expect(page.items.count == 3)
        #expect(page.total == 45)
        #expect(page.items[0].primaryMuscles == ["CHEST"])
    }

    @Test func decodesLastPerformance() throws {
        let last = try fixture("exercise-last-performance", as: LastPerformance.self)

        #expect(last.sets.map(\.setNumber) == [1, 2, 3])
        #expect(last.sets.allSatisfy { $0.weightKg == 20 && $0.reps == 5 })
    }
}

@Suite struct WorkoutRequestEncodingTests {
    private func json(_ value: some Encodable) throws -> [String: Any] {
        let data = try APICoding.makeEncoder().encode(value)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func addSetSendsClientIdAsUUIDString() throws {
        let id = UUID()
        let body = try json(AddSetRequest(weightKg: 22.5, reps: 8, clientId: id))

        #expect(body["clientId"] as? String == id.uuidString)
        #expect(body["weightKg"] as? Double == 22.5)
        #expect(body["reps"] as? Int == 8)
        // rpe not set: omitted rather than null
        #expect(body["rpe"] == nil)
    }

    @Test func updateSetOmitsUnchangedFields() throws {
        let body = try json(UpdateSetRequest(reps: 10))

        #expect(body.keys.sorted() == ["reps"])
    }

    @Test func startWorkoutWithoutTemplateIsAnEmptyObject() throws {
        #expect(try json(StartWorkoutRequest(templateId: nil)).isEmpty)
        #expect(try json(StartWorkoutRequest(templateId: "t1"))["templateId"] as? String == "t1")
    }
}

@Suite struct FinishFlowTests {
    @Test func finishSendsSyncTemplate() throws {
        let data = try APICoding.makeEncoder().encode(FinishWorkoutRequest(syncTemplate: true))
        let body = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(body["syncTemplate"] as? Bool == true)
    }

    @Test func templateDriftDecodes() throws {
        let drift = try APICoding.makeDecoder().decode(TemplateDriftResponse.self, from: Data(#"{"diverged":true}"#.utf8))
        #expect(drift.diverged)
    }

    /// Same as the web's `handleFinishClick`: only a templated workout that
    /// drifted asks about the routine; a free workout and a failed check
    /// fall back to the plain confirmation
    @Test func whichDialogFinishOpens() {
        #expect(FinishPrompt.for(templateId: nil, diverged: nil) == .confirm)
        #expect(FinishPrompt.for(templateId: "t1", diverged: false) == .confirm)
        #expect(FinishPrompt.for(templateId: "t1", diverged: nil) == .confirm)
        #expect(FinishPrompt.for(templateId: "t1", diverged: true) == .syncTemplate)
        #expect(!FinishPrompt.needsDriftCheck(templateId: nil))
        #expect(FinishPrompt.needsDriftCheck(templateId: "t1"))
    }
}
