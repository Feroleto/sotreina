import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// "Nova rotina" / "Editar rotina" (web RoutineEditPage, mobile builder): the
/// name, the exercises with their targets (tap opens "Editar exercício",
/// drag to reorder, × to remove) and "Adicionar exercício". Everything stays
/// in a `RoutineDraft` until Salvar, one call; Cancelar with changes asks
/// before discarding. Presented full screen, with its own navigation stack.
struct RoutineEditView: View {
    /// nil = new routine
    let templateId: String?
    let store: WorkoutStore
    let onSaved: (TemplateDetail) -> Void
    @State private var draft: RoutineDraft
    @State private var saving = false
    @State private var saveError: String?
    @State private var confirmingDiscard = false
    @State private var picking = false
    /// "Editar exercício" pushes by row id; a Button rather than a
    /// NavigationLink, which would add a chevron next to the ×
    @State private var path: [String] = []
    @Environment(\.dismiss) private var dismiss

    init(template: TemplateDetail?, store: WorkoutStore, onSaved: @escaping (TemplateDetail) -> Void = { _ in }) {
        templateId = template?.id
        self.store = store
        self.onSaved = onSaved
        _draft = State(initialValue: template.map(RoutineDraft.init(template:)) ?? RoutineDraft())
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Group {
                    VStack(alignment: .leading, spacing: 8) {
                        CapsTitle(Text("gym.editor.nameLabel", bundle: .l10n))
                        TextField(text: $draft.name) { Text("gym.editor.namePlaceholder", bundle: .l10n) }
                            .font(Font.geist(16, relativeTo: .body).weight(.semibold))
                            .submitLabel(.done)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.border, lineWidth: 1)
                            }
                    }
                    .padding(.top, 14)
                    .listRowSeparator(.hidden)

                    HStack {
                        CapsTitle(Text("gym.routineDetail.exercises", bundle: .l10n))
                        Spacer()
                        Text("gym.editor.exercisesAdded \(draft.exercises.count)", bundle: .l10n)
                            .font(DSFont.caption)
                            .foregroundStyle(Color.mutedFg)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    .listRowSeparator(.hidden, edges: .bottom)

                    ForEach(draft.exercises) { exercise in
                        Button { path.append(exercise.id) } label: {
                            EditorExerciseRow(exercise: exercise) { draft.remove(exercise.id) }
                        }
                        .buttonStyle(.plain)
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    }
                    // long-press and drag a row; swipe left also removes
                    .onMove { draft.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { offsets in
                        offsets.map { draft.exercises[$0].id }.forEach { draft.remove($0) }
                    }

                    Button { picking = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus").font(.system(size: 13, weight: .semibold))
                            Text("gym.editor.addExercise", bundle: .l10n)
                        }
                            .font(DSFont.button)
                            .foregroundStyle(Color.accTx)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                    .listRowSeparator(.hidden, edges: .bottom)

                    if let saveError {
                        Text(saveError)
                            .font(DSFont.meta)
                            .foregroundStyle(Color.neg)
                            .listRowSeparator(.hidden)
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: pageGutter, bottom: 0, trailing: pageGutter))
                .listRowBackground(Color.pageBg)
            }
            .monolitoList()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text(templateId == nil ? "gym.editor.newTitle" : "gym.editor.editTitle", bundle: .l10n))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if draft.isDirty { confirmingDiscard = true } else { dismiss() }
                    } label: {
                        Text("common.cancel", bundle: .l10n)
                    }
                    .disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saving {
                        ProgressView()
                    } else {
                        Button { Task { await save() } } label: {
                            Text("gym.editor.save", bundle: .l10n).bold()
                        }
                        .disabled(!draft.canSave)
                    }
                }
            }
            .confirmationDialog(Text("gym.editor.discardConfirm", bundle: .l10n), isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button(role: .destructive) { dismiss() } label: { Text("gym.editor.discard", bundle: .l10n) }
                Button(role: .cancel) {} label: { Text("gym.editor.keepEditing", bundle: .l10n) }
            }
            .navigationDestination(for: String.self) { id in
                RoutineTargetsEditView(draft: $draft, exerciseId: id)
            }
            .sheet(isPresented: $picking) {
                RoutineExercisePickerView(draft: $draft, store: store)
                    .monolitoTheme()
            }
            .background(Color.pageBg)
        }
    }

    private func save() async {
        saving = true
        saveError = nil
        switch await store.saveTemplate(draft, id: templateId) {
        case .success(let saved):
            onSaved(saved)
            dismiss()
        case .failure(let error):
            // nil = session expired, the app is going back to login
            saveError = error.message
        }
        saving = false
    }
}

/// grip · name / targets · ×
private struct EditorExerciseRow: View {
    let exercise: WorkingExercise
    let onRemove: () -> Void
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        HStack(spacing: 12) {
            // a hint: the drag itself is the List's long press
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.mutedFg)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.exerciseName)
                    .font(DSFont.row.weight(.semibold))
                    .foregroundStyle(Color.fg)
                    .lineLimit(1)
                Text(verbatim: RoutineTargetsText.spec(
                    sets: exercise.targetSets, repsMin: exercise.targetRepsMin,
                    repsMax: exercise.targetRepsMax, rest: exercise.restSeconds, lang: language.lang
                ))
                .font(DSFont.caption)
                .foregroundStyle(Color.mutedFg)
            }
            Spacer(minLength: 8)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.mutedFg)
                    .frame(width: 28, height: 28)
                    .background(Color.chip, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text("gym.editor.removeExercise", bundle: .l10n))
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

