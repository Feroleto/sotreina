import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// The open workout (spec §6.4, tela 3): one section per exercise with its
/// sets, a row to log the next one, add/remove exercises, cancel and finish.
struct WorkoutSessionView: View {
    let store: WorkoutStore
    let workout: WorkoutDetail
    @State private var confirmingDiscard = false
    @State private var confirmingFinish = false
    @State private var confirmingSync = false
    @State private var addingExercise = false
    @State private var editing: EditingSet?
    @FocusState private var focus: SetField?
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let lang = language.lang
        NavigationStack {
            List {
                Section {
                    // startedAt comes from the server, so the clock
                    // survives relaunches and matches the web
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        KPIStrip([
                            KPI(L10n.string("gym.session.duration", lang: lang), WorkoutFormat.elapsed(Int(context.date.timeIntervalSince(workout.startedAt)))),
                            KPI(L10n.string("gym.summary.sets", lang: lang), "\(workout.exercises.reduce(0) { $0 + $1.sets.count })"),
                            KPI(L10n.string("gym.summary.exercises", lang: lang), "\(workout.exercises.count)"),
                        ])
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: pageGutter, bottom: 12, trailing: pageGutter))
                    .listRowSeparator(.hidden)
                }
                .listRowBackground(Color.pageBg)

                ForEach(workout.exercises) { exercise in
                    ExerciseSection(
                        exercise: exercise,
                        store: store,
                        focus: $focus,
                        onEdit: { set in editing = EditingSet(exerciseId: exercise.id, workoutSet: set) }
                    )
                }

                Section {
                    Button {
                        addingExercise = true
                    } label: {
                        Label { Text("gym.picker.title", bundle: .l10n) } icon: { Image(systemName: "plus") }
                            .font(DSFont.row)
                    }
                    .listRowBackground(Color.pageBg)
                } footer: {
                    if !store.pendingSets.isEmpty {
                        Text("gym.session.pendingFooter", bundle: .l10n)
                    }
                }
            }
            .monolitoList()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(workout.templateName ?? L10n.string("gym.freeWorkout", lang: lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    // back to the tabs; the session keeps running in the bar
                    Button {
                        store.sessionMinimized = true
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .accessibilityLabel(Text("gym.session.minimize", bundle: .l10n))
                    Button(role: .destructive) { confirmingDiscard = true } label: { Text("common.cancel", bundle: .l10n) }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if store.isFinishing {
                        ProgressView()
                    } else {
                        Button {
                            Task {
                                switch await store.finishPrompt() {
                                case .confirm: confirmingFinish = true
                                case .syncTemplate: confirmingSync = true
                                }
                            }
                        } label: {
                            Text("gym.session.finishShort", bundle: .l10n)
                        }
                            .bold()
                            .disabled(!store.canFinish)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button { focus = nil } label: { Text("common.ok", bundle: .l10n) }
                }
            }
            .confirmationDialog(Text("gym.session.finishConfirm", bundle: .l10n), isPresented: $confirmingFinish, titleVisibility: .visible) {
                Button { Task { await store.finish() } } label: { Text("gym.session.finish", bundle: .l10n) }
                Button(role: .cancel) {} label: { Text("gym.session.keepTraining", bundle: .l10n) }
            }
            // the workout drifted from its routine (web: `session.syncTemplate*`);
            // either answer finishes, "Voltar" keeps training
            .confirmationDialog(Text("gym.session.syncTemplatePrompt", bundle: .l10n), isPresented: $confirmingSync, titleVisibility: .visible) {
                Button { Task { await store.finish(syncTemplate: true) } } label: { Text("gym.session.syncTemplateUpdate", bundle: .l10n) }
                Button { Task { await store.finish(syncTemplate: false) } } label: { Text("gym.session.syncTemplateKeep", bundle: .l10n) }
                Button(role: .cancel) {} label: { Text("gym.session.syncTemplateBack", bundle: .l10n) }
            }
            .confirmationDialog(Text("gym.session.cancelConfirm", bundle: .l10n), isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button(role: .destructive) {
                    Task { await store.discard() }
                } label: {
                    Text("gym.session.cancelAndDelete", bundle: .l10n)
                }
                Button(role: .cancel) {} label: { Text("gym.session.keepTraining", bundle: .l10n) }
            } message: {
                Text("gym.session.cancelMessage", bundle: .l10n)
            }
            .sheet(isPresented: $addingExercise) {
                ExercisePickerView { await store.addExercise(exerciseId: $0.id) }
            }
            .sheet(item: $editing) { editing in
                SetEditSheet(store: store, editing: editing)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                RestBar(rest: store.rest)
            }
            // spec §6.6: asked on the first workout; iOS shows it only once
            .task { await store.rest.requestNotificationPermission() }
            .task(id: workout.exercises.map(\.exerciseId)) {
                await store.loadLastPerformance(for: workout.exercises.map(\.exerciseId))
            }
            .refreshable { await store.load() }
        }
    }
}

enum SetField: Hashable {
    case weight(String)
    case reps(String)
}

struct EditingSet: Identifiable {
    let exerciseId: String
    let workoutSet: WorkoutSet
    var id: String { workoutSet.id }
}

