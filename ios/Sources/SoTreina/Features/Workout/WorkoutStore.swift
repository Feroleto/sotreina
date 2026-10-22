import Foundation
import Observation
import os
import SoTreinaKit

/// Routines + the open workout — the app's counterpart of the web's
/// useActiveWorkout.ts. Every workout mutation answers with the full
/// `WorkoutDetail`, which replaces `active` wholesale (no partial patching).
@MainActor
@Observable
final class WorkoutStore {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    /// A set the server hasn't confirmed: in flight, or failed and waiting for
    /// a manual resend with the same `clientId` (spec §6.4 — no automatic
    /// queue; the backend dedupes on `clientId`, so a resend after a lost
    /// response can't duplicate it).
    struct PendingSet: Identifiable, Equatable {
        let clientId: UUID
        let workoutExerciseId: String
        var weightKg: Double?
        var reps: Int?
        var failed = false
        var id: UUID { clientId }
    }

    private(set) var templates: [TemplateSummary] = []
    private(set) var active: WorkoutDetail? {
        didSet { refreshLiveActivity() }
    }
    private(set) var loadState: LoadState = .idle
    /// set while `POST /workouts` runs, so only that row shows a spinner
    private(set) var startingTemplateId: String?
    private(set) var pendingSets: [PendingSet] = [] {
        didSet { refreshLiveActivity() }
    }
    /// keyed by exerciseId; fetched once per exercise per app run
    private(set) var lastPerformance: [String: LastPerformance] = [:] {
        didSet { refreshLiveActivity() }
    }
    /// the summary of the workout just finished, shown until dismissed
    private(set) var lastFinished: FinishedWorkout?
    private(set) var isFinishing = false
    /// a failed action; the screen itself stays usable
    var actionError: String?
    /// one rest countdown for the whole app, like the web's single useRestTimer
    let rest = RestTimerController()
    @ObservationIgnored private let liveActivity = LiveActivityController()
    /// the "✓" link's clientId per proposed set ("<workoutExerciseId>#<setNumber>"),
    /// stable across updates so a repeated or stale tap dedupes on the server
    @ObservationIgnored private var activityClientIds: [String: UUID] = [:]

    private let session: SessionStore
    private let log = Logger(subsystem: "com.feroleto.sotreina", category: "workout")
    private var lastPerformanceRequested: Set<String> = []
    /// mutations run one at a time: each answer is the whole workout, so two
    /// answers landing out of order would let the older one erase a set
    private var queueTail: Task<Void, Never>?

    init(session: SessionStore) {
        self.session = session
        rest.onChange = { [weak self] in self?.refreshLiveActivity() }
    }

    var nextRoutineId: String? { RoutineFormat.nextRoutine(templates)?.id }

    func pendingSets(for workoutExerciseId: String) -> [PendingSet] {
        pendingSets.filter { $0.workoutExerciseId == workoutExerciseId }
    }

    /// Finishing with an unconfirmed set would silently drop it.
    var canFinish: Bool { pendingSets.isEmpty && !isFinishing }

    // MARK: - Loading

    /// Launch and every return to the foreground: an open workout (started
    /// here or on the web) takes over the screen; edits made on the web
    /// meanwhile simply win (last write wins, accepted in the spec).
    func load() async {
        if templates.isEmpty { loadState = .loading }
        let api = session.api
        do {
            async let fetchedTemplates: [TemplateSummary]? = api.get("workout-templates")
            async let fetchedActive: WorkoutDetail? = api.get("workouts/active")
            (templates, active) = (try await fetchedTemplates ?? [], try await fetchedActive)
            if active == nil { pendingSets = [] }
            loadState = .loaded
        } catch {
            // keep whatever was on screen; only an empty first load shows the error
            if let message = handle(error), templates.isEmpty { loadState = .failed(message) }
        }
    }

    /// Feeds the set proposals. Best-effort: a failure only means no proposal.
    func loadLastPerformance(for exerciseIds: [String]) async {
        let missing = exerciseIds.filter { !lastPerformanceRequested.contains($0) }
        guard !missing.isEmpty else { return }
        lastPerformanceRequested.formUnion(missing)
        let api = session.api
        await withTaskGroup(of: (String, LastPerformance?).self) { group in
            for id in missing {
                group.addTask {
                    (id, try? await api.get("exercises/\(id)/last-performance") as LastPerformance?)
                }
            }
            for await (id, last) in group {
                if let last { lastPerformance[id] = last }
            }
        }
    }

