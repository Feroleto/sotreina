import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// The routine editor's "Adicionar exercício" (web RoutineExercisePicker):
/// search plus muscle chips, multi-select — a tap adds the exercise (3 ×
/// 10–12) or removes it if it's already in the routine — with a running
/// count, closed with Concluído.
struct RoutineExercisePickerView: View {
    @Binding var draft: RoutineDraft
    let store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @Environment(AppLanguageStore.self) private var language
    @State private var query = ""
    @State private var filter: MuscleFilter = .all
    @State private var results: [ExerciseListItem] = []
    @State private var isSearching = true
    @State private var failed = false

    private struct SearchKey: Equatable {
        let query: String
        let filter: MuscleFilter
    }

    var body: some View {
        let lang = language.lang
        NavigationStack {
            List {
                Group {
                    VStack(alignment: .leading, spacing: 10) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(MuscleFilter.allCases, id: \.self) { option in
                                    Button { filter = option } label: {
                                        Chip(option.label(lang), selected: filter == option)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(filter == option ? .isSelected : [])
                                }
                            }
                            .padding(.horizontal, pageGutter)
                        }
                        .padding(.horizontal, -pageGutter)
                        Text("gym.editor.selected \(draft.exercises.count)", bundle: .l10n)
                            .font(DSFont.caption)
                            .foregroundStyle(Color.mutedFg)
                    }
                    .padding(.vertical, 8)
                    .listRowSeparator(.hidden)

                    ForEach(results) { exercise in
                        let selected = draft.contains(exerciseId: exercise.id)
                        Button { draft.toggle(exercise) } label: {
                            PickerRow(exercise: exercise, selected: selected)
                        }
                        .buttonStyle(.plain)
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: pageGutter, bottom: 0, trailing: pageGutter))
                .listRowBackground(Color.pageBg)
            }
            .monolitoList()
            .overlay {
                if failed {
                    ContentUnavailableView {
                        Label { Text("gym.picker.loadFailed", bundle: .l10n) } icon: { Image(systemName: "wifi.exclamationmark") }
                    } description: {
                        Text("gym.picker.checkConnection", bundle: .l10n)
                    }
                } else if isSearching, results.isEmpty {
                    ProgressView()
                } else if results.isEmpty {
                    Text("gym.picker.empty", bundle: .l10n)
                        .font(DSFont.meta)
                        .foregroundStyle(Color.mutedFg)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("gym.picker.searchPlaceholder", bundle: .l10n))
            .navigationTitle(Text("gym.editor.addExercise", bundle: .l10n))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text("gym.editor.done", bundle: .l10n).bold() }
                }
            }
            .task(id: SearchKey(query: query, filter: filter)) { await search() }
        }
    }

    private func search() async {
        // debounce typing: .task(id:) cancels this when the key changes again
        if !query.isEmpty {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
        }
        isSearching = true
        defer { isSearching = false }
        do {
            let items = try await store.searchExercises(query, filter: filter)
            guard !Task.isCancelled else { return }
            results = items
            failed = false
        } catch is CancellationError {
            return
        } catch {
            if (error as? URLError)?.code == .cancelled { return }
            failed = true
        }
    }
}

/// name / first muscle · + or ✓
private struct PickerRow: View {
    let exercise: ExerciseListItem
    let selected: Bool
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(DSFont.row.weight(.semibold))
                    .foregroundStyle(Color.fg)
                    .lineLimit(1)
                if let muscle = exercise.primaryMuscles.first {
                    Text(MuscleGroup.label(muscle, lang: language.lang))
                        .font(DSFont.caption)
                        .foregroundStyle(Color.mutedFg)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: selected ? "checkmark" : "plus")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(selected ? Color.accFg : Color.mutedFg)
                .frame(width: 26, height: 26)
                .background(selected ? Color.acc : Color.chip, in: Circle())
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
