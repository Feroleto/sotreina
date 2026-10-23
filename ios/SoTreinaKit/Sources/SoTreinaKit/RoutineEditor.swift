import Foundation

// The routine editor, ported from the web (client/src/features/gym/
// useRoutineEditor.ts, RoutineExerciseEditPage.tsx, RoutineExercisePicker.tsx):
// the whole routine is built in memory and sent in one call on Salvar —
// `POST /workout-templates` to create, `PATCH /workout-templates/:id` with
// the full exercise list to edit. Closing without saving discards for real.

/// One exercise of the routine being edited. `id` only tells rows apart on
/// screen (the server row id when loaded, a fresh one when added); it's never
/// sent back, the request carries the `exerciseId` list in order.
public struct WorkingExercise: Equatable, Sendable, Identifiable {
    public let id: String
    public var exerciseId: String
    public var exerciseName: String
    public var targetSets: Int?
    public var targetRepsMin: Int?
    public var targetRepsMax: Int?
    /// nil = the timer's remembered length applies ("Padrão")
    public var restSeconds: Int?
}

public struct RoutineDraft: Equatable, Sendable {
    public var name: String
    public private(set) var exercises: [WorkingExercise]
    /// the routine as loaded, to compare against; nil when creating
    private let baseline: Baseline?

    private struct Baseline: Equatable, Sendable {
        let name: String
        let signature: [Signature]
    }

    /// What counts as a change in the list: the order and the targets, not
    /// the row identity (the web's `exercisesSignature`).
    private struct Signature: Equatable, Sendable {
        let exerciseId: String
        let targetSets: Int?
        let targetRepsMin: Int?
        let targetRepsMax: Int?
        let restSeconds: Int?
    }

    /// "Nova rotina"
    public init() {
        name = ""
        exercises = []
        baseline = nil
    }

    /// "Editar rotina"
    public init(template: TemplateDetail) {
        let loaded = template.exercises.sorted { $0.order < $1.order }.map {
            WorkingExercise(
                id: $0.id, exerciseId: $0.exerciseId, exerciseName: $0.exerciseName,
                targetSets: $0.targetSets, targetRepsMin: $0.targetRepsMin,
                targetRepsMax: $0.targetRepsMax, restSeconds: $0.restSeconds
            )
        }
        name = template.name
        exercises = loaded
        baseline = Baseline(name: template.name, signature: loaded.map(Self.signature))
    }

    public var isEdit: Bool { baseline != nil }

    /// Creating: anything typed or added. Editing: differs from what loaded.
    /// Gates the "Descartar alterações?" confirmation.
    public var isDirty: Bool {
        guard let baseline else {
            return !name.trimmingCharacters(in: .whitespaces).isEmpty || !exercises.isEmpty
        }
        return name != baseline.name || exercises.map(Self.signature) != baseline.signature
    }

    /// The server requires a name; a routine with no exercises is allowed.
    public var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    public func contains(exerciseId: String) -> Bool {
        exercises.contains { $0.exerciseId == exerciseId }
    }

    /// The picker's tap: adds with the default targets (3 × 10–12) when the
    /// exercise isn't in the routine, removes it when it is.
    public mutating func toggle(_ exercise: ExerciseListItem) {
        if let index = exercises.firstIndex(where: { $0.exerciseId == exercise.id }) {
            exercises.remove(at: index)
            return
        }
        exercises.append(WorkingExercise(
            id: UUID().uuidString, exerciseId: exercise.id, exerciseName: exercise.name,
            targetSets: TargetSteps.defaultSets, targetRepsMin: TargetSteps.defaultRepsMin,
            targetRepsMax: TargetSteps.defaultRepsMax, restSeconds: nil
        ))
    }

    public mutating func remove(_ id: String) {
        exercises.removeAll { $0.id == id }
    }

    public mutating func update(_ id: String, _ change: (inout WorkingExercise) -> Void) {
        guard let index = exercises.firstIndex(where: { $0.id == id }) else { return }
        change(&exercises[index])
    }

    /// Same contract as SwiftUI's `onMove` (and `Array.move`, which lives in
    /// SwiftUI, out of reach of the Kit on Linux).
    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.map { exercises[$0] }
        let before = source.filter { $0 < destination }.count
        for index in source.reversed() { exercises.remove(at: index) }
        exercises.insert(contentsOf: moving, at: destination - before)
    }

    /// The body of both calls; `order` comes from the position, on the server.
    public var request: TemplateWriteRequest {
        TemplateWriteRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            exercises: exercises.map {
                TemplateExerciseInput(
                    exerciseId: $0.exerciseId, targetSets: $0.targetSets,
                    targetRepsMin: $0.targetRepsMin, targetRepsMax: $0.targetRepsMax,
                    restSeconds: $0.restSeconds
                )
            }
        )
    }

    private static func signature(_ exercise: WorkingExercise) -> Signature {
        Signature(
            exerciseId: exercise.exerciseId, targetSets: exercise.targetSets,
            targetRepsMin: exercise.targetRepsMin, targetRepsMax: exercise.targetRepsMax,
            restSeconds: exercise.restSeconds
        )
    }
}