    // MARK: - Starting and ending

    func start(templateId: String?) async {
        guard startingTemplateId == nil else { return }
        startingTemplateId = templateId ?? ""
        defer { startingTemplateId = nil }
        do {
            // idempotent on the server: an already-open workout is returned as is
            active = try await session.api.post("workouts", body: StartWorkoutRequest(templateId: templateId))
            log.notice("workout started from template \(templateId ?? "-", privacy: .public)")
        } catch {
            actionError = handle(error)
        }
    }

    /// `DELETE /workouts/:id` — throws the whole session away (sets cascade).
    func discard() async {
        guard let id = active?.id else { return }
        await enqueue {
            do {
                try await self.session.api.deleteEmpty("workouts/\(id)")
                self.active = nil
                self.rest.skip()
                self.pendingSets = []
                await self.load()
            } catch {
                self.actionError = self.handle(error)
            }
        }
    }

    func finish() async {
        guard let id = active?.id, pendingSets.isEmpty else { return }
        isFinishing = true
        defer { isFinishing = false }
        await enqueue {
            do {
                let finished: FinishedWorkout? = try await self.session.api.patch(
                    "workouts/\(id)/finish", body: EmptyBody()
                )
                self.lastFinished = finished
                self.active = nil
                self.rest.skip()
                self.log.notice("workout finished")
                await self.load()
            } catch {
                self.actionError = self.handle(error)
            }
        }
    }

    func dismissSummary() {
        lastFinished = nil
    }

    // MARK: - Sets

    func addSet(workoutExerciseId: String, weightKg: Double?, reps: Int?, clientId: UUID = UUID()) async {
        let pending = PendingSet(clientId: clientId, workoutExerciseId: workoutExerciseId, weightKg: weightKg, reps: reps)
        pendingSets.append(pending)
        // the rest starts on the tap, not on the server's answer: a slow or
        // failed request must not cost the athlete their rest timing
        let restSeconds = active?.exercises.first { $0.id == workoutExerciseId }?.target?.restSeconds
        rest.start(seconds: restSeconds)
        await send(pending)
    }

    /// Manual resend of a failed set — same `clientId`, so it can't duplicate.
    func retry(_ pending: PendingSet) async {
        guard let index = pendingSets.firstIndex(of: pending) else { return }
        pendingSets[index].failed = false
        await send(pendingSets[index])
    }

    func dropPending(_ pending: PendingSet) {
        pendingSets.removeAll { $0.id == pending.id }
    }

    private func send(_ pending: PendingSet) async {
        guard let workoutId = active?.id else { return }
        await enqueue {
            do {
                let body = AddSetRequest(weightKg: pending.weightKg, reps: pending.reps, clientId: pending.clientId)
                let detail: WorkoutDetail? = try await self.session.api.post(
                    "workouts/\(workoutId)/exercises/\(pending.workoutExerciseId)/sets", body: body
                )
                self.pendingSets.removeAll { $0.id == pending.id }
                if let detail { self.active = detail }
            } catch {
                if let index = self.pendingSets.firstIndex(where: { $0.id == pending.id }) {
                    self.pendingSets[index].failed = true
                }
                _ = self.handle(error)
            }
        }
    }

    func updateSet(workoutExerciseId: String, setId: String, weightKg: Double?, reps: Int?) async {
        await mutate(
            "PATCH set",
            path: "exercises/\(workoutExerciseId)/sets/\(setId)",
            method: .patch(UpdateSetRequest(weightKg: weightKg, reps: reps))
        )
    }

    func deleteSet(workoutExerciseId: String, setId: String) async {
        await mutate("DELETE set", path: "exercises/\(workoutExerciseId)/sets/\(setId)", method: .delete)
    }

    // MARK: - Exercises

    func addExercise(exerciseId: String) async {
        await mutate("POST exercise", path: "exercises", method: .post(AddExerciseRequest(exerciseId: exerciseId)))
    }

