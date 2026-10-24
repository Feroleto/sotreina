import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// Treino › Rotinas › a routine, read only (web RoutineDetailPage): muscle
/// chips, count and last time, the exercises with their targets (each opens
/// its detail) and "Iniciar treino". Editar and Excluir (behind a
/// confirmation) live in the navigation bar.
struct RoutineDetailView: View {
    let template: TemplateSummary
    let store: WorkoutStore
    @State private var state: DetailState = .loading
    @State private var confirmingDelete = false
    @State private var deleting = false
    @State private var editing: TemplateDetail?
    @Environment(\.dismiss) private var dismiss
    @Environment(AppLanguageStore.self) private var language

    private enum DetailState {
        case loading
        case loaded(TemplateDetail)
        case failed(String)
    }

    /// the list's copy, kept fresh by its reloads (e.g. "última vez" after a workout)
    private var summary: TemplateSummary { store.templates.first { $0.id == template.id } ?? template }

    var body: some View {
        let lang = language.lang
        List {
            Group {
                VStack(alignment: .leading, spacing: 10) {
                    if !summary.muscleGroups.isEmpty {
                        FlowLayout {
                            ForEach(summary.muscleGroups, id: \.self) { Chip(MuscleGroup.label($0, lang: lang)) }
                        }
                    }
                    Text(verbatim: "\(L10n.string("gym.routines.exerciseCount %lld", lang: lang, summary.exerciseCount)) · \(lastPerformed(lang))")
                        .font(DSFont.meta)
                        .foregroundStyle(Color.mutedFg)
                }
                .padding(.top, 8)
                .listRowSeparator(.hidden)

                // the row separator under it is the hairline
                CapsTitle(Text("gym.routineDetail.exercises", bundle: .l10n))
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }

                exercises

                Button {
                    Task {
                        await store.start(templateId: template.id)
                        // the session covers the app now; coming back lands on the list
                        if store.active != nil { dismiss() }
                    }
                } label: {
                    if store.startingTemplateId == template.id {
                        ProgressView().tint(Color.accFg)
                    } else {
                        Label { Text("gym.routineDetail.start", bundle: .l10n) } icon: { Image(systemName: "play") }
                    }
                }
                .buttonStyle(.primary)
                .disabled(store.startingTemplateId != nil || deleting)
                .padding(.top, 14)
                .padding(.bottom, 24)
                // keeps the hairline under the last exercise
                .listRowSeparator(.hidden, edges: .bottom)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: pageGutter, bottom: 0, trailing: pageGutter))
            .listRowBackground(Color.pageBg)
        }
        .monolitoList()
        .navigationTitle(Text(verbatim: summary.name))
        .floatingTabBarSpace()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if case .loaded(let detail) = state { editing = detail }
                } label: {
                    Image(systemName: "pencil")
                }
                .disabled(!isLoaded || deleting)
                .accessibilityLabel(Text("gym.editor.edit", bundle: .l10n))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { confirmingDelete = true } label: {
                    Image(systemName: "trash")
                }
                .tint(Color.neg)
                .disabled(deleting)
                .accessibilityLabel(Text("gym.routineDetail.delete", bundle: .l10n))
            }
        }
        .confirmationDialog(Text("gym.routineDetail.deleteConfirm", bundle: .l10n), isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button(role: .destructive) {
                Task {
                    deleting = true
                    if await store.deleteTemplate(template.id) { dismiss() }
                    deleting = false
                }
            } label: { Text("gym.routineDetail.delete", bundle: .l10n) }
            Button(role: .cancel) {} label: { Text("common.cancel", bundle: .l10n) }
        }
        .fullScreenCover(item: $editing) { detail in
            RoutineEditView(template: detail, store: store) { saved in state = .loaded(saved) }
                .monolitoTheme()
        }
        .task { await loadDetail() }
        .refreshable { await loadDetail() }
    }

    @ViewBuilder private var exercises: some View {
        switch state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .listRowSeparator(.hidden)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text(message).font(DSFont.meta).foregroundStyle(Color.neg)
                Button { Task { await loadDetail() } } label: { Text("common.retry", bundle: .l10n) }
                    .buttonStyle(.pill)
            }
            .padding(.vertical, 8)
        case .loaded(let detail):
            ForEach(Array(detail.exercises.enumerated()), id: \.element.id) { index, exercise in
                NavigationLink {
                    RoutineExerciseDetailView(exercise: exercise, fallbackMuscle: summary.muscleGroups.first, store: store)
                } label: {
                    RoutineExerciseRow(number: index + 1, exercise: exercise)
                }
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            }
        }
    }

    private var isLoaded: Bool {
        if case .loaded = state { true } else { false }
    }

    private func lastPerformed(_ lang: Lang) -> String {
        let when = RoutineFormat.lastPerformed(summary.lastPerformedAt, lang: lang)
        return summary.lastPerformedAt == nil ? when : L10n.string("gym.routineDetail.lastPerformed %@", lang: lang, when)
    }

    private func loadDetail() async {
        switch await store.templateDetail(template.id) {
        case .success(let detail): state = .loaded(detail)
        case .failure(let error):
            // nil = session expired, the app is going back to login
            if let message = error.message { state = .failed(message) }
        }
    }
}

/// "1  Barra Fixa com Peso / 3 séries · 12 reps · descanso 1:30"
private struct RoutineExerciseRow: View {
    let number: Int
    let exercise: TemplateExercise
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let lang = language.lang
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
                Text(verbatim: RoutineTargetsText.spec(
                    sets: exercise.targetSets, repsMin: exercise.targetRepsMin,
                    repsMax: exercise.targetRepsMax, rest: exercise.restSeconds, lang: lang
                ))
                .font(DSFont.caption)
                .foregroundStyle(Color.mutedFg)
            }
        }
        .padding(.vertical, 6)
    }
}

/// "3 séries · 12 reps · descanso 1:30" (the web's `editor.mobileSpec` +
/// `restSuffix`): the routine detail and the editor's rows.
enum RoutineTargetsText {
    static func spec(sets: Int?, repsMin: Int?, repsMax: Int?, rest: Int?, lang: Lang) -> String {
        let base = L10n.string(
            "gym.routineDetail.spec %@ %@", lang: lang,
            sets.map(String.init) ?? "—", RoutineFormat.repsRange(min: repsMin, max: repsMax)
        )
        guard let rest else { return base }
        return "\(base) · \(L10n.string("gym.routineDetail.rest %@", lang: lang, RoutineFormat.rest(seconds: rest)))"
    }
}
