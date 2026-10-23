import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// Search the exercise library (`GET /exercises?search=`) and pick one: the
/// open workout adds it, the Visão geral reads its personal record. The
/// server matches the PT and the English name.
struct ExercisePickerView: View {
    var title: LocalizedStringKey = "gym.picker.title"
    /// runs before the sheet closes (the row spins meanwhile)
    let onPick: (ExerciseListItem) async -> Void
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Environment(AppLanguageStore.self) private var language
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
                        await onPick(exercise)
                        dismiss()
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name)
                                .font(DSFont.row)
                                .foregroundStyle(Color.fg)
                            Text(exercise.primaryMuscles.map { MuscleGroup.label($0, lang: language.lang) }.joined(separator: " · "))
                                .font(DSFont.caption)
                                .foregroundStyle(Color.mutedFg)
                        }
                        Spacer()
                        if adding == exercise.id { ProgressView() }
                    }
                }
                .disabled(adding != nil)
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
                } else if !isSearching, results.isEmpty, !query.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("gym.picker.searchPlaceholder", bundle: .l10n))
            .navigationTitle(Text(title, bundle: .l10n))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.cancel", bundle: .l10n) }
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
