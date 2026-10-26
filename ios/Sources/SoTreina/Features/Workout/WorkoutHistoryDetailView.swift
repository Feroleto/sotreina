import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// Treino › Histórico › a finished workout (web WorkoutDetailPage): the date,
/// duration/volume/exercises/sets, and each exercise with its averages; a
/// row pushes its sets. Duration, volume and count come from the list row;
/// the sets from `GET /workouts/:id` (cached).
struct WorkoutHistoryDetailView: View {
    let item: WorkoutHistoryItem
    let store: GymHistoryStore
    @State private var detail: WorkoutDetail?
    @State private var failure: String?
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let lang = language.lang
        let unit = store.weightUnit
        List {
            Group {
                Text(verbatim: WorkoutFormat.longDate(item.startedAt, lang: lang))
                    .font(DSFont.meta)
                    .foregroundStyle(Color.mutedFg)
                    .padding(.top, 14)
                    .listRowSeparator(.hidden)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                    StatBox(label: Text("gym.history.detail.duration", bundle: .l10n), value: WorkoutFormat.durationShort(item.durationSec))
                    StatBox(label: Text("gym.history.detail.volume", bundle: .l10n), value: WorkoutFormat.volume(item.volumeKg, unit: unit, lang: lang))
                    StatBox(label: Text("gym.history.detail.exercises", bundle: .l10n), value: "\(item.exerciseCount)")
                    StatBox(label: Text("gym.history.detail.sets", bundle: .l10n), value: detail.map { "\($0.exercises.reduce(0) { $0 + $1.sets.count })" } ?? "—")
                }
                .padding(.top, 12)
                .listRowSeparator(.hidden)

                CapsTitle(Text("gym.history.detail.exercisesHeader", bundle: .l10n))
                    .padding(.top, 20)
                    .padding(.bottom, 8)
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }

                if let detail {
                    ForEach(Array(detail.exercises.enumerated()), id: \.element.id) { index, exercise in
                        NavigationLink {
                            ExerciseSessionDetailView(exercise: exercise, store: store)
                        } label: {
                            ExerciseSummaryRow(number: index + 1, exercise: exercise, unit: unit)
                        }
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    }
                } else if let failure {
                    Text(failure).font(DSFont.meta).foregroundStyle(Color.neg).padding(.vertical, 10)
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20).listRowSeparator(.hidden)
                }
            }
            .listRowInsets(EdgeInsets(top: 0, leading: pageGutter, bottom: 0, trailing: pageGutter))
            .listRowBackground(Color.pageBg)
        }
        .monolitoList()
        .navigationTitle(item.templateName.map { Text(verbatim: $0) } ?? Text("gym.freeWorkout", bundle: .l10n))
        .floatingTabBarSpace()
        .navigationBarTitleDisplayMode(.inline)
        .taskOnTabActivation {
            detail = detail ?? store.cachedWorkout(item.id)
            switch await store.workout(item.id) {
            case .success(let fresh): detail = fresh
            case .failure(let error): if detail == nil { failure = error.message }
            }
        }
    }
}

/// "1  Supino / 3 séries · 21,3 kg · 8 reps"
private struct ExerciseSummaryRow: View {
    let number: Int
    let exercise: WorkoutExercise
    let unit: WeightUnit
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let lang = language.lang
        let averages = SetStats.averages(exercise.sets)
        let weight = averages.weightKg.map { "\(WorkoutFormat.weight($0, unit: unit, lang: lang)) \(UnitConversion.label(unit))" } ?? "— \(UnitConversion.label(unit))"
        HStack(spacing: 12) {
            Text(verbatim: "\(number)")
                .font(DSFont.monoBody)
                .foregroundStyle(Color.mutedFg)
                .frame(width: 22, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.exerciseName)
                    .font(DSFont.row.weight(.semibold))
                    .foregroundStyle(Color.fg)
                    .lineLimit(1)
                Text(verbatim: L10n.string(
                    "gym.history.detail.summary %lld %@ %@", lang: lang,
                    exercise.sets.count, weight, averages.reps.map(String.init) ?? "—"
                ))
                .font(DSFont.caption)
                .foregroundStyle(Color.mutedFg)
            }
        }
        .padding(.vertical, 6)
    }
}

/// caps label over a bold value, bordered (`rounded-[12px] border`)
private struct StatBox: View {
    let label: Text
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            CapsTitle(label)
            Text(verbatim: value)
                .font(Font.geist(17, relativeTo: .headline).weight(.bold))
                .foregroundStyle(Color.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.border, lineWidth: 1)
        }
    }
}

/// Treino › Histórico › treino › an exercise (web ExerciseSessionDetailPage):
/// sets, volume and Epley 1RM of the best set, the sets one by one, the best
/// set and the routine's planned rep range.
struct ExerciseSessionDetailView: View {
    let exercise: WorkoutExercise
    let store: GymHistoryStore
    @State private var muscle: String?
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let lang = language.lang
        let unit = store.weightUnit
        let sets = exercise.sets
        let best = SetStats.best(sets)
        let oneRepMax: Double? = best.flatMap { set in
            guard let kg = set.weightKg, let reps = set.reps else { return nil }
            return SetStats.epley1RM(weightKg: kg, reps: reps)
        }

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(exercise.exerciseName)
                    .font(Font.geist(20, relativeTo: .title3).weight(.bold))
                    .foregroundStyle(Color.fg)
                if let muscle {
                    Chip(MuscleGroup.label(muscle, lang: lang)).padding(.top, 8)
                }

