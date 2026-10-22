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
    // Activity isn't Sendable, so the main actor keeps only its id and the
    // @concurrent helpers below look it up where it's used.
    private var activityID: String?
    private var restEndsAt: Date?
    private let log = Logger(subsystem: "com.feroleto.sotreina", category: "live-activity")

    var isRunning: Bool { activityID != nil }

    init() {
        // pick up an activity left running by a previous app launch
        let running = Activity<WorkoutActivityAttributes>.activities.first
        activityID = running?.id
        restEndsAt = running?.content.state.restEndsAt
    }

    func startRest(seconds: TimeInterval) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            status = "Live Activities desativadas em Ajustes › SoTreina"
            return
        }
        let endsAt = Date.now.addingTimeInterval(seconds)
        let state = WorkoutActivityAttributes.ContentState(restEndsAt: endsAt, exerciseName: "Supino reto")

        if let activityID {
            restEndsAt = endsAt
            Task { await Self.update(id: activityID, state: state) }
            status = "Descanso reiniciado"
            return
        }

        do {
            activityID = try Activity.request(
                attributes: WorkoutActivityAttributes(workoutName: "Treino de teste"),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            ).id
            restEndsAt = endsAt
            status = "Live Activity iniciada — bloqueie a tela pra conferir"
            log.info("live activity started")
        } catch {
            status = "Falhou: \(error.localizedDescription)"
            log.error("Activity.request failed: \(String(describing: error), privacy: .public)")
        }
    }

    func addRest(seconds: TimeInterval) {
        guard let activityID else { return }
        let base = max(restEndsAt ?? .now, .now)
        let endsAt = base.addingTimeInterval(seconds)
        restEndsAt = endsAt
        let state = WorkoutActivityAttributes.ContentState(restEndsAt: endsAt, exerciseName: "Supino reto")
        Task { await Self.update(id: activityID, state: state) }
    }

    func end() async {
        guard let activityID else { return }
        await Self.end(id: activityID)
        self.activityID = nil
        restEndsAt = nil
        status = "Encerrada"
    }

    @concurrent
    private nonisolated static func update(id: String, state: WorkoutActivityAttributes.ContentState) async {
        let activity = Activity<WorkoutActivityAttributes>.activities.first { $0.id == id }
        await activity?.update(ActivityContent(state: state, staleDate: nil))
    }

    @concurrent
    private nonisolated static func end(id: String) async {
        let activity = Activity<WorkoutActivityAttributes>.activities.first { $0.id == id }
        await activity?.end(nil, dismissalPolicy: .immediate)
    }
}
