import Foundation
import Observation
import os
import SoTreinaDesign
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
        didSet {
            refreshLiveActivity()
            // every mutation answers with the whole workout: keep the cache on
            // it, so a relaunch never resurrects a finished or changed one
            session.cachedAPI?.store(active, as: "workouts/active")
            // a new or ended session always comes back full screen, except
            // the first one of a validation launch aimed at another screen
            if active?.id != oldValue?.id {
                sessionMinimized = active != nil && launchMinimizedPending
                if active != nil { launchMinimizedPending = false }
            }
        }
    }
    /// The open session folded into the bar above the tab bar (web:
    /// "minimizar" + ActiveWorkoutBar); it still runs, timer and all.
    var sessionMinimized = false
    private(set) var loadState: LoadState = .idle
    /// set while `POST /workouts` runs, so only that row shows a spinner
    private(set) var startingTemplateId: String?
    private(set) var pendingSets: [PendingSet] = [] {
        didSet { refreshLiveActivity() }
    }
    /// keyed by exerciseId; fetched once per exercise, again after a finish
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
    @ObservationIgnored private var restoredFromCache = false
    @ObservationIgnored private var launchMinimizedPending = ValidationLaunch.current.startsSessionMinimized
    /// mutations run one at a time: each answer is the whole workout, so two
    /// answers landing out of order would let the older one erase a set
    private var queueTail: Task<Void, Never>?

    init(session: SessionStore) {
        self.session = session
        rest.onChange = { [weak self] in self?.refreshLiveActivity() }
    }

    /// for every weight the session shows or reads (`UnitConversion`)
    var weightUnit: WeightUnit { session.weightUnit }

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
        guard let api = session.cachedAPI else { return }
        restoreFromCacheOnce(api)
        if templates.isEmpty, loadState != .loaded { loadState = .loading }
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

    /// First load only: show the last answers at once (spec §5.2); the fetch
    /// that follows replaces them. Later loads never re-read the cache — it
    /// would bring back a state the app has since moved past.
    private func restoreFromCacheOnce(_ api: CachedAPI) {
        guard !restoredFromCache else { return }
        restoredFromCache = true
        if let hit: ResponseCache.Hit<[TemplateSummary]> = api.cached("workout-templates") {
            templates = hit.value ?? []
            loadState = .loaded
        }
        if let hit: ResponseCache.Hit<WorkoutDetail> = api.cached("workouts/active") {
            active = hit.value
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

    // MARK: - Routine and exercise detail (read only)

    /// `GET /workout-templates/:id` — the per-exercise targets the summary
    /// list doesn't carry. Returns the error message to show, nil on a 401.
    func templateDetail(_ id: String) async -> Result<TemplateDetail, DetailError> {
        do {
            guard let detail: TemplateDetail = try await session.api.get("workout-templates/\(id)") else {
                return .failure(DetailError(message: Self.message(for: APIError.http(status: 404), lang: AppLanguageStore.shared.lang)))
            }
            return .success(detail)
        } catch {
            return .failure(DetailError(message: handle(error)))
        }
    }

    /// `GET /exercises/:id`. Best-effort, like the web: the exercise detail
    /// falls back field by field when it's missing.
    func exerciseDetail(_ id: String) async -> ExerciseDetail? {
        try? await session.api.get("exercises/\(id)")
    }

    /// "Peso anterior": the cached last performance when the session already
    /// fetched it, else a fresh fetch (not cached: it doesn't feed proposals).
    func lastPerformance(exerciseId: String) async -> LastPerformance? {
        if let cached = lastPerformance[exerciseId] { return cached }
        return try? await session.api.get("exercises/\(exerciseId)/last-performance")
    }

    /// `DELETE /workout-templates/:id`. Past workouts survive (their
    /// `templateId` goes null on the server). True when it's gone.
    func deleteTemplate(_ id: String) async -> Bool {
        do {
            try await session.api.deleteEmpty("workout-templates/\(id)")
            templates.removeAll { $0.id == id }
            log.notice("template deleted")
            await load()
            return true
        } catch {
            actionError = handle(error)
            return false
        }
    }

    // MARK: - Routine editor

    /// Salvar: `POST /workout-templates` (new) or `PATCH /workout-templates/:id`
    /// with the whole exercise list. Reloads the list so it shows the result.
    func saveTemplate(_ draft: RoutineDraft, id: String?) async -> Result<TemplateDetail, DetailError> {
        do {
            let saved: TemplateDetail? = if let id {
                try await session.api.patch("workout-templates/\(id)", body: draft.request)
            } else {
                try await session.api.post("workout-templates", body: draft.request)
            }
            guard let saved else {
                return .failure(DetailError(message: Self.message(for: APIError.http(status: 404), lang: AppLanguageStore.shared.lang)))
            }
            log.notice("template saved (\(id == nil ? "new" : "edit", privacy: .public))")
            await load()
            return .success(saved)
        } catch {
            return .failure(DetailError(message: handle(error)))
        }
    }

    /// The editor's picker: `GET /exercises`, matching the PT and English
    /// names, narrowed by a muscle chip (`?muscles=`, an OR).
    func searchExercises(_ query: String, filter: MuscleFilter) async throws -> [ExerciseListItem] {
        var items = [URLQueryItem(name: "limit", value: "50")]
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { items.append(URLQueryItem(name: "search", value: trimmed)) }
        if !filter.muscles.isEmpty { items.append(URLQueryItem(name: "muscles", value: filter.muscles.joined(separator: ","))) }
        do {
            let page: ExercisePage? = try await session.api.get("exercises", query: items)
            return page?.items ?? []
        } catch {
            if case APIError.unauthorized = error { session.expire() }
            throw error
        }
    }

    struct DetailError: Error {
        /// nil = the session expired (the app is going back to login)
        let message: String?
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

    /// Which dialog "Finalizar" opens: asks the server whether a templated
    /// workout drifted from its routine. A failed check falls back to the
    /// plain confirmation, like the web — finishing never gets stuck on it.
    func finishPrompt() async -> FinishPrompt {
        guard let workout = active else { return .confirm }
        guard FinishPrompt.needsDriftCheck(templateId: workout.templateId) else {
            return FinishPrompt.for(templateId: nil, diverged: nil)
        }
        isFinishing = true
        defer { isFinishing = false }
        let drift: TemplateDriftResponse? = try? await session.api.get("workouts/\(workout.id)/template-drift")
        return FinishPrompt.for(templateId: workout.templateId, diverged: drift?.diverged)
    }

    /// `syncTemplate` = the answer to "update the routine too?"
    func finish(syncTemplate: Bool = false) async {
        guard let id = active?.id, pendingSets.isEmpty else { return }
        isFinishing = true
        defer { isFinishing = false }
        await enqueue {
            do {
                let finished: FinishedWorkout? = try await self.session.api.patch(
                    "workouts/\(id)/finish", body: FinishWorkoutRequest(syncTemplate: syncTemplate)
                )
                self.lastFinished = finished
                self.active = nil
                // this workout is now everyone's "last time": the next one
                // must fetch it again, not propose from the one before
                self.lastPerformance = [:]
                self.lastPerformanceRequested = []
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
            rest: rest.timer.active, clientId: clientId, lang: AppLanguageStore.shared.lang,
            weightUnit: weightUnit
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
            // the "✓" opened the app: show the set landing in the session
            sessionMinimized = false
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
        return Self.message(for: error, lang: AppLanguageStore.shared.lang)
    }

    static func message(for error: Error, lang: Lang) -> String {
        switch error {
        case let urlError as URLError where urlError.code == .notConnectedToInternet
            || urlError.code == .networkConnectionLost
            || urlError.code == .timedOut:
            return L10n.string("app.error.offline", lang: lang)
        case APIError.http(let status) where status >= 500:
            return L10n.string("app.error.server %lld", lang: lang, status)
        case APIError.http(404):
            return L10n.string("app.error.notFound", lang: lang)
        default:
            return L10n.string("app.error.generic", lang: lang)
        }
    }
}
