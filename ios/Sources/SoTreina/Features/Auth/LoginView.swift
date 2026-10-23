import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// Entrada (spec §3, Fase S): Entrar / Criar conta with email and password,
/// "Esqueci a senha" pushed on top. No Strava sign-in in the app: a
/// Strava-only account adds a password on the web first (spec §2).
struct LoginView: View {
    @Environment(SessionStore.self) private var session
    @State private var mode: Mode = .login
    @State private var firstName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var baseURL = APIClient.storedBaseURL.absoluteString
    @State private var isSubmitting = false
    @State private var failure: Failure?

    private enum Mode: Hashable {
        case login
        case register
    }

    /// Kept as a case, not text, so a language change also redraws it.
    private enum Failure {
        case invalidURL
        case invalidCredentials
        case form(RegisterProblem)
        case emailInUse
        case other
    }

    private var registerProblem: RegisterProblem? {
        EntryForm.registerProblem(email: email, password: password, confirm: confirm)
    }

    private var canSubmit: Bool {
        guard !isSubmitting, !email.isEmpty, !password.isEmpty else { return false }
        return mode == .login || !confirm.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $mode) {
                        Text("auth.login.tabLogin", bundle: .l10n).tag(Mode.login)
                        Text("auth.login.tabRegister", bundle: .l10n).tag(Mode.register)
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section {
                    if mode == .register {
                        TextField(text: $firstName) { Text("auth.login.namePlaceholder", bundle: .l10n) }
                            .textContentType(.givenName)
                    }
                    TextField(text: $email) { Text("auth.login.emailLabel", bundle: .l10n) }
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField(text: $password) { Text("auth.login.passwordLabel", bundle: .l10n) }
                        .textContentType(mode == .login ? .password : .newPassword)
                    if mode == .register {
                        SecureField(text: $confirm) { Text("auth.login.confirmPasswordPlaceholder", bundle: .l10n) }
                            .textContentType(.newPassword)
                    }
                }

                if let failure {
                    Section {
                        failureText(failure).foregroundStyle(Color.neg)
                    }
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView().tint(Color.accFg)
                        } else if mode == .login {
                            Text("auth.login.submitLogin", bundle: .l10n)
                        } else {
                            Text("auth.login.submitRegister", bundle: .l10n)
                        }
                    }
                    .buttonStyle(.primary)
                    .disabled(!canSubmit)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                if mode == .login {
                    Section {
                        NavigationLink {
                            ForgotPasswordView(email: email, baseURL: baseURL)
                        } label: {
                            Text("auth.login.forgotPassword", bundle: .l10n)
                        }
                    } footer: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("auth.login.stravaOnly", bundle: .l10n)
                            Link(destination: URL(string: "https://www.sotreina.com")!) {
                                Text("auth.login.openWeb", bundle: .l10n)
                            }
                            .foregroundStyle(Color.accTx)
                        }
                        .font(DSFont.caption)
                        .padding(.top, 4)
                    }
                }

                // spike-only: lets the same build hit production or a dev
                // server reachable from the phone (e.g. the PC's LAN IP)
                Section {
                    TextField(text: $baseURL) { Text("auth.login.apiURL", bundle: .l10n) }
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(Font.geistMono(13, relativeTo: .footnote))
                } header: {
                    Text("auth.login.server", bundle: .l10n)
                }
            }
            .monolitoForm()
            .navigationTitle(Text(verbatim: "SoTreina"))
            .onChange(of: mode) { failure = nil }
        }
    }

    private func failureText(_ failure: Failure) -> Text {
        switch failure {
        case .invalidURL: Text("auth.login.invalidURL", bundle: .l10n)
        case .invalidCredentials: Text("auth.login.invalidCredentials", bundle: .l10n)
        case .form(.emailMissing): Text("auth.login.genericError", bundle: .l10n)
        case .form(.passwordTooShort): Text("auth.login.passwordTooShort", bundle: .l10n)
        case .form(.passwordMismatch): Text("auth.login.passwordMismatch", bundle: .l10n)
        case .emailInUse: Text("auth.login.emailInUse", bundle: .l10n)
        case .other: Text("auth.login.genericError", bundle: .l10n)
        }
    }

    private func submit() async {
        guard let url = URL(string: baseURL.trimmingCharacters(in: .whitespaces)) else {
            failure = .invalidURL
            return
        }
        if mode == .register, let problem = registerProblem {
            failure = .form(problem)
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        failure = nil

        do {
            switch mode {
            case .login:
                try await session.login(email: email, password: password, baseURL: url)
            case .register:
                try await session.register(
                    RegisterRequest(email: email, password: password, firstName: firstName),
                    baseURL: url
                )
            }
        } catch APIError.unauthorized {
            // same as the web: credentials that proved wrong don't stay
            failure = .invalidCredentials
            password = ""
        } catch APIError.http(status: 409) {
            // the password wasn't the problem: keep the fields
            failure = .emailInUse
        } catch {
            failure = .other
        }
    }
}
