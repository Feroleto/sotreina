import Foundation

/// What the workout's Live Activity shows (spec §6.7) — it *is* the
/// ActivityKit `ContentState` (see WorkoutActivityAttributes), kept free of
/// ActivityKit so it's built and tested here on Linux.
public struct WorkoutActivitySnapshot: Codable, Hashable, Sendable {
    /// nil while the workout has no exercise yet
    public var exerciseName: String?
    public var workoutExerciseId: String?
    /// the set about to be done ("Série 2 de 3")
    public var setNumber: Int
    public var targetSets: Int?
    public var restEndsAt: Date?
    /// full length of the running rest, for the progress bar
    public var restDuration: Int?
    public var proposal: SetProposal?
    /// a set failed to reach the server: the activity shows ⚠
    public var hasFailedSet: Bool
    /// the "✓" link, carrying the proposal and a stable clientId
    public var logSetURL: URL?

    public var isResting: Bool { restEndsAt != nil }

    /// the app's language: the extension runs in another process and can't
    /// read the app's setting, so it travels with the state. Optional so a
    /// state saved by an older build still decodes (nil reads as PT)
    public var lang: Lang?

    /// the user's weight unit, for the same reason as `lang` (nil reads as
    /// kg). Display only: the proposal and the "✓" link stay in kg
    public var weightUnit: WeightUnit? = nil

    /// "20 kg × 5" / "45 lb × 5": the proposal as the activity shows it
    public var proposalText: String? {
        proposal.map { WorkoutFormat.set(weightKg: $0.weightKg, reps: $0.reps, unit: weightUnit ?? .kg, lang: lang ?? .pt) }
    }

    /// "Série 2 de 3", or "Série 4" without a target / past it
    public var setLabel: String {
        let pt = (lang ?? .pt) == .pt
        let word = pt ? "Série" : "Set"
        let of = pt ? "de" : "of"
        if let targetSets, setNumber <= targetSets { return "\(word) \(setNumber) \(of) \(targetSets)" }
        return "\(word) \(setNumber)"
    }
}

public enum WorkoutActivity {
    /// A set the app holds but the server hasn't confirmed (in order).
    public struct PendingSet: Sendable {
        public var workoutExerciseId: String
        public var weightKg: Double?
        public var reps: Int?
        public var failed: Bool

        public init(workoutExerciseId: String, weightKg: Double?, reps: Int?, failed: Bool) {
            self.workoutExerciseId = workoutExerciseId
            self.weightKg = weightKg
            self.reps = reps
            self.failed = failed
        }
    }

    /// The exercise being worked on and its next set number. Stays on the
    /// exercise of the latest set until the lifter marks it done
    /// (`completedAt`; the target is only a guide), then moves to the first
    /// exercise (in order) still open. When everything is done it stays on
    /// the last one touched.
    public static func cursor(
        in workout: WorkoutDetail,
        pending: [PendingSet]
    ) -> (exercise: WorkoutExercise, setNumber: Int)? {
        let exercises = workout.exercises.sorted { $0.order < $1.order }
        guard !exercises.isEmpty else { return nil }

        func count(_ exercise: WorkoutExercise) -> Int {
            exercise.sets.count + pending.filter { $0.workoutExerciseId == exercise.id }.count
        }
        func isDone(_ exercise: WorkoutExercise) -> Bool { exercise.completedAt != nil }

        let latestLogged = exercises
            .compactMap { exercise in exercise.sets.map(\.completedAt).max().map { (exercise, $0) } }
            .max { $0.1 < $1.1 }?.0
        let lastTouched = pending.last.flatMap { item in exercises.first { $0.id == item.workoutExerciseId } }
            ?? latestLogged

        let current: WorkoutExercise
        if let lastTouched, !isDone(lastTouched) {
            current = lastTouched
        } else if let next = exercises.first(where: { !isDone($0) }) {
            current = next
        } else {
            current = lastTouched ?? exercises[0]
        }
        return (current, count(current) + 1)
    }

