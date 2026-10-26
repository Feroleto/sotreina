import Foundation
import Observation
import os
import SoTreinaKit

/// Plano da semana (spec .plans/plano-semanal-spec.md §6.2): the resolved
/// window, Monday of this week through Sunday of the next, from
/// `GET /plan/days`. Held by the shell, so Hoje and Treino read the same
/// days; loaded with the other stores on launch and every return to the
/// foreground, which also covers a day that turned at midnight (the window
/// is recomputed from today on every load).
@MainActor
@Observable
final class PlanStore {
    private(set) var days: [PlanDay] = []
    private(set) var loadState: WorkoutStore.LoadState = .idle
    private let session: SessionStore
    @ObservationIgnored private let log = Logger(subsystem: "com.feroleto.sotreina", category: "plan")
    /// a validation launch's fixed plan: never fetched
    @ObservationIgnored private var previewing = false

    init(session: SessionStore) {
        self.session = session
        #if DEBUG
        switch ValidationLaunch.current.destination {
        case .todayPlan(let restDay):
            previewing = true
            days = PlanPreview.days(today: Self.today(), restDay: restDay)
            loadState = .loaded
        case .planDaySheet:
            previewing = true
            days = PlanPreview.days(today: Self.today(), restDay: false)
            loadState = .loaded
        default: break
        }
        #endif
    }

    /// the user's local day, the one the server cuts by (`X-Time-Zone`)
    static func today(_ now: Date = .now) -> String {
        DietFormat.localDate(now, calendar: .current)
    }

    private static func query(_ range: PlanDate.Range) -> [URLQueryItem] {
        [URLQueryItem(name: "from", value: range.from), URLQueryItem(name: "to", value: range.to)]
    }

    /// The plan is active today: Hoje and Treino follow it.
    var isActiveToday: Bool { days.first { $0.date == Self.today() }?.active == true }

    func load() async {
        guard !previewing, let api = session.cachedAPI else { return }
        let range = PlanDate.window(today: Self.today())
        let query = Self.query(range)
        if loadState == .idle, let hit: ResponseCache.Hit<[PlanDay]> = api.cached("plan/days", query: query) {
            days = hit.value ?? []
            loadState = .loaded
        }
        if loadState != .loaded { loadState = .loading }
        do {
            days = try await api.get("plan/days", query: query) ?? []
            loadState = .loaded
        } catch {
            // keep what's on screen; without a plan Hoje works the old way,
            // so a failed first load is only logged
            if case APIError.unauthorized = error {
                session.expire()
                return
            }
            log.error("request failed: \(String(describing: error), privacy: .public)")
            if days.isEmpty { loadState = .failed(WorkoutStore.message(for: error, lang: AppLanguageStore.shared.lang)) }
        }
    }

    // MARK: Ajustes

    /// the last Ajuste that failed, shown once in the day sheet
    var actionError: String?
    @ObservationIgnored private var queueTail: Task<Void, Never>?

    /// One Ajuste from the day sheet (`PlanChange`): shown at once, sent in
    /// order behind any other (a late answer must not undo a newer tap), and
    /// the window the server answers replaces the guess. A failure puts the
    /// days back as they were before this change.
    func apply(_ change: PlanChange, templateNames: [String: String]) async {
        let before = days
        days = change.applied(to: days, templateNames: templateNames)
        actionError = nil
        guard !previewing else { return }
        let previous = queueTail
        let task = Task { @MainActor in
            await previous?.value
            do {
                let api = self.session.api
                let window: [PlanDay]? = switch change.route {
                case .day(let date, let body): try await api.put("plan/days/\(date)", body: body)
                case .move(let body): try await api.post("plan/moves", body: body)
                }
                if let window { self.merge(window) }
            } catch {
                if case APIError.unauthorized = error {
                    self.session.expire()
                    return
                }
                self.log.error("adjustment failed: \(String(describing: error), privacy: .public)")
                self.days = before
                self.actionError = WorkoutStore.message(for: error, lang: AppLanguageStore.shared.lang)
                // whatever got through before this one: the server knows
                await self.load()
            }
        }
        queueTail = task
        await task.value
    }

    /// The answer covers the editable window; keep any other day loaded.
    private func merge(_ window: [PlanDay]) {
        let fresh = Set(window.map(\.date))
        days = (days.filter { !fresh.contains($0.date) } + window).sorted { $0.date < $1.date }
        let range = PlanDate.window(today: Self.today())
        session.cachedAPI?.store(days, as: "plan/days", query: Self.query(range))
    }

    // MARK: Padrão

    /// `GET /plan`, loaded by the editor only.
    private(set) var pattern: WeekPattern?

    func loadPattern() async {
        guard let api = session.cachedAPI else { return }
        if pattern == nil, let hit: ResponseCache.Hit<WeekPattern> = api.cached("plan") { pattern = hit.value }
        do {
            pattern = try await api.get("plan")
        } catch {
            if case APIError.unauthorized = error { session.expire() }
            log.error("pattern load failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// `PUT /plan/pattern`: the version starting today. The days are refetched
    /// (the server answers with the pattern, not the window).
    func savePattern(_ request: PatternWriteRequest) async throws {
        do {
            guard let saved: WeekPattern = try await session.api.put("plan/pattern", body: request) else {
                throw APIError.invalidResponse
            }
            pattern = saved
            session.cachedAPI?.store(saved, as: "plan")
        } catch APIError.unauthorized {
            session.expire()
            throw APIError.unauthorized
        } catch {
            log.error("pattern save failed: \(String(describing: error), privacy: .public)")
            throw error
        }
        await load()
    }

    /// The next Treino by the plan (`PlanStatus.nextGym`); nil without an
    /// active plan today. A routine performed today means today's Treino is
    /// done (a free workout doesn't count here, it has no routine to rotate).
    func nextGym(templates: [TemplateSummary]) -> PlanStatus.NextGym? {
        let today = Self.today()
        let doneToday = templates.contains { $0.lastPerformedAt.map { Self.today($0) == today } ?? false }
        return PlanStatus.nextGym(days, templates: templates, today: today, doneToday: doneToday)
    }
}
