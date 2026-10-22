import SwiftUI
import SoTreinaKit

/// Read-only list of the user's routines with "Iniciar" (spec §6.4, tela 2).
/// Creating and editing routines stays on the web.
struct RoutinesView: View {
    let store: WorkoutStore
    let me: Me
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Rotinas")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "person.crop.circle")
                        }
                        .accessibilityLabel("Conta")
                    }
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView(me: me)
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
                Label("Não carregou", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Tentar de novo") { Task { await store.load() } }
                    .buttonStyle(.borderedProminent)
            }
        default:
            if store.templates.isEmpty {
                ContentUnavailableView(
                    "Nenhuma rotina",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Crie suas rotinas no SoTreina pela web e elas aparecem aqui.")
                )
                .refreshable { await store.load() }
            } else {
                list
            }
        }
    }

    private var list: some View {
        List(store.templates) { template in
            RoutineRow(
                template: template,
                isNext: template.id == store.nextRoutineId && store.templates.count > 1,
                isStarting: store.startingTemplateId == template.id,
                isDisabled: store.startingTemplateId != nil
            ) {
                Task { await store.start(templateId: template.id) }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await store.load() }
    }
}

private struct RoutineRow: View {
    let template: TemplateSummary
    let isNext: Bool
    let isStarting: Bool
    let isDisabled: Bool
    let onStart: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(template.name)
                        .font(.headline)
                    if isNext {
                        Text("Próxima")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.tint.opacity(0.15), in: Capsule())
                            .foregroundStyle(.tint)
                    }
                }
                if !template.muscleGroups.isEmpty {
                    Text(template.muscleGroups.map(MuscleGroup.label).joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text("\(exerciseCount) · \(RoutineFormat.lastPerformed(template.lastPerformedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button(action: onStart) {
                if isStarting {
                    ProgressView()
                        .frame(minWidth: 56)
                } else {
                    Text("Iniciar")
                        .frame(minWidth: 56)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isDisabled)
        }
        .padding(.vertical, 4)
    }

    private var exerciseCount: String {
        template.exerciseCount == 1 ? "1 exercício" : "\(template.exerciseCount) exercícios"
    }
}
