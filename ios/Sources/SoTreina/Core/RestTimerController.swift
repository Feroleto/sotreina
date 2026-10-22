import Foundation
import Observation
import os
import SoTreinaKit
import UserNotifications

/// App side of the rest timer (spec §6.6): persists `RestTimer` across
/// relaunches and keeps one local notification scheduled for `endsAt` — so
/// the end of the rest is heard with the phone locked or the app closed.
@MainActor
@Observable
final class RestTimerController {
    private(set) var timer: RestTimer
    /// the Live Activity mirrors the rest; set by WorkoutStore
    @ObservationIgnored var onChange: (() -> Void)?

    private static let notificationId = "rest-timer"
    private static let durationKey = "restTimer.duration"
    private static let activeKey = "restTimer.active"
    private let log = Logger(subsystem: "com.feroleto.sotreina", category: "rest-timer")
    /// clears `active` when the countdown reaches zero with the app open
    private var expiry: Task<Void, Never>?

    init() {
        let defaults = UserDefaults.standard
        let stored = defaults.object(forKey: Self.durationKey) as? Int
        let active = defaults.data(forKey: Self.activeKey)
            .flatMap { try? JSONDecoder().decode(RestTimer.Active.self, from: $0) }
        timer = RestTimer(duration: stored, restoring: active)
        scheduleExpiry()
    }

    var isRunning: Bool { timer.active != nil }

    /// `seconds`: the routine's rest for this exercise, nil = the default
    func start(seconds: Int? = nil) {
        timer.start(seconds: seconds)
        changed()
    }

    func add(seconds: Int) {
        timer.add(seconds: seconds)
        changed()
    }

    func skip() {
        timer.skip()
        changed()
    }

    func setDuration(_ seconds: Int) {
        timer.setDuration(seconds)
        changed()
    }

    /// Asked on the first workout (spec §6.6) — a no-op once answered.
    func requestNotificationPermission() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            log.error("notification permission failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func changed() {
        persist()
        reschedule()
        scheduleExpiry()
        onChange?()
    }

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(timer.duration, forKey: Self.durationKey)
        if let active = timer.active, let data = try? JSONEncoder().encode(active) {
            defaults.set(data, forKey: Self.activeKey)
        } else {
            defaults.removeObject(forKey: Self.activeKey)
        }
    }

    /// One pending request at a time, replaced on every change (+15s moves it,
    /// Pular removes it).
    private func reschedule() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationId])
        guard let remaining = timer.remaining(), remaining > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Descanso acabou"
        content.body = "Hora da próxima série."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false)
        let request = UNNotificationRequest(identifier: Self.notificationId, content: content, trigger: trigger)
        center.add(request) { [log] error in
            if let error { log.error("schedule failed: \(String(describing: error), privacy: .public)") }
        }
    }

    private func scheduleExpiry() {
        expiry?.cancel()
        guard let active = timer.active else { return }
        expiry = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, active.endsAt.timeIntervalSinceNow)))
            guard !Task.isCancelled, let self, self.timer.active == active else { return }
            self.timer.skip()
            self.persist()
            self.onChange?()
        }
    }
}

/// Without a delegate iOS drops a notification that fires while the app is
/// in the foreground — exactly when the rest usually ends (phone in hand).
final class ForegroundNotificationPresenter: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = ForegroundNotificationPresenter()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
