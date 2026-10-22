import SwiftUI
import SoTreinaKit

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
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
        .animation(.default, value: rest.isRunning)
    }

    private func running(_ active: RestTimer.Active) -> some View {
        let range = active.endsAt.addingTimeInterval(-TimeInterval(active.duration))...active.endsAt
        return VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Descanso")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                // counts down on its own, no per-second re-render
                Text(timerInterval: range, countsDown: true)
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .monospacedDigit()
            }
            ProgressView(timerInterval: range, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            HStack(spacing: 10) {
                Button("−15s") { rest.add(seconds: -15) }
                    .buttonStyle(.bordered)
                Button("+15s") { rest.add(seconds: 15) }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Pular") { rest.skip() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var idle: some View {
        HStack {
            Image(systemName: "timer")
                .foregroundStyle(.secondary)
            Text("Descanso após cada série")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Menu {
                Picker("Descanso", selection: Binding(get: { rest.timer.duration }, set: { rest.setDuration($0) })) {
                    ForEach(presets, id: \.self) { seconds in
                        Text(WorkoutFormat.elapsed(seconds)).tag(seconds)
                    }
                }
            } label: {
                Text(WorkoutFormat.elapsed(rest.timer.duration))
                    .monospacedDigit()
                    .bold()
            }
        }
    }

    /// the presets, plus a remembered length that isn't one (left by ±15s)
    private var presets: [Int] {
        Array(Set(RestTimer.presets + [rest.timer.duration])).sorted()
    }
}
