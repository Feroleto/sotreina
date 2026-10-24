import SoTreinaDesign
import SwiftUI

/// The API server, out of the login screen (spec login-app-ios §3.1): a
/// long press on the logo opens it. Lets the same build hit production or a
/// dev server reachable from the phone (e.g. the PC's LAN IP).
struct ServerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var url = APIClient.storedBaseURL.absoluteString
    @State private var invalid = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(text: $url) { Text("auth.login.apiURL", bundle: .l10n) }
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(Font.geistMono(13, relativeTo: .footnote))
                        .onChange(of: url) { invalid = false }
                } footer: {
                    if invalid {
                        Text("auth.login.invalidURL", bundle: .l10n).foregroundStyle(Color.neg)
                    }
                }

                Section {
                    Button {
                        url = APIClient.defaultBaseURL.absoluteString
                    } label: {
                        Text("auth.server.useProduction", bundle: .l10n)
                    }
                    .disabled(url == APIClient.defaultBaseURL.absoluteString)
                }
            }
            .monolitoForm()
            .navigationTitle(Text("auth.login.server", bundle: .l10n))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.cancel", bundle: .l10n) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { save() } label: { Text("common.save", bundle: .l10n) }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        let trimmed = url.trimmingCharacters(in: .whitespaces)
        guard let parsed = URL(string: trimmed), ["http", "https"].contains(parsed.scheme), parsed.host() != nil else {
            invalid = true
            return
        }
        APIClient.storedBaseURL = parsed
        dismiss()
    }
}