                HStack(spacing: 8) {
                    CenteredStat(label: Text("gym.history.sets.sets", bundle: .l10n), value: "\(sets.count)")
                    CenteredStat(label: Text("gym.history.sets.volume", bundle: .l10n), value: weight(SetStats.totalVolume(sets), unit, lang))
                    CenteredStat(label: Text("gym.history.sets.oneRm", bundle: .l10n), value: oneRepMax.map { weight($0, unit, lang) } ?? "—")
                }
                .padding(.top, 16)

                // `flex`: a fixed set column, then three equal ones, volume right-aligned
                VStack(spacing: 8) {
                    SetColumns(
                        set: CapsTitle(Text("gym.history.sets.columnSet", bundle: .l10n)),
                        weight: CapsTitle(Text("gym.history.sets.columnWeight", bundle: .l10n)),
                        reps: CapsTitle(Text("gym.history.sets.columnReps", bundle: .l10n)),
                        volume: CapsTitle(Text("gym.history.sets.columnVolume", bundle: .l10n))
                    )
                    ForEach(sets) { set in
                        SetColumns(
                            set: Text(verbatim: "\(set.setNumber)").fontWeight(.medium),
                            weight: Text(verbatim: set.weightKg.map { weight($0, unit, lang) } ?? "— \(UnitConversion.label(unit))"),
                            reps: Text(verbatim: set.reps.map(String.init) ?? "—"),
                            volume: Text(verbatim: weight(SetStats.volume(set), unit, lang)).foregroundStyle(Color.mutedFg)
                        )
                        .font(Font.geist(13, relativeTo: .subheadline))
                        .foregroundStyle(Color.fg)
                    }
                }
                .padding(.top, 20)

                CapsTitle(Text("gym.history.sets.otherInfo", bundle: .l10n))
                    .padding(.top, 22)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .bottom) { Hairline() }

                InfoLine(label: Text("gym.history.sets.bestSet", bundle: .l10n), value: best.map { set in
                    L10n.string(
                        "gym.history.sets.bestSetValue %lld %@ %@", lang: lang,
                        set.setNumber, set.weightKg.map { weight($0, unit, lang) } ?? "— \(UnitConversion.label(unit))",
                        set.reps.map(String.init) ?? "—"
                    )
                } ?? "—")
                InfoLine(label: Text("gym.history.sets.plannedReps", bundle: .l10n), value: exercise.target.map {
                    "\(RoutineFormat.repsRange(min: $0.repsMin, max: $0.repsMax)) reps"
                } ?? "—")
            }
            .padding(.horizontal, pageGutter)
            .padding(.top, 18)
            .padding(.bottom, 40)
        }
        .background(Color.pageBg)
        .navigationTitle(Text(exercise.exerciseName))
        .floatingTabBarSpace()
        .navigationBarTitleDisplayMode(.inline)
        .task { muscle = await store.exercise(exercise.exerciseId)?.primaryMuscles.first }
    }

    /// "20 kg" / "44,1 lb"
    private func weight(_ kg: Double, _ unit: WeightUnit, _ lang: Lang) -> String {
        "\(WorkoutFormat.weight(kg, unit: unit, lang: lang)) \(UnitConversion.label(unit))"
    }
}

/// one row of the sets table: set | weight | reps | volume
private struct SetColumns<A: View, B: View, C: View, D: View>: View {
    let set: A
    let weight: B
    let reps: C
    let volume: D

    var body: some View {
        HStack(spacing: 6) {
            set.frame(width: 36, alignment: .leading)
            weight.frame(maxWidth: .infinity, alignment: .leading)
            reps.frame(maxWidth: .infinity, alignment: .leading)
            volume.frame(maxWidth: .infinity, alignment: .trailing)
        }
        .lineLimit(1)
    }
}

/// value over label, centered (the three stat cards of the exercise)
private struct CenteredStat: View {
    let label: Text
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(verbatim: value)
                .font(Font.geist(15, relativeTo: .headline).weight(.semibold))
                .foregroundStyle(Color.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            label.font(DSFont.caption).foregroundStyle(Color.mutedFg).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .padding(.horizontal, 8)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.border, lineWidth: 1)
        }
    }
}

/// "Melhor série      #2 · 20 kg × 10 reps", over a hairline
private struct InfoLine: View {
    let label: Text
    let value: String

    var body: some View {
        HStack {
            label.foregroundStyle(Color.mutedFg)
            Spacer(minLength: 8)
            Text(verbatim: value).fontWeight(.medium).foregroundStyle(Color.fg)
        }
        .font(Font.geist(13, relativeTo: .subheadline))
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Hairline() }
    }
}
