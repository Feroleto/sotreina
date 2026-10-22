import SwiftUI
import SoTreinaKit

/// Account + diagnostics, opened from the routines toolbar. The Live
/// Activity buttons are the Fase 0 spike, kept until Fase 2 wires the real
/// rest timer into the session.
struct SettingsView: View {
    let me: Me
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var liveActivity = LiveActivityController()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Olá, \(me.firstName ?? "atleta")")
                        .font(.title2.bold())
                    LabeledContent("Strava", value: me.hasStravaAccount ? "conectado" : "não conectado")
                    LabeledContent("Servidor", value: APIClient.storedBaseURL.host() ?? "—")
                }

                Section {
                    Button("Iniciar descanso de 60s") { liveActivity.startRest(seconds: 60) }
                    Button("+15s") { liveActivity.addRest(seconds: 15) }
                        .disabled(!liveActivity.isRunning)
                    Button("Encerrar Live Activity", role: .destructive) {
                        Task { await liveActivity.end() }
                    }
                    .disabled(!liveActivity.isRunning)
                } header: {
                    Text("Live Activity (teste)")
                } footer: {
                    if let status = liveActivity.status {
                        Text(status)
                    }
                }

                Section {
                    Button("Sair", role: .destructive) {
                        Task {
                            await liveActivity.end()
                            await session.logout()
                        }
                    }
                }
            }
            .navigationTitle("Conta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }
}
