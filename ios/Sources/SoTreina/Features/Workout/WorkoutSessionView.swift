import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// The open workout (spec §6.4, tela 3; Claude Design "Treino Academia Foco"
/// 2a; `.plans/treino-sessao-ajustes-spec.md`): one active exercise in a card
/// with its sets — logged (tap to edit in place), the current one with its
/// fields and the ✓, the planned ones dimmed — and the other exercises
/// collapsed below, tap to make one active.
struct WorkoutSessionView: View {
    let store: WorkoutStore
    let workout: WorkoutDetail
    @State private var confirmingDiscard = false
    @State private var confirmingFinish = false
    @State private var confirmingSync = false
    @State private var addingExercise = false
    /// the logged set open for editing (one at a time)
    @State private var editingSetId: String?
    /// an exercise picked by hand; nil follows the cursor (the Live
    /// Activity's rule: stay until marked done, then the next open one)
    @State private var selectedId: String?
    @FocusState private var focus: SetField?
    @Environment(AppLanguageStore.self) private var language

    /// the workout with the planned sets and done marks still on their way
    /// to the server
    private var shown: WorkoutDetail {
        workout.applying(targetSets: store.targetOverrides, completed: store.completedOverrides)
    }

    private var exercises: [WorkoutExercise] { shown.exercises.sorted { $0.order < $1.order } }

    private func count(_ exercise: WorkoutExercise) -> Int {
        exercise.sets.count + store.pendingSets(for: exercise.id).count
    }

    /// done only when the lifter marked it — the target is a visual guide
    private func isDone(_ exercise: WorkoutExercise) -> Bool { exercise.completedAt != nil }

    private var active: WorkoutExercise? {
        if let selectedId, let picked = exercises.first(where: { $0.id == selectedId }) { return picked }
        let pending = store.pendingSets.map {
            WorkoutActivity.PendingSet(workoutExerciseId: $0.workoutExerciseId, weightKg: $0.weightKg, reps: $0.reps, failed: $0.failed)
        }
        return WorkoutActivity.cursor(in: shown, pending: pending)?.exercise
    }

