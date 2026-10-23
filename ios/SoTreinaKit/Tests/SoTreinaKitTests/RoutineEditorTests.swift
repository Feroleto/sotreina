import Foundation
import Testing
@testable import SoTreinaKit

private func templateFixture() throws -> TemplateDetail {
    let url = try #require(Bundle.module.url(forResource: "workout-template", withExtension: "json", subdirectory: "Fixtures"))
    return try APICoding.makeDecoder().decode(TemplateDetail.self, from: Data(contentsOf: url))
}

private func libraryItem(_ id: String, _ name: String) -> ExerciseListItem {
    ExerciseListItem(
        id: id, name: name, slug: id, force: nil, level: nil, mechanic: nil, equipment: nil,
        primaryMuscles: ["CHEST"], secondaryMuscles: [], source: "SEED"
    )
}

// The web's useRoutineEditor: the routine lives in memory until Salvar.
@Suite struct RoutineDraftTests {
    @Test func newDraftIsDirtyOnceAnythingIsTyped() {
        var draft = RoutineDraft()
        #expect(!draft.isEdit)
        #expect(!draft.isDirty)
        #expect(!draft.canSave)

        draft.name = "   "
        #expect(!draft.isDirty) // whitespace alone isn't a change
        draft.name = "Push"
        #expect(draft.isDirty)
        #expect(draft.canSave)

        draft.name = ""
        draft.toggle(libraryItem("e1", "Supino"))
        #expect(draft.isDirty)
        #expect(!draft.canSave) // a name is required
    }

    @Test func loadedTemplateStartsCleanAndInOrder() throws {
        let template = try templateFixture()
        let draft = RoutineDraft(template: template)
        #expect(draft.isEdit)
        #expect(!draft.isDirty)
        #expect(draft.name == "Upper")
        #expect(draft.exercises.map(\.exerciseId) == template.exercises.sorted { $0.order < $1.order }.map(\.exerciseId))
        #expect(draft.exercises[1].targetRepsMin == 5)
    }

    @Test func editDraftDirtiesOnNameTargetsOrderAndCleansWhenUndone() throws {
        var draft = RoutineDraft(template: try templateFixture())

        draft.name = "Upper B"
        #expect(draft.isDirty)
        draft.name = "Upper"
        #expect(!draft.isDirty)

        let id = draft.exercises[0].id
        draft.update(id) { $0.targetSets = 5 }
        #expect(draft.isDirty)
        draft.update(id) { $0.targetSets = 3 }
        #expect(!draft.isDirty)

        // a pure reorder is a change; moving back undoes it
        draft.move(fromOffsets: IndexSet(integer: 0), toOffset: 2)
        #expect(draft.isDirty)
        draft.move(fromOffsets: IndexSet(integer: 1), toOffset: 0)
        #expect(!draft.isDirty)
    }

    @Test func removingAndReAddingTheSameExerciseIsStillAChangeOfTargets() throws {
        var draft = RoutineDraft(template: try templateFixture())
        let first = draft.exercises[0]
        draft.remove(first.id)
        #expect(draft.isDirty)
        // the row identity doesn't count, but the re-added one comes with the
        // default targets and lands at the end
        draft.toggle(libraryItem(first.exerciseId, first.exerciseName))
        #expect(draft.exercises.last?.exerciseId == first.exerciseId)
        #expect(draft.isDirty)
    }

    @Test func toggleAddsWithDefaultTargetsAndRemovesByExerciseId() {
        var draft = RoutineDraft()
        draft.toggle(libraryItem("e1", "Supino"))
        draft.toggle(libraryItem("e2", "Remada"))
        #expect(draft.exercises.map(\.exerciseId) == ["e1", "e2"])
        #expect(draft.exercises[0].targetSets == 3)
        #expect(draft.exercises[0].targetRepsMin == 10)
        #expect(draft.exercises[0].targetRepsMax == 12)
        #expect(draft.exercises[0].restSeconds == nil)
        #expect(draft.contains(exerciseId: "e1"))

        draft.toggle(libraryItem("e1", "Supino"))
        #expect(draft.exercises.map(\.exerciseId) == ["e2"])
        #expect(!draft.contains(exerciseId: "e1"))
    }

