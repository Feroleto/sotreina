import Foundation

// Mirrors of the gym endpoints the app consumes. Hand-written like `Me`
// (.plans/app-ios-nativo-spec.md §5.4); each one names the server type it
// copies, and DecodingTests runs them against JSON captured from the API.
// Enum-like strings (muscle groups, setType) stay `String`: the app only
// displays them, and a new server value must never break a whole decode.

// MARK: - Routines

/// `GET /workout-templates` item — `TemplateSummary` in
/// server/src/workout-templates/workout-templates.service.ts.
public struct TemplateSummary: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var description: String?
    public var exerciseCount: Int
    public var exercisePreview: [String]
    public var muscleGroups: [String]
    public var lastPerformedAt: Date?
}

/// `GET /workout-templates/:id` — `TemplateDetail`.
public struct TemplateDetail: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var description: String?
    public var exercises: [TemplateExercise]
}

/// `TemplateExerciseDetail`.
public struct TemplateExercise: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var exerciseId: String
    public var exerciseName: String
    public var primaryMuscles: [String]
    public var order: Int
    public var targetSets: Int?
    public var targetRepsMin: Int?
    public var targetRepsMax: Int?
    /// seconds; nil = the user's default (absent from older servers too)
    public var restSeconds: Int?
    public var supersetGroupId: String?
}

// MARK: - Workout session

/// Every `/workouts/*` mutation answers with this, and the app replaces its
/// state with it — `WorkoutDetail` in server/src/workouts/workouts.service.ts.
/// `GET /workouts/active` answers it too, or an empty body (no open workout).
public struct WorkoutDetail: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var startedAt: Date
    public var finishedAt: Date?
    public var notes: String?
    public var templateId: String?
    public var templateName: String?
    public var exercises: [WorkoutExercise]
}

/// `WorkoutExerciseDetail`.
public struct WorkoutExercise: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var exerciseId: String
    public var exerciseName: String
    public var order: Int
    public var supersetGroupId: String?
    /// goal from the originating routine; nil for an exercise added ad hoc
    public var target: ExerciseTarget?
    public var sets: [WorkoutSet]
}

/// `ExerciseTarget`.
public struct ExerciseTarget: Codable, Equatable, Sendable {
    public var sets: Int?
    public var repsMin: Int?
    public var repsMax: Int?
    /// the routine's rest for this exercise; nil = the user's default
    public var restSeconds: Int?

    public init(sets: Int?, repsMin: Int?, repsMax: Int?, restSeconds: Int? = nil) {
        self.sets = sets
        self.repsMin = repsMin
        self.repsMax = repsMax
        self.restSeconds = restSeconds
    }
}

/// `WorkoutSetItem`. `weightKg`/`rpe` are `Decimal` columns, already
/// converted to JSON numbers by the server.
public struct WorkoutSet: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var setNumber: Int
    public var weightKg: Double?
    public var reps: Int?
    public var rpe: Double?
    public var setType: String
    public var completedAt: Date
}

/// `PATCH /workouts/:id/finish` — `FinishedWorkout`: the detail plus a summary.
/// Decode-only: the app shows it once and never sends it back.
public struct FinishedWorkout: Decodable, Equatable, Sendable {
    public var detail: WorkoutDetail
    public var summary: WorkoutFinishSummary

    public init(from decoder: Decoder) throws {
        // flat on the wire (`{...detail, summary}`), nested here
        detail = try WorkoutDetail(from: decoder)
        summary = try decoder.container(keyedBy: CodingKeys.self).decode(WorkoutFinishSummary.self, forKey: .summary)
    }

    private enum CodingKeys: String, CodingKey { case summary }
}

/// `WorkoutFinishSummary` in server/src/workouts/workout-summary.ts.
public struct WorkoutFinishSummary: Codable, Equatable, Sendable {
    public var durationSec: Int
    public var volumeKg: Double
    public var setCount: Int
    public var exerciseCount: Int
    public var personalRecords: [WorkoutPersonalRecord]
}

/// `WorkoutPersonalRecord` — this workout's best set beating the old record.
public struct WorkoutPersonalRecord: Codable, Equatable, Sendable {
    public var exerciseId: String
    public var exerciseName: String
    public var weightKg: Double
    public var reps: Int?
    public var previousWeightKg: Double
    public var previousReps: Int?
}

// MARK: - Exercises

/// `GET /exercises` — paginated `ExerciseListItem`s.
public struct ExercisePage: Codable, Equatable, Sendable {
    public var items: [ExerciseListItem]
    public var total: Int
    public var page: Int
    public var limit: Int
}

/// `ExerciseListItem` in server/src/exercises/exercises.service.ts.
public struct ExerciseListItem: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var slug: String
    public var force: String?
    public var level: String?
    public var mechanic: String?
    public var equipment: String?
    public var primaryMuscles: [String]
    public var secondaryMuscles: [String]
    public var source: String
}

/// `GET /exercises/:id/last-performance` — `LastPerformance`, or an empty
/// body when the exercise was never done (the source of the set suggestions).
public struct LastPerformance: Codable, Equatable, Sendable {
    public var workoutId: String
    public var startedAt: Date
    public var sets: [LastPerformanceSet]
}

/// `LastPerformanceSet`.
public struct LastPerformanceSet: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var setNumber: Int
    public var weightKg: Double?
    public var reps: Int?
    public var rpe: Double?
    public var setType: String
}

// MARK: - Request bodies

/// `POST /workouts` — `parseStartWorkoutInput`. No template = free workout.
public struct StartWorkoutRequest: Codable, Equatable, Sendable {
    public var templateId: String?

    public init(templateId: String?) {
        self.templateId = templateId
    }
}

/// `POST /workouts/:id/exercises` — `parseAddExerciseInput`.
public struct AddExerciseRequest: Codable, Equatable, Sendable {
    public var exerciseId: String

    public init(exerciseId: String) {
        self.exerciseId = exerciseId
    }
}

/// `POST /workouts/:id/exercises/:weId/sets` — `parseAddSetInput`.
/// `clientId` makes a resend idempotent: keep the same one when retrying a
/// set that failed, a fresh one for each new set.
public struct AddSetRequest: Codable, Equatable, Sendable {
    public var weightKg: Double?
    public var reps: Int?
    public var rpe: Double?
    public var clientId: UUID

    public init(weightKg: Double?, reps: Int?, rpe: Double? = nil, clientId: UUID = UUID()) {
        self.weightKg = weightKg
        self.reps = reps
        self.rpe = rpe
        self.clientId = clientId
    }
}

/// `PATCH .../sets/:setId` — `parseSetInput`, a partial edit (nil = unchanged).
public struct UpdateSetRequest: Codable, Equatable, Sendable {
    public var weightKg: Double?
    public var reps: Int?
    public var rpe: Double?

    public init(weightKg: Double? = nil, reps: Int? = nil, rpe: Double? = nil) {
        self.weightKg = weightKg
        self.reps = reps
        self.rpe = rpe
    }
}