    var body: some View {
        let lang = language.lang
        NavigationStack {
            VStack(spacing: 0) {
                progressHeader
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if let active, let index = exercises.firstIndex(where: { $0.id == active.id }) {
                            ActiveExerciseCard(
                                exercise: active,
                                position: index + 1,
                                total: exercises.count,
                                store: store,
                                focus: $focus,
                                editingSetId: $editingSetId,
                                onCompleted: {
                                    // hand back to the cursor: the next open exercise
                                    editingSetId = nil
                                    withAnimation(.snappy) { selectedId = nil }
                                }
                            )
                            .id(active.id)
                            .transition(.opacity)
                        }
                        otherExercises
                        Button {
                            addingExercise = true
                        } label: {
                            Label { Text("gym.picker.title", bundle: .l10n) } icon: { Image(systemName: "plus") }
                                .font(DSFont.row)
                                .foregroundStyle(Color.accTx)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 13)
                        }
                        .buttonStyle(.plain)
                        if !store.pendingSets.isEmpty {
                            Text("gym.session.pendingFooter", bundle: .l10n)
                                .font(DSFont.caption)
                                .foregroundStyle(Color.mutedFg)
                                .padding(.horizontal, 6)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 16)
                    // a tap anywhere else closes (and saves) the set being edited
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focus = nil
                        editingSetId = nil
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .refreshable { await store.load() }
            }
            .background(Color.pageBg)
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
                    // also closes (and saves) a set being edited
                    Button {
                        focus = nil
                        editingSetId = nil
                    } label: { Text("common.ok", bundle: .l10n) }
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
            .safeAreaInset(edge: .bottom, spacing: 0) {
                RestBar(rest: store.rest)
            }
            .onChange(of: active?.id) { editingSetId = nil }
            // spec §6.6: asked on the first workout; iOS shows it only once
            .task { await store.rest.requestNotificationPermission() }
            .task(id: workout.exercises.map(\.exerciseId)) {
                await store.loadLastPerformance(for: workout.exercises.map(\.exerciseId))
            }
        }
    }

    /// Elapsed time, "N de M séries" and the progress line under the bar.
    private var progressHeader: some View {
        let done = exercises.reduce(0) { $0 + count($1) }
        // planned sets; a set beyond the plan still counts
        let total = exercises.reduce(0) { $0 + max(SetPlan.target($1), count($1)) }
        return VStack(spacing: 8) {
            HStack {
                // startedAt comes from the server, so the clock
                // survives relaunches and matches the web
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(WorkoutFormat.elapsed(Int(context.date.timeIntervalSince(workout.startedAt))))
                }
                Spacer()
                Text("gym.session.setsProgress \(done) \(total)", bundle: .l10n)
            }
            .font(Font.geistMono(12.5, relativeTo: .caption).weight(.medium))
            .foregroundStyle(Color.mutedFg)
            .monospacedDigit()
            ProgressLine(total > 0 ? Double(done) / Double(total) : 0, height: 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 14)
    }

    /// The other exercises, collapsed: still to do first, then the done ones.
    @ViewBuilder private var otherExercises: some View {
        let others = exercises.filter { $0.id != active?.id }
        let next = others.filter { !isDone($0) }
        let done = others.filter(isDone)
        if !next.isEmpty {
            exerciseList(Text("gym.session.upNext", bundle: .l10n), next)
        }
        if !done.isEmpty {
            exerciseList(Text("gym.session.doneExercises", bundle: .l10n), done)
        }
    }

    private func exerciseList(_ title: Text, _ items: [WorkoutExercise]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            CapsTitle(title)
                .padding(.horizontal, 6)
                .padding(.top, 8)
            ForEach(Array(items.enumerated()), id: \.element.id) { index, exercise in
                Button {
                    focus = nil
                    withAnimation(.snappy) { selectedId = exercise.id }
                } label: {
                    CollapsedExerciseRow(exercise: exercise, count: count(exercise), done: isDone(exercise))
                }
                .buttonStyle(.plain)
                if index < items.count - 1 { Hairline() }
            }
        }
    }
}

enum SetField: Hashable {
    case weight(String)
    case reps(String)
    case editWeight(String)
    case editReps(String)
}

/// "Flexão de Braço Unilateral · 3 × 10–12 · 0/3" in "A seguir".
private struct CollapsedExerciseRow: View {
    let exercise: WorkoutExercise
    let count: Int
    let done: Bool
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let target = SetPlan.target(exercise)
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.exerciseName)
                    .font(Font.geist(15.5, relativeTo: .body).weight(.medium))
                    .foregroundStyle(Color.fg)
                if let text = WorkoutFormat.target(sets: target, repsMin: exercise.target?.repsMin, repsMax: exercise.target?.repsMax, lang: language.lang) {
                    Text(text)
                        .font(Font.geist(12.5, relativeTo: .footnote))
                        .foregroundStyle(Color.mutedFg)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if done {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.pos)
            }
            Text(verbatim: "\(count)/\(target)")
                .font(Font.geistMono(12.5, relativeTo: .footnote).weight(.medium))
                .foregroundStyle(Color.mutedFg.opacity(0.75))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

/// The exercise being worked on: header (details on tap), then its sets in
/// order — logged, unconfirmed, the current one (fields + ✓) and the
/// planned rest — and "+ Série".
private struct ActiveExerciseCard: View {
    let exercise: WorkoutExercise
    let position: Int
    let total: Int
    let store: WorkoutStore
    var focus: FocusState<SetField?>.Binding
    @Binding var editingSetId: String?
    let onCompleted: () -> Void
    @State private var confirmingRemove = false
    @State private var expanded = false
    @Environment(AppLanguageStore.self) private var language
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var pending: [WorkoutStore.PendingSet] { store.pendingSets(for: exercise.id) }
    private var done: Int { exercise.sets.count + pending.count }
    private var target: Int { SetPlan.target(exercise) }
    private var nextNumber: Int { done + 1 }
    private var isCompleted: Bool { exercise.completedAt != nil }

