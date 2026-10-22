import SwiftUI
import SoTreinaKit

/// Search the exercise library (`GET /exercises?search=`) and add one to the
/// open workout. The server matches the PT and the English name.
struct ExercisePickerView: View {
    let store: WorkoutStore
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [ExerciseListItem] = []
    @State private var isSearching = false
    @State private var failed = false
    @State private var adding: String?

    var body: some View {
        NavigationStack {
            List(results) { exercise in
                Button {
                    adding = exercise.id
                    Task {
                        await store.addExercise(exerciseId: exercise.id)
                        dismiss()
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name)
                                .foregroundStyle(.primary)
                            Text(exercise.primaryMuscles.map(MuscleGroup.label).joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if adding == exercise.id { ProgressView() }
                    }
                }
                .disabled(adding != nil)
            }
            .overlay {
                if failed {
                    ContentUnavailableView("Não carregou", systemImage: "wifi.exclamationmark",
                                           description: Text("Verifique a conexão e tente de novo."))
                } else if !isSearching, results.isEmpty, !query.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar exercício")
            .navigationTitle("Adicionar exercício")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .task(id: query) { await search() }
        }
    }

    private func search() async {
        // debounce: .task(id:) cancels this when the query changes again
        if !query.isEmpty {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
        }
        isSearching = true
        defer { isSearching = false }
        do {
            var items = [URLQueryItem(name: "limit", value: "40")]
            let trimmed = query.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { items.append(URLQueryItem(name: "search", value: trimmed)) }
            let page: ExercisePage? = try await session.api.get("exercises", query: items)
            guard !Task.isCancelled else { return }
            results = page?.items ?? []
            failed = false
        } catch is CancellationError {
            return
        } catch {
            if (error as? URLError)?.code == .cancelled { return }
            if case APIError.unauthorized = error { session.expire() }
            failed = true
        }
    }
}
