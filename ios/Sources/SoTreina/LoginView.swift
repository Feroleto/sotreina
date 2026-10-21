import SwiftUI

struct LoginView: View {
    @Environment(SessionStore.self) private var session
    @State private var email = ""
    @State private var password = ""
    @State private var baseURL = APIClient.storedBaseURL.absoluteString
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Senha", text: $password)
                        .textContentType(.password)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Entrar").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty || isSubmitting)
                }

                // spike-only: lets the same build hit production or a dev
                // server reachable from the phone (e.g. the PC's LAN IP)
                Section("Servidor") {
                    TextField("URL da API", text: $baseURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.footnote.monospaced())
                }
            }
            .navigationTitle("SoTreina")
        }
    }

    private func submit() async {
        guard let url = URL(string: baseURL.trimmingCharacters(in: .whitespaces)) else {
            errorMessage = "URL da API inválida"
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        errorMessage = nil

        do {
            try await session.login(email: email, password: password, baseURL: url)
        } catch APIError.unauthorized {
            errorMessage = "Email ou senha incorretos"
            password = ""
        } catch {
            errorMessage = "Não foi possível entrar: \(error.localizedDescription)"
        }
    }
}