    public static func snapshot(
        workout: WorkoutDetail,
        pending: [PendingSet],
        lastPerformance: [String: LastPerformance],
        rest: RestTimer.Active?,
        clientId: UUID,
        lang: Lang = .pt,
        weightUnit: WeightUnit = .kg,
        now: Date = .now
    ) -> WorkoutActivitySnapshot {
        let restRunning = rest.flatMap { $0.endsAt > now ? $0 : nil }
        guard let (exercise, setNumber) = cursor(in: workout, pending: pending) else {
            return WorkoutActivitySnapshot(
                exerciseName: nil, workoutExerciseId: nil, setNumber: 1, targetSets: nil,
                restEndsAt: restRunning?.endsAt, restDuration: restRunning?.duration, proposal: nil,
                hasFailedSet: pending.contains { $0.failed }, logSetURL: nil, lang: lang, weightUnit: weightUnit
            )
        }

        let previous = pending.last { $0.workoutExerciseId == exercise.id }.map { ($0.weightKg, $0.reps) }
            ?? exercise.sets.max { $0.setNumber < $1.setNumber }.map { ($0.weightKg, $0.reps) }
        let proposal = SetProposal.propose(
            setNumber: setNumber,
            lastPerformance: lastPerformance[exercise.exerciseId],
            previousInWorkout: previous.map { (weightKg: $0.0, reps: $0.1) }
        )
        let logSetURL = proposal.map {
            ActivityLink.logSet(
                workoutId: workout.id, workoutExerciseId: exercise.id,
                weightKg: $0.weightKg, reps: $0.reps, clientId: clientId
            ).url
        }

        return WorkoutActivitySnapshot(
            exerciseName: exercise.exerciseName,
            workoutExerciseId: exercise.id,
            setNumber: setNumber,
            targetSets: exercise.target?.sets,
            restEndsAt: restRunning?.endsAt,
            restDuration: restRunning?.duration,
            proposal: proposal,
            hasFailedSet: pending.contains { $0.failed },
            logSetURL: logSetURL,
            lang: lang,
            weightUnit: weightUnit
        )
    }
}

/// The Live Activity's buttons. Its intent buttons would need AppIntents
/// metadata that xtool can't generate (Xcode-only build step), so every
/// button is a link that opens the app on this URL and the app does the
/// action — at the cost of a Face ID unlock on the lock screen.
public enum ActivityLink: Equatable, Sendable {
    case addRest(seconds: Int)
    case skipRest
    /// `clientId` is fixed per proposed set, so tapping the same "✓" twice
    /// (or a stale one) dedupes on the server instead of logging it twice.
    case logSet(workoutId: String, workoutExerciseId: String, weightKg: Double?, reps: Int?, clientId: UUID)

    public static let scheme = "sotreina"

    public var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        switch self {
        case .addRest(let seconds):
            components.host = "rest"
            components.path = "/add"
            components.queryItems = [URLQueryItem(name: "seconds", value: String(seconds))]
        case .skipRest:
            components.host = "rest"
            components.path = "/skip"
        case let .logSet(workoutId, workoutExerciseId, weightKg, reps, clientId):
            components.host = "set"
            components.path = "/log"
            components.queryItems = [
                URLQueryItem(name: "workout", value: workoutId),
                URLQueryItem(name: "exercise", value: workoutExerciseId),
                weightKg.map { URLQueryItem(name: "weight", value: String($0)) },
                reps.map { URLQueryItem(name: "reps", value: String($0)) },
                URLQueryItem(name: "client", value: clientId.uuidString),
            ].compactMap { $0 }
        }
        return components.url!
    }

    public init?(url: URL) {
        guard url.scheme == Self.scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }
        let query = Dictionary(
            (components.queryItems ?? []).compactMap { item in item.value.map { (item.name, $0) } },
            uniquingKeysWith: { first, _ in first }
        )
        switch (components.host, components.path) {
        case ("rest", "/add"):
            guard let seconds = query["seconds"].flatMap(Int.init) else { return nil }
            self = .addRest(seconds: seconds)
        case ("rest", "/skip"):
            self = .skipRest
        case ("set", "/log"):
            guard let workoutId = query["workout"], let exerciseId = query["exercise"],
                  let clientId = query["client"].flatMap(UUID.init(uuidString:))
            else { return nil }
            let weightKg = query["weight"].flatMap(Double.init)
            let reps = query["reps"].flatMap(Int.init)
            guard weightKg != nil || reps != nil else { return nil }
            self = .logSet(
                workoutId: workoutId, workoutExerciseId: exerciseId,
                weightKg: weightKg, reps: reps, clientId: clientId
            )
        default:
            return nil
        }
    }
}
