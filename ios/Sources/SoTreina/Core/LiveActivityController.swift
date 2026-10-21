import ActivityKit
import Foundation
import Observation
import os
import SoTreinaKit

/// Fase 0 spike: start / extend / end one rest-timer Live Activity.
@MainActor
@Observable
final class LiveActivityController {
    private(set) var status: String?
    private var activity: Activity<WorkoutActivityAttributes>?
    private var restEndsAt: Date?
    private let log = Logger(subsystem: "com.feroleto.sotreina", category: "live-activity")

    var isRunning: Bool { activity != nil }

    init() {
        // pick up an activity left running by a previous app launch
        activity = Activity<WorkoutActivityAttributes>.activities.first
        restEndsAt = activity?.content.state.restEndsAt
    }

    func startRest(seconds: TimeInterval) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            status = "Live Activities desativadas em Ajustes › SoTreina"
            return
        }
        let endsAt = Date.now.addingTimeInterval(seconds)
        let state = WorkoutActivityAttributes.ContentState(restEndsAt: endsAt, exerciseName: "Supino reto")

        if let activity {
            restEndsAt = endsAt
            Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
            status = "Descanso reiniciado"
            return
        }

        do {
            activity = try Activity.request(
                attributes: WorkoutActivityAttributes(workoutName: "Treino de teste"),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
            restEndsAt = endsAt
            status = "Live Activity iniciada — bloqueie a tela pra conferir"
            log.info("live activity started")
        } catch {
            status = "Falhou: \(error.localizedDescription)"
            log.error("Activity.request failed: \(String(describing: error), privacy: .public)")
        }
    }

    func addRest(seconds: TimeInterval) {
        guard let activity else { return }
        let base = max(restEndsAt ?? .now, .now)
        let endsAt = base.addingTimeInterval(seconds)
        restEndsAt = endsAt
        let state = WorkoutActivityAttributes.ContentState(restEndsAt: endsAt, exerciseName: "Supino reto")
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    func end() async {
        guard let activity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        self.activity = nil
        restEndsAt = nil
        status = "Encerrada"
    }
}
