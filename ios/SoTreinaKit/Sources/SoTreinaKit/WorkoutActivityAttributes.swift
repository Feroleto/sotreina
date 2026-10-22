import Foundation

#if canImport(ActivityKit)
import ActivityKit

/// Shared between the app (which starts/updates the Live Activity) and the
/// widget extension (which renders it) — both must see the exact same type.
/// No App Group needed: the app hands the state straight to ActivityKit.
public struct WorkoutActivityAttributes: ActivityAttributes {
    /// built (and tested) in WorkoutActivity.swift, free of ActivityKit
    public typealias ContentState = WorkoutActivitySnapshot

    public var workoutId: String
    public var workoutName: String

    public init(workoutId: String, workoutName: String) {
        self.workoutId = workoutId
        self.workoutName = workoutName
    }
}
#endif
