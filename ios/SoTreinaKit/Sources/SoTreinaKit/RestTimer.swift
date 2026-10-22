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
        /// a routine's per-exercise rest: ±15s on it doesn't touch the default
        public var overridden: Bool

        public init(endsAt: Date, duration: Int, overridden: Bool = false) {
            self.endsAt = endsAt
            self.duration = duration
            self.overridden = overridden
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            endsAt = try container.decode(Date.self, forKey: .endsAt)
            duration = try container.decode(Int.self, forKey: .duration)
            // absent in what builds before it persisted
            overridden = try container.decodeIfPresent(Bool.self, forKey: .overridden) ?? false
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

    /// `seconds` is a routine's per-exercise rest (`ExerciseTarget.restSeconds`):
    /// it runs for that long without becoming the default, so the next
    /// exercise without its own rest still gets the usual length — the same
    /// rule as the web's `startOverride`.
    public mutating func start(seconds: Int? = nil, now: Date = .now) {
        let length = seconds.map(Self.clamp) ?? duration
        active = Active(
            endsAt: now.addingTimeInterval(TimeInterval(length)),
            duration: length,
            overridden: seconds != nil
        )
    }

    /// `+15s`/`-15s`. Remaining time floors at zero, and the adjusted length
    /// becomes the next rest's default (so the next set already suggests it).
    public mutating func add(seconds: Int, now: Date = .now) {
        guard let current = active else { return }
        let endsAt = max(now, current.endsAt.addingTimeInterval(TimeInterval(seconds)))
        let remaining = Int(endsAt.timeIntervalSince(now).rounded())
        active = Active(
            endsAt: endsAt,
            duration: max(current.duration + seconds, remaining),
            overridden: current.overridden
        )
        if !current.overridden { duration = Self.clamp(remaining) }
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