private struct ExerciseSection: View {
    let exercise: WorkoutExercise
    let store: WorkoutStore
    var focus: FocusState<SetField?>.Binding
    let onEdit: (WorkoutSet) -> Void
    @State private var confirmingRemove = false
    @Environment(AppLanguageStore.self) private var language

    private var pending: [WorkoutStore.PendingSet] { store.pendingSets(for: exercise.id) }

    var body: some View {
        Section {
            ForEach(exercise.sets) { set in
                Button {
                    onEdit(set)
                } label: {
                    SetLine(number: set.setNumber, text: WorkoutFormat.set(weightKg: set.weightKg, reps: set.reps, unit: store.weightUnit, lang: language.lang)) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.pos)
                    }
                }
                .tint(.primary)
                .swipeActions {
                    Button(role: .destructive) {
                        Task { await store.deleteSet(workoutExerciseId: exercise.id, setId: set.id) }
                    } label: {
                        Text("common.delete", bundle: .l10n)
                    }
                }
            }

            ForEach(Array(pending.enumerated()), id: \.element.id) { offset, item in
                PendingSetRow(number: exercise.sets.count + offset + 1, pending: item, store: store)
            }

            NewSetRow(
                exercise: exercise,
                setNumber: exercise.sets.count + pending.count + 1,
                proposal: proposal,
                store: store,
                focus: focus
            )
            // a fresh row (empty fields) for every set number
            .id(exercise.sets.count + pending.count)
        } header: {
            HStack {
                Text(exercise.exerciseName)
                    .font(DSFont.rowTitle)
                    .foregroundStyle(Color.fg)
                    .textCase(nil)
                Spacer()
                Menu {
                    Button(role: .destructive) {
                        if exercise.sets.isEmpty {
                            Task { await store.removeExercise(workoutExerciseId: exercise.id) }
                        } else {
                            confirmingRemove = true
                        }
                    } label: {
                        Label { Text("gym.session.removeExercise", bundle: .l10n) } icon: { Image(systemName: "trash") }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .imageScale(.large)
                }
                .accessibilityLabel(Text("gym.session.exerciseOptions \(exercise.exerciseName)", bundle: .l10n))
            }
        } footer: {
            let lang = language.lang
            let parts = [
                WorkoutFormat.target(exercise.target, lang: lang).map { L10n.string("gym.session.target %@", lang: lang, $0) },
                exercise.target?.restSeconds.map { L10n.string("gym.session.rest %@", lang: lang, WorkoutFormat.elapsed($0)) },
            ].compactMap { $0 }
            if !parts.isEmpty {
                Text(parts.joined(separator: " · "))
                    .font(DSFont.caption)
                    .foregroundStyle(Color.mutedFg)
            }
        }
        .listRowBackground(Color.pageBg)
        .confirmationDialog(
            Text("gym.session.removeConfirm \(exercise.exerciseName)", bundle: .l10n),
            isPresented: $confirmingRemove,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                Task { await store.removeExercise(workoutExerciseId: exercise.id) }
            } label: {
                Text("gym.session.removeAndDelete", bundle: .l10n)
            }
        }
    }

    private var proposal: SetProposal? {
        let previous = pending.last.map { ($0.weightKg, $0.reps) }
            ?? exercise.sets.last.map { ($0.weightKg, $0.reps) }
        return SetProposal.propose(
            setNumber: exercise.sets.count + pending.count + 1,
            lastPerformance: store.lastPerformance[exercise.exerciseId],
            previousInWorkout: previous.map { (weightKg: $0.0, reps: $0.1) }
        )
    }
}

private struct SetLine<Trailing: View>: View {
    let number: Int
    let text: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack {
            Text(verbatim: "\(number)")
                .font(DSFont.monoBody)
                .foregroundStyle(Color.mutedFg)
                .frame(width: 24, alignment: .leading)
            Text(text)
                .font(DSFont.monoBody)
            Spacer()
            trailing
        }
    }
}

private struct PendingSetRow: View {
    let number: Int
    let pending: WorkoutStore.PendingSet
    let store: WorkoutStore
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        SetLine(number: number, text: WorkoutFormat.set(weightKg: pending.weightKg, reps: pending.reps, unit: store.weightUnit, lang: language.lang)) {
            if pending.failed {
                Button {
                    Task { await store.retry(pending) }
                } label: {
                    Label { Text("gym.session.resend", bundle: .l10n) } icon: { Image(systemName: "exclamationmark.triangle.fill") }
                        .foregroundStyle(Color.neg)
                }
                .buttonStyle(.borderless)
            } else {
                ProgressView()
            }
        }
        .swipeActions {
            if pending.failed {
                Button(role: .destructive) { store.dropPending(pending) } label: { Text("gym.session.discard", bundle: .l10n) }
            }
        }
    }
}