    var body: some View {
        let lang = language.lang
        let unit = store.weightUnit
        VStack(alignment: .leading, spacing: 14) {
            header

            VStack(spacing: 6) {
                ForEach(exercise.sets) { set in
                    if editingSetId == set.id {
                        EditSetRow(exerciseId: exercise.id, workoutSet: set, store: store, focus: focus) {
                            editingSetId = nil
                        }
                    } else {
                        Button {
                            focus.wrappedValue = nil
                            editingSetId = set.id
                        } label: {
                            SetLine(number: set.setNumber, text: WorkoutFormat.set(weightKg: set.weightKg, reps: set.reps, unit: unit, lang: lang)) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Color.pos)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(Text("gym.session.editSetHint", bundle: .l10n))
                    }
                }

                ForEach(Array(pending.enumerated()), id: \.element.id) { offset, item in
                    PendingSetRow(number: exercise.sets.count + offset + 1, pending: item, store: store)
                }

                // marked done: no row to log; "Reabrir" brings it back
                if !isCompleted {
                    CurrentSetRow(
                        exercise: exercise,
                        setNumber: nextNumber,
                        proposal: proposal(for: nextNumber),
                        store: store,
                        focus: focus
                    )
                    // a fresh row (empty fields) for every set number
                    .id(nextNumber)
                }

                ForEach(plannedNumbers, id: \.self) { number in
                    let planned = proposal(for: number)
                    SetLine(number: number, text: WorkoutFormat.set(weightKg: planned?.weightKg, reps: planned?.reps, unit: unit, lang: lang)) {
                        Button {
                            setTarget(target - 1)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.mutedFg)
                                .frame(width: 22, height: 22)
                                .overlay {
                                    Circle().strokeBorder(Color.mutedFg.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2.5]))
                                }
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(-11)
                        .accessibilityLabel(Text("gym.session.removeSet", bundle: .l10n))
                    }
                    .opacity(0.6)
                }
            }

