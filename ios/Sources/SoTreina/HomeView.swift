import SwiftUI
import SoTreinaKit

/// Fase 0 spike screen: proves login + Bearer + Live Activity on device.
struct HomeView: View {
    let me: Me
    @Environment(SessionStore.self) private var session
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
                    Text("Live Activity")
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
            .navigationTitle("SoTreina")
        }
    }
}
