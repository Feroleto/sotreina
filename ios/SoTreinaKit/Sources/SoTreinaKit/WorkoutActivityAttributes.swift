import Foundation

#if canImport(ActivityKit)
import ActivityKit

/// Shared between the app (which starts/updates the Live Activity) and the
/// widget extension (which renders it) — both must see the exact same type.
/// No App Group needed: the app hands the state straight to ActivityKit.
public struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        /// `nil` = mid-set (no rest running)
        public var restEndsAt: Date?
        public var exerciseName: String

        public init(restEndsAt: Date?, exerciseName: String) {
            self.restEndsAt = restEndsAt
            self.exerciseName = exerciseName
        }
    }

    public var workoutName: String

    public init(workoutName: String) {
        self.workoutName = workoutName
    }
}
#endif