/// "Editar exercício" (web RoutineExerciseEditPage): séries, faixa de
/// repetições e descanso, each a stepper that writes only its own field.
struct RoutineTargetsEditView: View {
    @Binding var draft: RoutineDraft
    let exerciseId: String
    @Environment(\.dismiss) private var dismiss
    @Environment(AppLanguageStore.self) private var language

    private var exercise: WorkingExercise? { draft.exercises.first { $0.id == exerciseId } }

    var body: some View {
        ScrollView {
            if let exercise {
                let steps = TargetSteps(exercise)
                VStack(alignment: .leading, spacing: 14) {
                    Text(exercise.exerciseName)
                        .font(Font.geist(16, relativeTo: .headline).weight(.semibold))
                        .foregroundStyle(Color.fg)
                        .lineLimit(2)
                        .padding(.bottom, 6)

                    StepperCard(title: Text("gym.editor.exercise.sets", bundle: .l10n)) {
                        StepperControl(
                            value: Text(verbatim: "\(steps.sets)"), size: 26,
                            label: Text("gym.editor.exercise.sets", bundle: .l10n),
                            canDecrease: steps.canDecreaseSets, canIncrease: steps.canIncreaseSets,
                            decrease: { set { $0.targetSets = steps.sets - 1 } },
                            increase: { set { $0.targetSets = steps.sets + 1 } }
                        )
                    }

                    StepperCard(title: Text("gym.editor.exercise.reps", bundle: .l10n), hint: Text("gym.editor.exercise.repsHint", bundle: .l10n)) {
                        HStack(spacing: 8) {
                            StepperControl(
                                value: Text(verbatim: "\(steps.repsMin)"), size: 20,
                                label: Text("gym.editor.exercise.repsMin", bundle: .l10n),
                                canDecrease: steps.canDecreaseRepsMin, canIncrease: steps.canIncreaseRepsMin,
                                decrease: { set { $0.targetRepsMin = steps.repsMin - 1 } },
                                increase: { set { $0.targetRepsMin = steps.repsMin + 1 } }
                            )
                            Text(verbatim: "–").foregroundStyle(Color.mutedFg)
                            StepperControl(
                                value: Text(verbatim: "\(steps.repsMax)"), size: 20,
                                label: Text("gym.editor.exercise.repsMax", bundle: .l10n),
                                canDecrease: steps.canDecreaseRepsMax, canIncrease: steps.canIncreaseRepsMax,
                                decrease: { set { $0.targetRepsMax = steps.repsMax - 1 } },
                                increase: { set { $0.targetRepsMax = steps.repsMax + 1 } }
                            )
                        }
                    }

                    StepperCard(title: Text("gym.editor.exercise.rest", bundle: .l10n), hint: Text("gym.editor.exercise.restHint", bundle: .l10n)) {
                        StepperControl(
                            value: steps.rest.map { Text(verbatim: RoutineFormat.rest(seconds: $0)) }
                                ?? Text("gym.editor.exercise.restDefault", bundle: .l10n),
                            size: 22, mono: true,
                            label: Text("gym.editor.exercise.rest", bundle: .l10n),
                            canDecrease: steps.canDecreaseRest, canIncrease: steps.canIncreaseRest,
                            decrease: { set { $0.restSeconds = TargetSteps.restDown(steps.rest) } },
                            increase: { set { $0.restSeconds = TargetSteps.restUp(steps.rest) } }
                        )
                    }
                }
                .padding(.horizontal, pageGutter)
                .padding(.vertical, 18)
            }
        }
        .background(Color.pageBg)
        .navigationTitle(Text("gym.editor.exercise.title", bundle: .l10n))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { dismiss() } label: { Text("gym.editor.done", bundle: .l10n).bold() }
            }
        }
    }

    private func set(_ change: (inout WorkingExercise) -> Void) {
        draft.update(exerciseId, change)
    }
}

/// A bordered card with a caps title (and a hint) over its stepper.
private struct StepperCard<Content: View>: View {
    let title: Text
    var hint: Text?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 4) {
            CapsTitle(title)
            if let hint {
                hint.font(DSFont.caption).foregroundStyle(Color.mutedFg).multilineTextAlignment(.center)
            }
            content.padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.border, lineWidth: 1)
        }
    }
}

/// − value +, with limits that depend on the other values (min ≤ max),
/// which `ValueStepper`'s fixed range can't express.
private struct StepperControl: View {
    let value: Text
    let size: CGFloat
    var mono = false
    let label: Text
    let canDecrease: Bool
    let canIncrease: Bool
    let decrease: () -> Void
    let increase: () -> Void

    var body: some View {
        HStack(spacing: size > 21 ? 20 : 10) {
            button("minus", enabled: canDecrease, action: decrease)
                .accessibilityLabel(Text("today.goals.decrease", bundle: .l10n))
            value
                .font(mono ? Font.geistMono(size, relativeTo: .title2).weight(.bold) : Font.geist(size, relativeTo: .title2).weight(.bold))
                .foregroundStyle(Color.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(minWidth: mono ? 72 : 36)
            button("plus", enabled: canIncrease, action: increase)
                .accessibilityLabel(Text("today.goals.increase", bundle: .l10n))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }

    private func button(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(Color.chip, in: Circle())
                .foregroundStyle(Color.fg)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
    }
}
