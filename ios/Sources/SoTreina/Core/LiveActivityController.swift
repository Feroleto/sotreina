import ActivityKit
import Foundation
import os
import SoTreinaDesign
import SoTreinaKit

/// Keeps one Live Activity per open workout (spec §6.7) in step with the
/// app's state: started with the workout, updated on every change, ended on
/// finish/cancel. ActivityKit counts the rest down by itself, so updates are
/// only needed when something actually changes.
@MainActor
final class LiveActivityController {
    // Activity isn't Sendable, so the main actor keeps only ids and state;
    // the @concurrent helpers below look the activity up where it's used.
    private var activityID: String?
    private var workoutID: String?
    private var lastState: WorkoutActivitySnapshot?
    private let log = Logger(subsystem: "com.feroleto.sotreina", category: "live-activity")

    init() {
        // pick up the activity left running by a previous launch
        if let running = Activity<WorkoutActivityAttributes>.activities.first {
            activityID = running.id
            workoutID = running.attributes.workoutId
            lastState = running.content.state
        }
    }

    /// nil workout = none open: end whatever is showing.
    func sync(workout: WorkoutDetail?, state: WorkoutActivitySnapshot?) {
        guard let workout, let state else {
            endAll()
            return
        }
        if workoutID != workout.id {
            // the old ones by id: ending "all" asynchronously could also
            // catch the one being started here
            let stale = Activity<WorkoutActivityAttributes>.activities.map(\.id)
            start(workout: workout, state: state)
            Task { await Self.end(ids: stale) }
        } else if let activityID, state != lastState {
            lastState = state
            Task { await Self.update(id: activityID, state: state) }
        }
    }

    private func start(workout: WorkoutDetail, state: WorkoutActivitySnapshot) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            log.notice("live activities disabled in Settings")
            return
        }
        do {
            let activity = try Activity.request(
                attributes: WorkoutActivityAttributes(
                    workoutId: workout.id,
                    workoutName: workout.templateName ?? L10n.string("gym.freeWorkout", lang: AppLanguageStore.current)
                ),
                content: Self.content(state),
                pushType: nil
            )
            activityID = activity.id
            workoutID = workout.id
            lastState = state
            log.notice("live activity started")
        } catch {
            log.error("Activity.request failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func endAll() {
        let ids = Activity<WorkoutActivityAttributes>.activities.map(\.id)
        activityID = nil
        workoutID = nil
        lastState = nil
        guard !ids.isEmpty else { return }
        Task { await Self.end(ids: ids) }
    }

    /// Stale when the rest ends: the system re-renders it as "em série" even
    /// with the app suspended and unable to push that update itself.
    private nonisolated static func content(_ state: WorkoutActivitySnapshot) -> ActivityContent<WorkoutActivitySnapshot> {
        ActivityContent(state: state, staleDate: state.restEndsAt)
    }

    @concurrent
    private nonisolated static func update(id: String, state: WorkoutActivitySnapshot) async {
        let activity = Activity<WorkoutActivityAttributes>.activities.first { $0.id == id }
        await activity?.update(content(state))
    }

    /// Logout: no controller instance needed (the workout screen is gone).
    static func endEverything() {
        let ids = Activity<WorkoutActivityAttributes>.activities.map(\.id)
        guard !ids.isEmpty else { return }
        Task { await end(ids: ids) }
    }

    @concurrent
    private nonisolated static func end(ids: [String]) async {
        for activity in Activity<WorkoutActivityAttributes>.activities where ids.contains(activity.id) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