            planControls
        }
        .padding(EdgeInsets(top: 18, leading: 16, bottom: 12, trailing: 16))
        .background(Color.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
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

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                withAnimation(reduceMotion ? nil : .snappy) { expanded.toggle() }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("gym.session.exerciseOf \(position) \(total)", bundle: .l10n)
                        .font(DSFont.caption)
                        .foregroundStyle(Color.mutedFg)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(exercise.exerciseName)
                            .font(Font.geist(20, relativeTo: .title3).weight(.semibold))
                            .tracking(-0.3)
                            .foregroundStyle(Color.fg)
                            .multilineTextAlignment(.leading)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.mutedFg)
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                    }
                    if expanded {
                        details
                            .padding(.top, 6)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(Text(expanded ? "gym.session.detailsShown" : "gym.session.detailsHidden", bundle: .l10n))
            .accessibilityHint(Text("gym.session.detailsHint", bundle: .l10n))

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
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.mutedFg)
                    .frame(width: 32, height: 32)
                    .overlay { Circle().strokeBorder(Color.border, lineWidth: 1.5) }
            }
            .accessibilityLabel(Text("gym.session.exerciseOptions \(exercise.exerciseName)", bundle: .l10n))
        }
    }

    /// Meta, every set of the last session and the routine's rest.
    private var details: some View {
        let lang = language.lang
        var rows: [(LocalizedStringKey, String)] = []
        if let text = WorkoutFormat.target(sets: target, repsMin: exercise.target?.repsMin, repsMax: exercise.target?.repsMax, lang: lang) {
            rows.append(("gym.session.detailTarget", text))
        }
        if let last = store.lastPerformance[exercise.exerciseId], let text = SetPlan.lastTime(last, unit: store.weightUnit, lang: lang) {
            rows.append(("gym.session.detailLastTime", text))
        }
        if let rest = exercise.target?.restSeconds {
            rows.append(("gym.session.detailRest", WorkoutFormat.elapsed(rest)))
        }
        return VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(row.0, bundle: .l10n)
                        .font(DSFont.meta)
                        .foregroundStyle(Color.mutedFg)
                        .frame(width: 78, alignment: .leading)
                    Text(row.1)
                        .font(Font.geistMono(13, relativeTo: .footnote).weight(.medium))
                        .foregroundStyle(Color.fg)
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }

    /// Open: "+ Série" (and − when the only planned set left is the current
    /// one — the planned rows carry their own ×) and "Concluir exercício".
    /// Done: "Reabrir exercício".
    @ViewBuilder private var planControls: some View {
        HStack(spacing: 14) {
            if isCompleted {
                Label { Text("gym.session.exerciseDone", bundle: .l10n) } icon: { Image(systemName: "checkmark.circle.fill") }
                    .foregroundStyle(Color.pos)
                Spacer()
                Button {
                    Task { await store.setCompleted(workoutExerciseId: exercise.id, false) }
                } label: {
                    Text("gym.session.reopenExercise", bundle: .l10n)
                }
                .buttonStyle(.chip)
            } else {
                Button {
                    // past the plan, the current row counts as planned first
                    setTarget(max(target, nextNumber) + 1)
                } label: {
                    Label { Text("gym.session.addSet", bundle: .l10n) } icon: { Image(systemName: "plus") }
                }
                .disabled(!SetPlan.canAdd(target: max(target, nextNumber)))
                if plannedNumbers.isEmpty, SetPlan.canRemove(target: target, done: done) {
                    Button {
                        setTarget(target - 1)
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 28, height: 28)
                    }
                    .accessibilityLabel(Text("gym.session.removeSet", bundle: .l10n))
                }
                Spacer()
                Button {
                    editingSetId = nil
                    focus.wrappedValue = nil
                    onCompleted()
                    Task { await store.setCompleted(workoutExerciseId: exercise.id, true) }
                } label: {
                    Label { Text("gym.session.completeExercise", bundle: .l10n) } icon: { Image(systemName: "checkmark") }
                }
                .buttonStyle(.chip)
            }
        }
        .buttonStyle(.plain)
        .font(Font.geist(13.5, relativeTo: .subheadline).weight(.medium))
        .foregroundStyle(Color.accTx)
        .padding(.leading, 12)
        .frame(minHeight: 36)
    }

    private func setTarget(_ sets: Int) {
        Task { await store.setTargetSets(workoutExerciseId: exercise.id, sets) }
    }

    /// set numbers after the current one still within the plan
    private var plannedNumbers: [Int] {
        guard !isCompleted, target > nextNumber else { return [] }
        return Array((nextNumber + 1)...target)
    }

    private func proposal(for setNumber: Int) -> SetProposal? {
        let previous = pending.last.map { ($0.weightKg, $0.reps) }
            ?? exercise.sets.last.map { ($0.weightKg, $0.reps) }
        return SetProposal.propose(
            setNumber: setNumber,
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
        HStack(spacing: 12) {
            Text(verbatim: "\(number)")
                .font(Font.geistMono(14, relativeTo: .body).weight(.medium))
                .foregroundStyle(Color.mutedFg)
                .frame(width: 22, alignment: .leading)
            Text(text)
                .font(Font.geistMono(15, relativeTo: .body).weight(.medium))
                .foregroundStyle(Color.fg)
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
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
                Menu {
                    Button {
                        Task { await store.retry(pending) }
                    } label: {
                        Text("gym.session.resend", bundle: .l10n)
                    }
                    Button(role: .destructive) { store.dropPending(pending) } label: { Text("gym.session.discard", bundle: .l10n) }
                } label: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.neg)
                } primaryAction: {
                    Task { await store.retry(pending) }
                }
                .accessibilityLabel(Text("gym.session.resend", bundle: .l10n))
            } else {
                ProgressView()
                    .frame(width: 22, height: 22)
            }
        }
    }
}

/// Weight field + unit, reps field + "reps", in the current/editing rows.
private struct SetFields: View {
    @Binding var weightText: String
    @Binding var repsText: String
    let weightPlaceholder: String?
    let repsPlaceholder: String?
    let unit: WeightUnit
    let weightFocus: SetField
    let repsFocus: SetField
    var focus: FocusState<SetField?>.Binding

