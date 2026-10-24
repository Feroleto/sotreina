import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// Criar conta (spec login-app-ios §3.2), pushed from Entrar: name, email
/// and password, no "confirm password" (iOS suggests a strong one and saves
/// it). Success signs in, and `RootView` shows the area picker (a new
/// account has no areas yet).
struct RegisterView: View {
    @Environment(SessionStore.self) private var session
    @Binding var email: String
    let onSignedIn: (Me) -> Void
    @State private var firstName = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var failure: Failure?
    @FocusState private var focus: Field?
    /// UIKit field, outside the `FocusState` (see `EntryPasswordField`)
    @State private var passwordFocused = false

    private enum Field: Hashable {
        case name
        case email
    }

    private enum Failure {
        case form(RegisterProblem)
        case emailInUse
        case other
    }

    private var canSubmit: Bool {
        !isSubmitting && !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    var body: some View {
        EntryScroll(submitID: "submit", focused: focus != nil || passwordFocused) {
            EntryHeading(title: "auth.login.submitRegister", subtitle: "auth.login.formSubtitleRegister")
                .padding(.top, 12)

            VStack(spacing: 12) {
                TextField(text: $firstName) {
                    Text("auth.login.namePlaceholder", bundle: .l10n).foregroundStyle(Color.mutedFg)
                }
                .textContentType(.givenName)
                .submitLabel(.next)
                .focused($focus, equals: .name)
                .onSubmit { focus = .email }
                .entryFieldBox()

                TextField(text: $email) {
                    Text("auth.login.emailLabel", bundle: .l10n).foregroundStyle(Color.mutedFg)
                }
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($focus, equals: .email)
                .onSubmit { passwordFocused = true }
                .entryFieldBox()

                EntryPasswordField(
                    label: "auth.login.passwordLabel", text: $password, isNew: true,
                    isFocused: $passwordFocused
                ) {
                    if canSubmit { Task { await submit() } }
                }
            }
            .padding(.top, 28)

            if let failure {
                failureView(failure)
                    .padding(.top, 10)
            }

            // the link is markdown inside the localized string
            Text("auth.register.consent", bundle: .l10n)
                .font(Font.geist(13, relativeTo: .footnote))
                .foregroundStyle(Color.mutedFg)
                .tint(Color.accTx)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)

            Button {
                Task { await submit() }
            } label: {
                if isSubmitting {
                    ProgressView().tint(Color.accFg)
                } else {
                    Text("auth.login.submitRegister", bundle: .l10n)
                }
            }
            .buttonStyle(EntryButtonStyle())
            .disabled(!canSubmit)
            .padding(.top, 14)
            .id("submit")
        }
        .entryPushedScreen()
    }

    @ViewBuilder
    private func failureView(_ failure: Failure) -> some View {
        switch failure {
        case .form(.emailMissing), .other:
            EntryError(text: Text("auth.login.genericError", bundle: .l10n))
        case .form(.passwordTooShort):
            EntryError(text: Text("auth.login.passwordTooShort", bundle: .l10n))
        case .emailInUse:
            EntryError(text: Text("auth.login.emailInUse", bundle: .l10n))
        }
    }

    private func submit() async {
        if let problem = EntryForm.registerProblem(email: email, password: password) {
            failure = .form(problem)
            if problem == .passwordTooShort { passwordFocused = true }
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        failure = nil

        do {
            let me = try await session.register(
                RegisterRequest(email: email, password: password, firstName: firstName),
                baseURL: APIClient.storedBaseURL
            )
            onSignedIn(me)
        } catch APIError.http(status: 409) {
            // the password wasn't the problem: keep the fields
            failure = .emailInUse
            focus = .email
        } catch {
            failure = .other
        }
    }
}
