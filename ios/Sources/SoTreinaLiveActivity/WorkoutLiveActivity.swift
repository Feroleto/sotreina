import ActivityKit
import SoTreinaKit
import SwiftUI
import WidgetKit

@main
struct SoTreinaWidgets: WidgetBundle {
    var body: some Widget {
        WorkoutLiveActivity()
    }
}

private let accent = Color(red: 0x39 / 255, green: 0x87 / 255, blue: 0xE5 / 255)

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            // lock screen / banner
            HStack(spacing: 14) {
                Image(systemName: "dumbbell.fill")
                    .font(.title2)
                    .foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.workoutName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(context.state.exerciseName)
                        .font(.headline)
                }
                Spacer()
                RestCountdown(endsAt: context.state.restEndsAt)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
            }
            .padding(16)
            .activityBackgroundTint(Color.black.opacity(0.6))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "dumbbell.fill")
                        .foregroundStyle(accent)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RestCountdown(endsAt: context.state.restEndsAt)
                        .font(.title2.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.exerciseName)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: "timer").foregroundStyle(accent)
            } compactTrailing: {
                RestCountdown(endsAt: context.state.restEndsAt)
                    .frame(maxWidth: 48)
            } minimal: {
                Image(systemName: "timer").foregroundStyle(accent)
            }
        }
    }
}

/// `Text(timerInterval:)` ticks on its own — the app doesn't need to be
/// running (or push updates) for the countdown to advance.
private struct RestCountdown: View {
    let endsAt: Date?

    var body: some View {
        if let endsAt, endsAt > .now {
            Text(timerInterval: Date.now...endsAt, countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        } else {
            Text("Série")
        }
    }
}
