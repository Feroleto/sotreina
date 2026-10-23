import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// After "Finalizar" (spec §6.4, tela 4): the `summary` of
/// `PATCH /workouts/:id/finish`. Static — the web's celebration animations
/// stay on the web.
struct WorkoutSummaryView: View {
    let finished: FinishedWorkout
    let onDone: () -> Void
    @Environment(AppLanguageStore.self) private var language

    private var summary: WorkoutFinishSummary { finished.summary }

    var body: some View {
        let lang = language.lang
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(finished.detail.templateName ?? L10n.string("gym.freeWorkout", lang: lang))
                        .font(DSFont.meta)
                        .foregroundStyle(Color.mutedFg)
                    BigNumber(WorkoutFormat.durationShort(summary.durationSec))
                        .padding(.top, 18)

                    KPIStrip([
                        KPI(L10n.string("gym.summary.volume", lang: lang), "\(WorkoutFormat.volume(summary.volumeKg, lang: lang)) kg"),
                        KPI(L10n.string("gym.summary.sets", lang: lang), "\(summary.setCount)"),
                        KPI(L10n.string("gym.summary.exercises", lang: lang), "\(summary.exerciseCount)"),
                    ])
                    .padding(.top, 22)

                    if !summary.personalRecords.isEmpty {
                        SectionTitle(L10n.string("gym.summary.prTitle %lld", lang: lang, summary.personalRecords.count))
                            .padding(.top, 24)
                            .padding(.bottom, 4)
                        ForEach(summary.personalRecords, id: \.exerciseId) { record in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(record.exerciseName)
                                        .font(DSFont.row)
                                    Text("gym.summary.prFrom \(WorkoutFormat.set(weightKg: record.previousWeightKg, reps: record.previousReps, lang: lang))", bundle: .l10n)
                                        .font(DSFont.caption)
                                        .foregroundStyle(Color.mutedFg)
                                }
                                Spacer()
                                Text(WorkoutFormat.set(weightKg: record.weightKg, reps: record.reps, lang: lang))
                                    .font(Font.geistMono(15, relativeTo: .body).weight(.medium))
                                Badge("PR")
                            }
                            .padding(.vertical, 13)
                            .overlay(alignment: .bottom) { Hairline() }
                        }
                    }
                }
                .padding(.horizontal, pageGutter)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.pageBg)
            .navigationTitle(Text("gym.summary.title", bundle: .l10n))
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button(action: onDone) { Text("gym.summary.done", bundle: .l10n) }
                    .buttonStyle(.primary)
                    .padding(.horizontal, pageGutter)
                    .padding(.bottom, 8)
            }
        }
    }
}
