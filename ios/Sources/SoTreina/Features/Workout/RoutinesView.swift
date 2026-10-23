import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// Treino › Rotinas: the user's routines with "Iniciar" (spec §6.4, tela 2),
/// and a last row for a free workout (no routine) — app only, a registered
/// exception to web parity.
/// Tapping a routine (outside "Iniciar") pushes its detail. Creating and
/// editing routines stays on the web for now. Lives under the area header of
/// `AreaScreen`, which owns the navigation stack.
struct RoutinesView: View {
    let store: WorkoutStore
    /// the routine whose detail is pushed
    @State private var viewingId: String?

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.pageBg)
            .navigationDestination(item: $viewingId) { id in
                if let template = store.templates.first(where: { $0.id == id }) {
                    RoutineDetailView(template: template, store: store)
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch store.loadState {
        // a reload with routines on screen keeps the list (refreshable shows its own spinner)
        case .idle:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loading where store.templates.isEmpty:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView {
                Label { Text("gym.routines.loadFailed", bundle: .l10n) } icon: { Image(systemName: "wifi.exclamationmark") }
            } description: {
                Text(message)
            } actions: {
                Button { Task { await store.load() } } label: { Text("common.retry", bundle: .l10n) }
                    .buttonStyle(.pill)
            }
        default:
            if store.templates.isEmpty {
                ContentUnavailableView {
                    Label { Text("gym.routines.emptyTitle", bundle: .l10n) } icon: { Image(systemName: "list.bullet.rectangle") }
                } description: {
                    Text("gym.routines.emptyBody", bundle: .l10n)
                } actions: {
                    Button { Task { await store.start(templateId: nil) } } label: {
                        Text("gym.routines.startFree", bundle: .l10n)
                    }
                    .buttonStyle(.pill)
                    .disabled(store.startingTemplateId != nil)
                }
                .refreshable { await store.load() }
            } else {
                list
            }
        }
    }

    private var list: some View {
        List {
            ForEach(store.templates) { template in
                RoutineRow(
                    template: template,
                    isNext: template.id == store.nextRoutineId && store.templates.count > 1,
                    isStarting: store.startingTemplateId == template.id,
                    isDisabled: store.startingTemplateId != nil,
                    onOpen: { viewingId = template.id }
                ) {
                    Task { await store.start(templateId: template.id) }
                }
            }
            FreeWorkoutRow(
                // `start(templateId: nil)` marks itself with ""
                isStarting: store.startingTemplateId == "",
                isDisabled: store.startingTemplateId != nil
            ) {
                Task { await store.start(templateId: nil) }
            }
        }
        .monolitoList()
        .refreshable { await store.load() }
    }
}

private struct RoutineRow: View {
    let template: TemplateSummary
    let isNext: Bool
    let isStarting: Bool
    let isDisabled: Bool
    let onOpen: () -> Void
    let onStart: () -> Void
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let lang = language.lang
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(template.name)
                        .font(DSFont.rowTitle)
                        .tracking(-0.17)
                        .lineLimit(1)
                    if isNext { Badge(L10n.string("gym.routines.next", lang: lang)) }
                }
                if !template.muscleGroups.isEmpty {
                    Text(template.muscleGroups.map { MuscleGroup.label($0, lang: lang) }.joined(separator: " · "))
                        .font(DSFont.meta)
                        .foregroundStyle(Color.mutedFg)
                        .lineLimit(1)
                }
                Text(verbatim: "\(L10n.string("gym.routines.exerciseCount %lld", lang: lang, template.exerciseCount)) · \(RoutineFormat.lastPerformed(template.lastPerformedAt, lang: lang))")
                    .font(DSFont.caption)
                    .foregroundStyle(Color.mutedFg)
            }

            Spacer(minLength: 8)

            Button(action: onStart) {
                if isStarting {
                    ProgressView()
                        .tint(Color.accFg)
                        .frame(minWidth: 52)
                } else {
                    Text("gym.routines.start", bundle: .l10n)
                        .frame(minWidth: 52)
                }
            }
            .buttonStyle(.pill)
            .disabled(isDisabled)
        }
        .padding(.vertical, 10)
        // the whole row opens the detail; "Iniciar" keeps its own tap
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .accessibilityAction(named: Text("gym.routineDetail.open", bundle: .l10n), onOpen)
        .listRowInsets(EdgeInsets(top: 0, leading: pageGutter, bottom: 0, trailing: pageGutter))
        .listRowBackground(Color.pageBg)
    }
}

/// "Treino livre": a workout with no routine, exercises added as it goes.
private struct FreeWorkoutRow: View {
    let isStarting: Bool
    let isDisabled: Bool
    let onStart: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("gym.freeWorkout", bundle: .l10n)
                    .font(DSFont.rowTitle)
                    .tracking(-0.17)
                Text("gym.routines.freeHint", bundle: .l10n)
                    .font(DSFont.caption)
                    .foregroundStyle(Color.mutedFg)
            }

            Spacer(minLength: 8)

            Button(action: onStart) {
                if isStarting {
                    ProgressView()
                        .tint(Color.accFg)
                        .frame(minWidth: 52)
                } else {
                    Text("gym.routines.start", bundle: .l10n)
                        .frame(minWidth: 52)
                }
            }
            .buttonStyle(.pill)
            .disabled(isDisabled)
        }
        .padding(.vertical, 10)
        .listRowInsets(EdgeInsets(top: 0, leading: pageGutter, bottom: 0, trailing: pageGutter))
        .listRowBackground(Color.pageBg)
    }
}
