import SwiftUI
import SoTreinaKit

/// After "Finalizar" (spec §6.4, tela 4): the `summary` of
/// `PATCH /workouts/:id/finish`. A plain list — the web's celebration
/// animations stay on the web.
struct WorkoutSummaryView: View {
    let finished: FinishedWorkout
    let onDone: () -> Void

    private var summary: WorkoutFinishSummary { finished.summary }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.tint)
                        Text(finished.detail.templateName ?? "Treino livre")
                            .font(.title3.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section {
                    LabeledContent("Duração", value: WorkoutFormat.durationShort(summary.durationSec))
                    LabeledContent("Volume", value: "\(WorkoutFormat.volume(summary.volumeKg)) kg")
                    LabeledContent("Séries", value: "\(summary.setCount)")
                    LabeledContent("Exercícios", value: "\(summary.exerciseCount)")
                }
                .monospacedDigit()

                if !summary.personalRecords.isEmpty {
                    Section(summary.personalRecords.count == 1 ? "Recorde pessoal" : "Recordes pessoais") {
                        ForEach(summary.personalRecords, id: \.exerciseId) { record in
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(record.exerciseName)
                                    Text("antes: \(WorkoutFormat.set(weightKg: record.previousWeightKg, reps: record.previousReps))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(WorkoutFormat.set(weightKg: record.weightKg, reps: record.reps))
                                    .monospacedDigit()
                                    .bold()
                                Text("PR")
                                    .font(.caption2.weight(.heavy))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(.tint.opacity(0.15), in: Capsule())
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Treino concluído")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button(action: onDone) {
                    Text("Concluir").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
            }
        }
    }
}