/// The next set: empty fields whose placeholders are the proposal — tapping
/// "Registrar" without typing logs the proposal (same as the web's grid).
private struct NewSetRow: View {
    let exercise: WorkoutExercise
    let setNumber: Int
    let proposal: SetProposal?
    let store: WorkoutStore
    var focus: FocusState<SetField?>.Binding
    @State private var weightText = ""
    @State private var repsText = ""
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let lang = language.lang
        let unit = store.weightUnit
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(verbatim: "\(setNumber)")
                    .font(DSFont.monoBody)
                    .foregroundStyle(Color.mutedFg)
                    .frame(width: 24, alignment: .leading)
                field(UnitConversion.label(unit), text: $weightText, placeholder: proposal?.weightKg.map { WorkoutFormat.weight($0, unit: unit, lang: lang) }, keyboard: .decimalPad)
                    .focused(focus, equals: .weight(exercise.id))
                Text(verbatim: "×").foregroundStyle(Color.mutedFg)
                field("reps", text: $repsText, placeholder: proposal?.reps.map(String.init), keyboard: .numberPad)
                    .focused(focus, equals: .reps(exercise.id))
                Spacer(minLength: 4)
                Button {
                    let values = resolved
                    focus.wrappedValue = nil
                    Task { await store.addSet(workoutExerciseId: exercise.id, weightKg: values.weightKg, reps: values.reps) }
                } label: {
                    Text("gym.session.log", bundle: .l10n)
                }
                .buttonStyle(.pill)
                .disabled(!canLog)
            }
            if let proposal, proposal.source == .lastTime {
                Text("gym.session.lastTime \(WorkoutFormat.set(weightKg: proposal.weightKg, reps: proposal.reps, unit: unit, lang: lang))", bundle: .l10n)
                    .font(DSFont.caption)
                    .foregroundStyle(Color.mutedFg)
                    .padding(.leading, 32)
            }
        }
        .padding(.vertical, 2)
    }

    private func field(_ unit: String, text: Binding<String>, placeholder: String?, keyboard: UIKeyboardType) -> some View {
        HStack(spacing: 2) {
            TextField(placeholder ?? "–", text: text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .font(DSFont.monoBody)
                .frame(width: 52)
                .padding(.vertical, 7)
                .padding(.horizontal, 6)
                .background(Color.chip, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(unit)
                .font(DSFont.caption)
                .foregroundStyle(Color.mutedFg)
        }
    }

    /// typed value (in the display unit), else the proposal's (already kg)
    private var resolved: (weightKg: Double?, reps: Int?) {
        (
            weightText.isEmpty ? proposal?.weightKg : SetInput.weightKg(weightText, unit: store.weightUnit),
            repsText.isEmpty ? proposal?.reps : SetInput.reps(repsText)
        )
    }

    private var canLog: Bool {
        // something typed must parse; and the set must carry at least one value
        if !weightText.isEmpty, SetInput.weight(weightText) == nil { return false }
        if !repsText.isEmpty, SetInput.reps(repsText) == nil { return false }
        return resolved.weightKg != nil || resolved.reps != nil
    }
}

/// Edit or delete a logged set (`PATCH`/`DELETE .../sets/:setId`).
private struct SetEditSheet: View {
    let store: WorkoutStore
    let editing: EditingSet
    @Environment(\.dismiss) private var dismiss
    @State private var weightText: String
    @State private var repsText: String

    init(store: WorkoutStore, editing: EditingSet) {
        self.store = store
        self.editing = editing
        // the sheet's decimal pad types the app language's separator
        let lang = AppLanguageStore.shared.lang
        _weightText = State(initialValue: editing.workoutSet.weightKg.map { WorkoutFormat.weight($0, unit: store.weightUnit, lang: lang) } ?? "")
        _repsText = State(initialValue: editing.workoutSet.reps.map(String.init) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent {
                        TextField("–", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        Text("gym.entry.weightLabel \(UnitConversion.label(store.weightUnit))", bundle: .l10n)
                    }
                    LabeledContent {
                        TextField("–", text: $repsText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        Text("gym.entry.repsLabel", bundle: .l10n)
                    }
                }
                Section {
                    Button(role: .destructive) {
                        dismiss()
                        Task { await store.deleteSet(workoutExerciseId: editing.exerciseId, setId: editing.workoutSet.id) }
                    } label: {
                        Text("gym.entry.deleteSet", bundle: .l10n)
                    }
                }
            }
            .monolitoForm()
            .navigationTitle(Text("gym.session.setTitle \(editing.workoutSet.setNumber)", bundle: .l10n))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.cancel", bundle: .l10n) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                        Task {
                            await store.updateSet(
                                workoutExerciseId: editing.exerciseId,
                                setId: editing.workoutSet.id,
                                weightKg: SetInput.editedWeightKg(
                                    weightText, original: editing.workoutSet.weightKg,
                                    unit: store.weightUnit, lang: AppLanguageStore.shared.lang
                                ),
                                reps: SetInput.reps(repsText)
                            )
                        }
                    } label: {
                        Text("common.save", bundle: .l10n)
                    }
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var isValid: Bool {
        (weightText.isEmpty || SetInput.weight(weightText) != nil)
            && (repsText.isEmpty || SetInput.reps(repsText) != nil)
            && !(weightText.isEmpty && repsText.isEmpty)
    }
}
