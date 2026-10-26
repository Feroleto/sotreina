import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// Treino › Rotinas › rotina › an exercise (web RoutineExerciseDetailPage):
/// the dataset's photo, muscle and equipment chips, the routine's targets
/// next to the heaviest weight of the last time, and how to perform it in
/// the app's language. The library fetch is best-effort: each piece falls
/// back on its own, like the web.
struct RoutineExerciseDetailView: View {
    let exercise: TemplateExercise
    /// the routine's first muscle, for an exercise with none of its own
    let fallbackMuscle: String?
    let store: WorkoutStore
    @State private var detail: ExerciseDetail?
    @State private var loaded = false
    @State private var heaviestKg: Double?
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let lang = language.lang
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                photo

                Text(exercise.exerciseName)
                    .font(Font.geist(20, relativeTo: .title3).weight(.bold))
                    .foregroundStyle(Color.fg)
                    .padding(.top, 16)

                FlowLayout {
                    if let muscle = detail?.primaryMuscles.first ?? exercise.primaryMuscles.first ?? fallbackMuscle {
                        Chip(MuscleGroup.label(muscle, lang: lang))
                    }
                    // before the fetch answers, the fallback would flash in
                    if loaded { Chip(Equipment.label(detail?.equipment, lang: lang)) }
                }
                .padding(.top, 8)

                HStack(spacing: 8) {
                    StatCard(label: Text("gym.exerciseDetail.sets", bundle: .l10n), value: exercise.targetSets.map(String.init) ?? "—")
                    StatCard(
                        label: Text("gym.exerciseDetail.reps", bundle: .l10n),
                        value: RoutineFormat.repsRange(min: exercise.targetRepsMin, max: exercise.targetRepsMax)
                    )
                    StatCard(label: Text("gym.exerciseDetail.prevWeight", bundle: .l10n), value: previousWeight(lang))
                }
                .padding(.top, 16)

                CapsTitle(Text("gym.exerciseDetail.howTo", bundle: .l10n))
                    .padding(.top, 22)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .bottom) { Hairline() }

                if loaded {
                    Text(ExerciseDetail.instructionsText(detail?.instructions ?? [], lang: lang))
                        .font(Font.geist(14, relativeTo: .body))
                        .lineSpacing(6)
                        .foregroundStyle(Color.fg)
                        .padding(.top, 12)
                }
            }
            .padding(.horizontal, pageGutter)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(Color.pageBg)
        .navigationTitle(Text(exercise.exerciseName))
        .floatingTabBarSpace()
        .navigationBarTitleDisplayMode(.inline)
        .taskOnTabActivation {
            async let fetchedDetail = store.exerciseDetail(exercise.exerciseId)
            async let fetchedLast = store.lastPerformance(exerciseId: exercise.exerciseId)
            (detail, heaviestKg) = await (fetchedDetail, fetchedLast?.heaviestWeightKg)
            loaded = true
        }
    }

    /// the dataset's first photo; a plain tile while it loads, fails or
    /// doesn't exist (custom exercises have none)
    private var photo: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.chip)
            .frame(height: 200)
            .overlay {
                if let url = detail?.imageUrls.first {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }

    private func previousWeight(_ lang: Lang) -> String {
        guard let kg = heaviestKg else { return "—" }
        let unit = store.weightUnit
        return "\(WorkoutFormat.weight(kg, unit: unit, lang: lang)) \(UnitConversion.label(unit))"
    }
}

/// value over label, in a bordered box (`rounded-[12px] border`)
private struct StatCard: View {
    let label: Text
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(verbatim: value)
                .font(Font.geist(15, relativeTo: .headline).weight(.semibold))
                .foregroundStyle(Color.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            label
                .font(DSFont.caption)
                .foregroundStyle(Color.mutedFg)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .padding(.horizontal, 8)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.border, lineWidth: 1)
        }
    }
}
