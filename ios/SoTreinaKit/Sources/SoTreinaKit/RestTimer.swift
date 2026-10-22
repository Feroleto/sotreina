import Foundation

/// The rest countdown between sets — a port of the web's `RestTimerEngine`
/// (client/src/features/gym/useRestTimer.ts). State is an absolute `endsAt`,
/// never a decrementing counter, so a suspended app or a relaunch can't
/// drift it. Persistence and notifications live in the app; this is pure.
public struct RestTimer: Equatable, Sendable {
    public struct Active: Codable, Equatable, Sendable {
        public var endsAt: Date
        /// the full length of this rest, for progress display
        public var duration: Int

        public init(endsAt: Date, duration: Int) {
            self.endsAt = endsAt
            self.duration = duration
        }
    }

    public static let defaultDuration = 90
    public static let durationRange = 15...600
    public static let presets = [60, 90, 120, 150, 180, 240]

    public private(set) var active: Active?
    /// what the next rest starts with; remembers the last adjustment, like the web
    public private(set) var duration: Int

    /// `restoring` is what was persisted; an already-elapsed rest (finished
    /// while the app was closed) is dropped instead of resurrected.
    public init(duration: Int? = nil, restoring active: Active? = nil, now: Date = .now) {
        self.duration = Self.clamp(duration ?? Self.defaultDuration)
        if let active, active.endsAt > now { self.active = active }
    }

    public func remaining(now: Date = .now) -> TimeInterval? {
        active.map { max(0, $0.endsAt.timeIntervalSince(now)) }
    }

    public func isFinished(now: Date = .now) -> Bool {
        active.map { $0.endsAt <= now } ?? false
    }

    public mutating func start(now: Date = .now) {
        active = Active(endsAt: now.addingTimeInterval(TimeInterval(duration)), duration: duration)
    }

    /// `+15s`/`-15s`. Remaining time floors at zero, and the adjusted length
    /// becomes the next rest's default (so the next set already suggests it).
    public mutating func add(seconds: Int, now: Date = .now) {
        guard let current = active else { return }
        let endsAt = max(now, current.endsAt.addingTimeInterval(TimeInterval(seconds)))
        let remaining = Int(endsAt.timeIntervalSince(now).rounded())
        active = Active(endsAt: endsAt, duration: max(current.duration + seconds, remaining))
        duration = Self.clamp(remaining)
    }

    public mutating func skip() {
        active = nil
    }

    public mutating func setDuration(_ seconds: Int) {
        duration = Self.clamp(seconds)
    }

    private static func clamp(_ seconds: Int) -> Int {
        min(max(seconds, durationRange.lowerBound), durationRange.upperBound)
    }
}