    @Test func requestTrimsTheNameAndSendsTheListInOrder() throws {
        var draft = RoutineDraft()
        draft.name = "  Push  "
        draft.toggle(libraryItem("e1", "Supino"))
        draft.toggle(libraryItem("e2", "Remada"))
        draft.update(draft.exercises[1].id) { $0.restSeconds = 120 }
        draft.move(fromOffsets: IndexSet(integer: 1), toOffset: 0)

        let request = draft.request
        #expect(request.name == "Push")
        #expect(request.exercises.map(\.exerciseId) == ["e2", "e1"])
        #expect(request.exercises[0].restSeconds == 120)

        // no description key: the app has no field for it, so a PATCH keeps
        // whatever the web wrote; nil targets are left out, not sent as null
        let json = String(decoding: try JSONEncoder().encode(request), as: UTF8.self)
        #expect(!json.contains("description"))
        #expect(!json.contains("null"))
    }
}

// RoutineExerciseEditPage's steppers.
@Suite struct RoutineTargetsTests {
    @Test func missingTargetsShowTheDefaults() {
        let steps = TargetSteps(sets: nil, repsMin: nil, repsMax: nil, rest: nil)
        #expect(steps.sets == 3)
        #expect(steps.repsMin == 10)
        #expect(steps.repsMax == 12)
        #expect(steps.rest == nil)
    }

    @Test func setsStayBetweenOneAndTen() {
        var steps = TargetSteps(sets: 1, repsMin: 8, repsMax: 12, rest: nil)
        #expect(!steps.canDecreaseSets)
        steps.sets = 10
        #expect(!steps.canIncreaseSets)
        #expect(steps.canDecreaseSets)
    }

    @Test func repsMinNeverPassesRepsMax() {
        let steps = TargetSteps(sets: 3, repsMin: 10, repsMax: 10, rest: nil)
        #expect(!steps.canIncreaseRepsMin)
        #expect(!steps.canDecreaseRepsMax)
        #expect(steps.canDecreaseRepsMin)
        #expect(steps.canIncreaseRepsMax)

        let edges = TargetSteps(sets: 3, repsMin: 1, repsMax: 50, rest: nil)
        #expect(!edges.canDecreaseRepsMin)
        #expect(!edges.canIncreaseRepsMax)
    }

    @Test func restStepsFromDefaultToNinetyAndBackBelowTheMinimum() {
        #expect(TargetSteps.restUp(nil) == 90)
        #expect(TargetSteps.restUp(90) == 105)
        #expect(TargetSteps.restUp(600) == 600)
        #expect(TargetSteps.restDown(105) == 90)
        #expect(TargetSteps.restDown(15) == nil) // "−" at the minimum goes back to "Padrão"
        #expect(TargetSteps.restDown(nil) == nil)

        #expect(!TargetSteps(sets: 3, repsMin: 8, repsMax: 12, rest: nil).canDecreaseRest)
        #expect(!TargetSteps(sets: 3, repsMin: 8, repsMax: 12, rest: 600).canIncreaseRest)
    }
}

// RoutineExercisePicker's muscle chips → `?muscles=`.
@Suite struct MuscleFilterTests {
    @Test func groupsMatchTheWeb() {
        #expect(MuscleFilter.all.muscles.isEmpty)
        #expect(MuscleFilter.back.muscles == ["BACK", "LATS", "TRAPS", "LOWER_BACK"])
        #expect(MuscleFilter.legs.muscles == ["QUADRICEPS", "HAMSTRINGS", "GLUTES", "CALVES", "ADDUCTORS", "ABDUCTORS"])
        #expect(MuscleFilter.allCases.map(\.rawValue) == ["all", "chest", "back", "legs", "shoulders", "arms", "core"])
    }

    @Test func labelsInBothLanguages() {
        #expect(MuscleFilter.shoulders.label(.pt) == "Ombro")
        #expect(MuscleFilter.arms.label(.en) == "Arms")
    }
}
