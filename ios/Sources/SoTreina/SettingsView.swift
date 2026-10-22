import SwiftUI
import SoTreinaKit

/// Account, opened from the routines toolbar.
struct SettingsView: View {
    let me: Me
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

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
                    Button("Sair", role: .destructive) {
                        Task { await session.logout() }
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
