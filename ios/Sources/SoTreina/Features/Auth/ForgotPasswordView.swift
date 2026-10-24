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
    @State private var isSubmitting = false
    @State private var sent = false
    @FocusState private var focused: Bool

    private var canSubmit: Bool {
        !isSubmitting && !email.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        EntryScroll(submitID: "submit", focused: focused) {
            EntryHeading(
                title: "auth.login.forgotTitle",
                subtitle: sent ? "auth.login.forgotSuccess" : "auth.login.forgotSubtitle"
            )
            .padding(.top, 12)

            TextField(text: $email) {
                Text("auth.login.emailLabel", bundle: .l10n).foregroundStyle(Color.mutedFg)
            }
            .textContentType(.username)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.send)
            .focused($focused)
            .onSubmit { if canSubmit { Task { await submit() } } }
            .entryFieldBox()
            .disabled(sent)
            .opacity(sent ? 0.6 : 1)
            .padding(.top, 28)

            if !sent {
                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView().tint(Color.accFg)
                    } else {
                        Text("auth.login.forgotSubmit", bundle: .l10n)
                    }
                }
                .buttonStyle(EntryButtonStyle())
                .disabled(!canSubmit)
                .padding(.top, 14)
                .id("submit")
            }
        }
        .entryPushedScreen()
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        try? await session.requestPasswordReset(email: email, baseURL: APIClient.storedBaseURL)
        focused = false
        sent = true
    }
}
