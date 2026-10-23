import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// Bottom bar of the session. Resting: the countdown with −15s / +15s /
/// Pular. Idle: the length of the next rest, pickable from presets.
struct RestBar: View {
    let rest: RestTimerController

    var body: some View {
        Group {
            if let active = rest.timer.active {
                running(active)
            } else {
                idle
            }
        }
        .padding(.horizontal, pageGutter)
        .padding(.vertical, 12)
        .background(Color.pageBg)
        .overlay(alignment: .top) { Hairline() }
        .animation(.default, value: rest.isRunning)
    }

    private func running(_ active: RestTimer.Active) -> some View {
        let range = active.endsAt.addingTimeInterval(-TimeInterval(active.duration))...active.endsAt
        return VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("gym.rest.label", bundle: .l10n)
                    .font(DSFont.meta)
                    .foregroundStyle(Color.mutedFg)
                Spacer()
                // counts down on its own, no per-second re-render
                Text(timerInterval: range, countsDown: true)
                    .font(Font.geistMono(34, relativeTo: .title).weight(.medium))
                    .tracking(-1.2)
                    .monospacedDigit()
            }
            ProgressView(timerInterval: range, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(Color.acc)
            HStack(spacing: 8) {
                Button { rest.add(seconds: -15) } label: { Text(verbatim: "−15s") }
                    .buttonStyle(.chip)
                    .accessibilityLabel(Text("gym.rest.minus15", bundle: .l10n))
                Button { rest.add(seconds: 15) } label: { Text(verbatim: "+15s") }
                    .buttonStyle(.chip)
                    .accessibilityLabel(Text("gym.rest.plus15", bundle: .l10n))
                Spacer()
                Button { rest.skip() } label: { Text("gym.rest.skip", bundle: .l10n) }
                    .buttonStyle(.pill)
                    .accessibilityLabel(Text("gym.rest.skipLabel", bundle: .l10n))
            }
        }
    }

    private var idle: some View {
        HStack {
            Image(systemName: "timer")
                .foregroundStyle(Color.mutedFg)
            Text("gym.rest.afterEachSet", bundle: .l10n)
                .font(DSFont.meta)
                .foregroundStyle(Color.mutedFg)
            Spacer()
            Menu {
                Picker(selection: Binding(get: { rest.timer.duration }, set: { rest.setDuration($0) })) {
                    ForEach(presets, id: \.self) { seconds in
                        Text(WorkoutFormat.elapsed(seconds)).tag(seconds)
                    }
                } label: {
                    Text("gym.rest.label", bundle: .l10n)
                }
            } label: {
                Text(WorkoutFormat.elapsed(rest.timer.duration))
                    .font(Font.geistMono(15, relativeTo: .body).weight(.medium))
                    .foregroundStyle(Color.fg)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 32)
                    .background(Color.chip, in: Capsule())
            }
        }
    }

    /// the presets, plus a remembered length that isn't one (left by ±15s)
    private var presets: [Int] {
        Array(Set(RestTimer.presets + [rest.timer.duration])).sorted()
    }
}
