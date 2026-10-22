import SwiftUI
import SoTreinaKit

/// The open workout (spec §6.4, tela 3): one section per exercise with its
/// sets, a row to log the next one, add/remove exercises, cancel and finish.
struct WorkoutSessionView: View {
    let store: WorkoutStore
    let workout: WorkoutDetail
    @State private var confirmingDiscard = false
    @State private var confirmingFinish = false
    @State private var addingExercise = false
    @State private var editing: EditingSet?
    @FocusState private var focus: SetField?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Duração") {
                        // startedAt comes from the server, so the clock
                        // survives relaunches and matches the web
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(WorkoutFormat.elapsed(Int(context.date.timeIntervalSince(workout.startedAt))))
                                .monospacedDigit()
                        }
                    }
                    LabeledContent("Séries", value: "\(workout.exercises.reduce(0) { $0 + $1.sets.count })")
                }

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
                        Label("Adicionar exercício", systemImage: "plus")
                    }
                } footer: {
                    if !store.pendingSets.isEmpty {
                        Text("Envie ou descarte as séries com ⚠ antes de finalizar.")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(workout.templateName ?? "Treino livre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar", role: .destructive) { confirmingDiscard = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if store.isFinishing {
                        ProgressView()
                    } else {
                        Button("Finalizar") { confirmingFinish = true }
                            .bold()
                            .disabled(!store.canFinish)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("OK") { focus = nil }
                }
            }
            .confirmationDialog("Finalizar o treino?", isPresented: $confirmingFinish, titleVisibility: .visible) {
                Button("Finalizar treino") { Task { await store.finish() } }
                Button("Continuar treinando", role: .cancel) {}
            }
            .confirmationDialog("Cancelar o treino?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("Cancelar treino e apagar as séries", role: .destructive) {
                    Task { await store.discard() }
                }
                Button("Continuar treinando", role: .cancel) {}
            } message: {
                Text("Tudo o que foi registrado neste treino será apagado, aqui e na web.")
            }
            .sheet(isPresented: $addingExercise) {
                ExercisePickerView(store: store)
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

    private var pending: [WorkoutStore.PendingSet] { store.pendingSets(for: exercise.id) }

    var body: some View {
        Section {
            ForEach(exercise.sets) { set in
                Button {
                    onEdit(set)
                } label: {
                    SetLine(number: set.setNumber, text: WorkoutFormat.set(weightKg: set.weightKg, reps: set.reps)) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
                .tint(.primary)
                .swipeActions {
                    Button("Apagar", role: .destructive) {
                        Task { await store.deleteSet(workoutExerciseId: exercise.id, setId: set.id) }
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
                Spacer()
                Menu {
                    Button("Remover exercício", systemImage: "trash", role: .destructive) {
                        if exercise.sets.isEmpty {
                            Task { await store.removeExercise(workoutExerciseId: exercise.id) }
                        } else {
                            confirmingRemove = true
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .imageScale(.large)
                }
                .accessibilityLabel("Opções de \(exercise.exerciseName)")
            }
        } footer: {
            let parts = [
                WorkoutFormat.target(exercise.target).map { "Meta: \($0)" },
                exercise.target?.restSeconds.map { "descanso \(WorkoutFormat.elapsed($0))" },
            ].compactMap { $0 }
            if !parts.isEmpty {
                Text(parts.joined(separator: " · "))
            }
        }
        .confirmationDialog(
            "Remover \(exercise.exerciseName)?",
            isPresented: $confirmingRemove,
            titleVisibility: .visible
        ) {
            Button("Remover e apagar as séries", role: .destructive) {
                Task { await store.removeExercise(workoutExerciseId: exercise.id) }
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
            Text("\(number)")
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .leading)
            Text(text)
                .monospacedDigit()
            Spacer()
            trailing
        }
    }
}

private struct PendingSetRow: View {
    let number: Int
    let pending: WorkoutStore.PendingSet
    let store: WorkoutStore

    var body: some View {
        SetLine(number: number, text: WorkoutFormat.set(weightKg: pending.weightKg, reps: pending.reps)) {
            if pending.failed {
                Button {
                    Task { await store.retry(pending) }
                } label: {
                    Label("Reenviar", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.borderless)
            } else {
                ProgressView()
            }
        }
        .swipeActions {
            if pending.failed {
                Button("Descartar", role: .destructive) { store.dropPending(pending) }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("\(setNumber)")
                    .foregroundStyle(.secondary)
                    .frame(width: 24, alignment: .leading)
                field("kg", text: $weightText, placeholder: proposal?.weightKg.map(WorkoutFormat.weight), keyboard: .decimalPad)
                    .focused(focus, equals: .weight(exercise.id))
                Text("×").foregroundStyle(.secondary)
                field("reps", text: $repsText, placeholder: proposal?.reps.map(String.init), keyboard: .numberPad)
                    .focused(focus, equals: .reps(exercise.id))
                Spacer(minLength: 4)
                Button("Registrar") {
                    let values = resolved
                    focus.wrappedValue = nil
                    Task { await store.addSet(workoutExerciseId: exercise.id, weightKg: values.weightKg, reps: values.reps) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canLog)
            }
            if let proposal, proposal.source == .lastTime {
                Text("Última vez: \(WorkoutFormat.set(weightKg: proposal.weightKg, reps: proposal.reps))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                .monospacedDigit()
                .frame(width: 52)
                .padding(.vertical, 6)
                .padding(.horizontal, 6)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// typed value, else the proposal's
    private var resolved: (weightKg: Double?, reps: Int?) {
        (
            weightText.isEmpty ? proposal?.weightKg : SetInput.weight(weightText),
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
        _weightText = State(initialValue: editing.workoutSet.weightKg.map(WorkoutFormat.weight) ?? "")
        _repsText = State(initialValue: editing.workoutSet.reps.map(String.init) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Peso (kg)") {
                        TextField("–", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Repetições") {
                        TextField("–", text: $repsText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                Section {
                    Button("Apagar série", role: .destructive) {
                        dismiss()
                        Task { await store.deleteSet(workoutExerciseId: editing.exerciseId, setId: editing.workoutSet.id) }
                    }
                }
            }
            .navigationTitle("Série \(editing.workoutSet.setNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        dismiss()
                        Task {
                            await store.updateSet(
                                workoutExerciseId: editing.exerciseId,
                                setId: editing.workoutSet.id,
                                weightKg: SetInput.weight(weightText),
                                reps: SetInput.reps(repsText)
                            )
                        }
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