    var body: some View {
        field(UnitConversion.label(unit), text: $weightText, placeholder: weightPlaceholder, keyboard: .decimalPad, width: 56)
            .focused(focus, equals: weightFocus)
        field("reps", text: $repsText, placeholder: repsPlaceholder, keyboard: .numberPad, width: 46)
            .focused(focus, equals: repsFocus)
    }

    private func field(_ unit: String, text: Binding<String>, placeholder: String?, keyboard: UIKeyboardType, width: CGFloat) -> some View {
        HStack(spacing: 4) {
            TextField(placeholder ?? "–", text: text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.center)
                .font(Font.geistMono(17, relativeTo: .body).weight(.medium))
                .frame(width: width, height: 40)
                .background(Color.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.border, lineWidth: 1) }
            Text(unit)
                .font(DSFont.caption)
                .foregroundStyle(Color.mutedFg)
        }
    }
}

/// The current set: empty fields whose placeholders are the proposal —
/// tapping ✓ without typing logs the proposal (same as the web's grid).
private struct CurrentSetRow: View {
    let exercise: WorkoutExercise
    let setNumber: Int
    let proposal: SetProposal?
    let store: WorkoutStore
    var focus: FocusState<SetField?>.Binding
    @State private var weightText = ""
    @State private var repsText = ""
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let unit = store.weightUnit
        HStack(spacing: 10) {
            Text(verbatim: "\(setNumber)")
                .font(Font.geistMono(14, relativeTo: .body).weight(.semibold))
                .foregroundStyle(Color.fg)
                .frame(width: 22, alignment: .leading)
            SetFields(
                weightText: $weightText, repsText: $repsText,
                weightPlaceholder: proposal?.weightKg.map { WorkoutFormat.weight($0, unit: unit, lang: language.lang) },
                repsPlaceholder: proposal?.reps.map(String.init),
                unit: unit, weightFocus: .weight(exercise.id), repsFocus: .reps(exercise.id), focus: focus
            )
            Spacer(minLength: 0)
            ConfirmSetButton(label: Text("gym.session.log", bundle: .l10n), enabled: canLog) {
                let values = resolved
                focus.wrappedValue = nil
                Task { await store.addSet(workoutExerciseId: exercise.id, weightKg: values.weightKg, reps: values.reps) }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.pageBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

/// A logged set opened in place (`PATCH`/`DELETE .../sets/:setId`): its
/// values in the fields, ✓ saves, holding the trash deletes.
private struct EditSetRow: View {
    let exerciseId: String
    let workoutSet: WorkoutSet
    let store: WorkoutStore
    var focus: FocusState<SetField?>.Binding
    let onClose: () -> Void
    @State private var weightText: String
    @State private var repsText: String
    @State private var holdHint = false
    /// saved with ✓ or deleted: nothing left to save when the row goes away
    @State private var settled = false

    init(exerciseId: String, workoutSet: WorkoutSet, store: WorkoutStore, focus: FocusState<SetField?>.Binding, onClose: @escaping () -> Void) {
        self.exerciseId = exerciseId
        self.workoutSet = workoutSet
        self.store = store
        self.focus = focus
        self.onClose = onClose
        // the decimal pad types the app language's separator
        let lang = AppLanguageStore.shared.lang
        _weightText = State(initialValue: workoutSet.weightKg.map { WorkoutFormat.weight($0, unit: store.weightUnit, lang: lang) } ?? "")
        _repsText = State(initialValue: workoutSet.reps.map(String.init) ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(verbatim: "\(workoutSet.setNumber)")
                    .font(Font.geistMono(14, relativeTo: .body).weight(.semibold))
                    .foregroundStyle(Color.fg)
                    .frame(width: 22, alignment: .leading)
                SetFields(
                    weightText: $weightText, repsText: $repsText,
                    weightPlaceholder: nil, repsPlaceholder: nil,
                    unit: store.weightUnit,
                    weightFocus: .editWeight(workoutSet.id), repsFocus: .editReps(workoutSet.id), focus: focus
                )
                Spacer(minLength: 0)
                HoldToDeleteButton(showHint: $holdHint) {
                    settled = true
                    focus.wrappedValue = nil
                    onClose()
                    Task { await store.deleteSet(workoutExerciseId: exerciseId, setId: workoutSet.id) }
                }
                ConfirmSetButton(label: Text("common.save", bundle: .l10n), enabled: isValid) {
                    save()
                    focus.wrappedValue = nil
                    onClose()
                }
            }
            if holdHint {
                Text("gym.session.holdToDelete", bundle: .l10n)
                    .font(DSFont.caption)
                    .foregroundStyle(Color.mutedFg)
                    .padding(.leading, 30)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            // taps on the row's own empty space don't count as "elsewhere"
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.pageBg)
                .onTapGesture {}
        }
        .animation(.easeOut(duration: 0.2), value: holdHint)
        // closed by a tap elsewhere, another set, the keyboard's OK or the
        // exercise switching: same as ✓
        .onDisappear { save() }
    }

    /// PATCH when the values are valid and changed; once per row
    private func save() {
        guard !settled else { return }
        settled = true
        guard isValid else { return }
        let weightKg = SetInput.editedWeightKg(
            weightText, original: workoutSet.weightKg,
            unit: store.weightUnit, lang: AppLanguageStore.shared.lang
        )
        let reps = SetInput.reps(repsText)
        guard weightKg != workoutSet.weightKg || reps != workoutSet.reps else { return }
        Task { await store.updateSet(workoutExerciseId: exerciseId, setId: workoutSet.id, weightKg: weightKg, reps: reps) }
    }

    private var isValid: Bool {
        (weightText.isEmpty || SetInput.weight(weightText) != nil)
            && (repsText.isEmpty || SetInput.reps(repsText) != nil)
            && !(weightText.isEmpty && repsText.isEmpty)
    }
}

/// The accent ✓ that commits a set, logging the current one or saving an
/// edit; a logged set shows the green ✓ in the same spot.
private struct ConfirmSetButton: View {
    let label: Text
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.accFg)
                .frame(width: 40, height: 40)
                .background(Color.acc, in: Circle())
                .opacity(enabled ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

/// Trash confirmed by holding 1.2 s (same gesture as the account menu's sign
/// out): a ring fills around the icon while pressed and snaps back if let go
/// early, which also shows "Segure para apagar".
private struct HoldToDeleteButton: View {
    @Binding var showHint: Bool
    let onComplete: () -> Void
    private let duration = 1.2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fill: CGFloat = 0
    @State private var done = false
    @State private var hintTask: Task<Void, Never>?

    var body: some View {
        Image(systemName: "trash")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Color.neg)
            .frame(width: 36, height: 36)
            .background(Color.neg.opacity(0.1 + 0.15 * fill), in: Circle())
            .overlay {
                Circle()
                    .trim(from: 0, to: fill)
                    .stroke(Color.neg, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(1.25)
            }
            .contentShape(Circle())
            .onLongPressGesture(minimumDuration: duration, maximumDistance: 30) {
                done = true
                fill = 1
                onComplete()
            } onPressingChanged: { pressing in
                if pressing {
                    hintTask?.cancel()
                    withAnimation(.linear(duration: duration)) { fill = 1 }
                } else {
                    // a completed hold also reports "not pressing" — give the
                    // `perform` closure its turn before snapping back
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(60))
                        guard !done else { return }
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) { fill = 0 }
                        showHint = true
                        hintTask = Task { @MainActor in
                            try? await Task.sleep(for: .seconds(1.6))
                            if !Task.isCancelled { showHint = false }
                        }
                    }
                }
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: done)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("gym.entry.deleteSet", bundle: .l10n))
            .accessibilityAddTraits(.isButton)
            // VoiceOver's double-tap is already deliberate
            .accessibilityAction { onComplete() }
    }
}
