import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// `POST /auth/forgot-password`. The answer is the same whether or not the
/// email exists, and a network error shows it too (the web's `finally`):
/// the screen never tells whether an account exists. The link in the email
/// opens the web's `/redefinir-senha`.
struct ForgotPasswordView: View {
    @Environment(SessionStore.self) private var session
    @State var email: String
    let baseURL: String
    @State private var isSubmitting = false
    @State private var sent = false

    var body: some View {
        Form {
            Section {
                TextField(text: $email) { Text("auth.login.emailLabel", bundle: .l10n) }
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(sent)
            } footer: {
                Text(sent ? "auth.login.forgotSuccess" : "auth.login.forgotSubtitle", bundle: .l10n)
                    .font(DSFont.caption)
            }

            if !sent {
                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView().tint(Color.accFg)
                        } else {
                            Text("auth.login.forgotSubmit", bundle: .l10n)
                        }
                    }
                    .buttonStyle(.primary)
                    .disabled(email.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
        }
        .monolitoForm()
        .navigationTitle(Text("auth.login.forgotTitle", bundle: .l10n))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit() async {
        guard let url = URL(string: baseURL.trimmingCharacters(in: .whitespaces)) else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        try? await session.requestPasswordReset(email: email, baseURL: url)
        sent = true
    }
}
