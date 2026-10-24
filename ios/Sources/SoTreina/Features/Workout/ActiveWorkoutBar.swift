import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// The minimized session (web ActiveWorkoutBar): what's running and for how
/// long; one tap brings the session back. Only the content: `FloatingTabBar`
/// puts it in a capsule of the bar's material, above the pill or beside its
/// circle.
struct ActiveWorkoutBar: View {
    let workout: WorkoutDetail
    let onResume: () -> Void
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        Button(action: onResume) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.acc)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("gym.activeBar.inProgress", bundle: .l10n)
                        .font(DSFont.caption)
                        .foregroundStyle(Color.mutedFg)
                    Text(workout.templateName ?? L10n.string("gym.freeWorkout", lang: language.lang))
                        .font(DSFont.row)
                        .foregroundStyle(Color.fg)
                        .lineLimit(1)
                }
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(WorkoutFormat.elapsed(Int(context.date.timeIntervalSince(workout.startedAt))))
                        .font(Font.geistMono(17, relativeTo: .body).weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(Color.fg)
                }
                Image(systemName: "chevron.up")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.mutedFg)
            }
            .padding(.leading, 20)
            .padding(.trailing, 18)
            .padding(.vertical, 10)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("gym.activeBar.resume", bundle: .l10n))
    }
}