/// `POST /workout-templates` and `PATCH /workout-templates/:id`. No
/// `description`: the app has no field for it (like the web on mobile), and
/// leaving the key out makes a PATCH keep the one written on the web.
public struct TemplateWriteRequest: Encodable, Equatable, Sendable {
    public var name: String
    public var exercises: [TemplateExerciseInput]
}

/// One exercise of the request. Nil targets are left out (synthesized
/// `Encodable` skips them), which the server reads as "no target".
public struct TemplateExerciseInput: Encodable, Equatable, Sendable {
    public var exerciseId: String
    public var targetSets: Int?
    public var targetRepsMin: Int?
    public var targetRepsMax: Int?
    public var restSeconds: Int?
}

/// "Editar exercício": the stepper values and their limits. Missing targets
/// show the defaults, like the web; only the stepper that's tapped writes.
public struct TargetSteps: Equatable, Sendable {
    public static let defaultSets = 3
    public static let defaultRepsMin = 10
    public static let defaultRepsMax = 12
    public static let setsRange = 1...10
    public static let repsRange = 1...50
    /// 15 s steps between the server's 15 s and 10 min
    public static let restStep = 15
    public static let restRange = 15...600
    /// where "+" lands from "Padrão": the timer's default
    public static let restFirst = 90

    public var sets: Int
    public var repsMin: Int
    public var repsMax: Int
    public var rest: Int?

    public init(sets: Int?, repsMin: Int?, repsMax: Int?, rest: Int?) {
        self.sets = sets ?? Self.defaultSets
        self.repsMin = repsMin ?? Self.defaultRepsMin
        self.repsMax = repsMax ?? Self.defaultRepsMax
        self.rest = rest
    }

    public init(_ exercise: WorkingExercise) {
        self.init(sets: exercise.targetSets, repsMin: exercise.targetRepsMin, repsMax: exercise.targetRepsMax, rest: exercise.restSeconds)
    }

    public var canDecreaseSets: Bool { sets > Self.setsRange.lowerBound }
    public var canIncreaseSets: Bool { sets < Self.setsRange.upperBound }
    public var canDecreaseRepsMin: Bool { repsMin > Self.repsRange.lowerBound }
    public var canIncreaseRepsMin: Bool { repsMin < repsMax && repsMin < Self.repsRange.upperBound }
    public var canDecreaseRepsMax: Bool { repsMax > repsMin && repsMax > Self.repsRange.lowerBound }
    public var canIncreaseRepsMax: Bool { repsMax < Self.repsRange.upperBound }
    public var canDecreaseRest: Bool { rest != nil }
    public var canIncreaseRest: Bool { (rest ?? 0) < Self.restRange.upperBound }

    /// "−" at the minimum goes back to "Padrão" (nil) instead of stopping.
    public static func restDown(_ rest: Int?) -> Int? {
        guard let rest else { return nil }
        let next = rest - restStep
        return next < restRange.lowerBound ? nil : next
    }

    public static func restUp(_ rest: Int?) -> Int? {
        guard let rest else { return restFirst }
        return min(rest + restStep, restRange.upperBound)
    }
}

/// The picker's muscle chips: coarse groups → server `MuscleGroup` values,
/// sent as `?muscles=` (an OR on `primaryMuscles`).
public enum MuscleFilter: String, CaseIterable, Sendable {
    case all, chest, back, legs, shoulders, arms, core

    public var muscles: [String] {
        switch self {
        case .all: []
        case .chest: ["CHEST"]
        case .back: ["BACK", "LATS", "TRAPS", "LOWER_BACK"]
        case .legs: ["QUADRICEPS", "HAMSTRINGS", "GLUTES", "CALVES", "ADDUCTORS", "ABDUCTORS"]
        case .shoulders: ["SHOULDERS"]
        case .arms: ["BICEPS", "TRICEPS", "FOREARMS"]
        case .core: ["ABDOMINALS"]
        }
    }

    public func label(_ lang: Lang) -> String {
        let pt = lang == .pt
        switch self {
        case .all: return pt ? "Todos" : "All"
        case .chest: return pt ? "Peito" : "Chest"
        case .back: return pt ? "Costas" : "Back"
        case .legs: return pt ? "Pernas" : "Legs"
        case .shoulders: return pt ? "Ombro" : "Shoulders"
        case .arms: return pt ? "Braço" : "Arms"
        case .core: return "Core"
        }
    }
}
