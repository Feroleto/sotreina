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

/// The open workout on the lock screen and in the Dynamic Island (spec §6.7):
/// exercise, "Série N de M", the rest countdown and the proposed set. The
/// buttons are `sotreina://` links (ActivityLink) that open the app on the
/// action — intent buttons would need AppIntents metadata xtool can't build.
struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenView(context: context)
                .padding(16)
                .activityBackgroundTint(Color.black.opacity(0.65))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            let resting = isResting(context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(state.setLabel, systemImage: "dumbbell.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if resting, let endsAt = state.restEndsAt {
                        Countdown(endsAt: endsAt)
                            .font(.title2.weight(.semibold))
                            .padding(.trailing, 4)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(state.exerciseName ?? context.attributes.workoutName)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ActionRow(state: state, resting: resting)
                        .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: resting ? "timer" : "dumbbell.fill")
                    .foregroundStyle(accent)
            } compactTrailing: {
                if resting, let endsAt = state.restEndsAt {
                    Countdown(endsAt: endsAt)
                        .frame(maxWidth: 46)
                } else {
                    Text("S\(state.setNumber)")
                        .monospacedDigit()
                }
            } minimal: {
                Image(systemName: resting ? "timer" : "dumbbell.fill")
                    .foregroundStyle(accent)
            }
        }
    }
}

/// The rest is over once `restEndsAt` passes; the app marks the content
/// stale at that moment (it can't push an update while suspended).
private func isResting(_ context: ActivityViewContext<WorkoutActivityAttributes>) -> Bool {
    context.state.isResting && !context.isStale
}

private struct LockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        let state = context.state
        let resting = isResting(context)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(accent)
                Text(context.attributes.workoutName)
                    .foregroundStyle(.secondary)
                Spacer()
                if state.hasFailedSet {
                    Label("Série não enviada", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } else if state.exerciseName != nil {
                    Text(state.setLabel)
                        .bold()
                }
            }
            .font(.caption)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.exerciseName ?? "Adicione um exercício no app")
                        .font(.headline)
                        .lineLimit(1)
                    if let proposal = state.proposal {
                        Text("Próxima: \(WorkoutFormat.set(weightKg: proposal.weightKg, reps: proposal.reps))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if resting, let endsAt = state.restEndsAt {
                    Countdown(endsAt: endsAt)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                } else {
                    Text("Em série")
                        .font(.title3.weight(.semibold))
                }
            }

            if resting, let endsAt = state.restEndsAt, let duration = state.restDuration {
                ProgressView(
                    timerInterval: endsAt.addingTimeInterval(-TimeInterval(duration))...endsAt,
                    countsDown: true
                ) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(accent)
            }

            ActionRow(state: state, resting: resting)
        }
    }
}

/// Resting: +15s and Pular; always (when there's a proposal): "✓ 20 kg × 5".
private struct ActionRow: View {
    let state: WorkoutActivitySnapshot
    let resting: Bool

    var body: some View {
        HStack(spacing: 8) {
            if resting {
                LinkButton(title: "+15s", url: ActivityLink.addRest(seconds: 15).url, prominent: false)
                LinkButton(title: "Pular", url: ActivityLink.skipRest.url, prominent: false)
            }
            Spacer(minLength: 0)
            if let url = state.logSetURL, let proposal = state.proposal {
                LinkButton(
                    title: "✓ \(WorkoutFormat.set(weightKg: proposal.weightKg, reps: proposal.reps))",
                    url: url,
                    prominent: true
                )
            }
        }
    }
}

private struct LinkButton: View {
    let title: String
    let url: URL
    let prominent: Bool

    var body: some View {
        Link(destination: url) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(prominent ? accent : Color.white.opacity(0.18), in: Capsule())
                .foregroundStyle(.white)
        }
    }
}

/// `Text(timerInterval:)` ticks on its own — no app update per second.
private struct Countdown: View {
    let endsAt: Date

    var body: some View {
        Text(timerInterval: Date.now...max(endsAt, .now), countsDown: true)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
    }
}