    func removeExercise(workoutExerciseId: String) async {
        pendingSets.removeAll { $0.workoutExerciseId == workoutExerciseId }
        await mutate("DELETE exercise", path: "exercises/\(workoutExerciseId)", method: .delete)
    }

    // MARK: - Live Activity

    /// Rebuilt on every change of the workout, the unconfirmed sets, the
    /// set proposals or the rest; the controller skips identical states.
    private func refreshLiveActivity() {
        guard let active else {
            liveActivity.sync(workout: nil, state: nil)
            activityClientIds = [:]
            return
        }
        let pending = pendingSets.map {
            WorkoutActivity.PendingSet(
                workoutExerciseId: $0.workoutExerciseId, weightKg: $0.weightKg, reps: $0.reps, failed: $0.failed
            )
        }
        let key = WorkoutActivity.cursor(in: active, pending: pending).map { "\($0.exercise.id)#\($0.setNumber)" } ?? ""
        let clientId = activityClientIds[key] ?? UUID()
        activityClientIds[key] = clientId
        let state = WorkoutActivity.snapshot(
            workout: active, pending: pending, lastPerformance: lastPerformance,
            rest: rest.timer.active, clientId: clientId
        )
        liveActivity.sync(workout: active, state: state)
    }

    /// A Live Activity button, opened as a `sotreina://` link (see ActivityLink).
    func handle(_ link: ActivityLink) async {
        log.notice("activity link \(String(describing: link), privacy: .public)")
        switch link {
        case .addRest(let seconds):
            rest.add(seconds: seconds)
        case .skipRest:
            rest.skip()
        case let .logSet(workoutId, workoutExerciseId, weightKg, reps, clientId):
            // a cold launch from the link: the workout may not be loaded yet
            if active?.id != workoutId { await load() }
            guard active?.id == workoutId,
                  active?.exercises.contains(where: { $0.id == workoutExerciseId }) == true,
                  !pendingSets.contains(where: { $0.clientId == clientId })
            else { return }
            await addSet(workoutExerciseId: workoutExerciseId, weightKg: weightKg, reps: reps, clientId: clientId)
        }
    }

    // MARK: - Plumbing

    private enum Method {
        case post(any Encodable & Sendable)
        case patch(any Encodable & Sendable)
        case delete
    }

    /// A `/workouts/:id/<path>` mutation whose answer replaces `active`.
    private func mutate(_ label: String, path: String, method: Method) async {
        guard let workoutId = active?.id else { return }
        let fullPath = "workouts/\(workoutId)/\(path)"
        await enqueue {
            do {
                let api = self.session.api
                let detail: WorkoutDetail? = switch method {
                case .post(let body): try await api.post(fullPath, body: body)
                case .patch(let body): try await api.patch(fullPath, body: body)
                case .delete: try await api.delete(fullPath)
                }
                if let detail { self.active = detail }
            } catch {
                self.log.error("\(label, privacy: .public) failed")
                self.actionError = self.handle(error)
                // the server is the source of truth: resync so the screen
                // doesn't keep showing an edit that didn't stick
                await self.load()
            }
        }
    }

    private func enqueue(_ operation: @escaping @MainActor () async -> Void) async {
        let previous = queueTail
        let task = Task { @MainActor in
            await previous?.value
            await operation()
        }
        queueTail = task
        await task.value
    }

    /// nil when the error was a 401 (the session store takes over the screen)
    private func handle(_ error: Error) -> String? {
        if case APIError.unauthorized = error {
            session.expire()
            return nil
        }
        log.error("request failed: \(String(describing: error), privacy: .public)")
        return Self.message(for: error)
    }

    static func message(for error: Error) -> String {
        switch error {
        case let urlError as URLError where urlError.code == .notConnectedToInternet
            || urlError.code == .networkConnectionLost
            || urlError.code == .timedOut:
            return "Sem conexão com a internet."
        case APIError.http(let status) where status >= 500:
            return "O servidor não respondeu (\(status)). Tente de novo."
        case APIError.http(404):
            return "Não encontrado — talvez tenha sido apagado na web."
        default:
            return "Algo deu errado. Tente de novo."
        }
    }
}

private struct EmptyBody: Encodable, Sendable {}
