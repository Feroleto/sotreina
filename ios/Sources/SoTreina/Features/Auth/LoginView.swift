import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// Entrada (spec login-app-ios §3.1): Entrar, with Criar conta and Esqueci
/// a senha pushed on top. Email and password only: the Apple button (and the
/// "ou" above it) waits for the paid developer account, and Strava connects
/// from Corrida, never here. A Strava-only account adds a password on the
/// web first, which the hint after a 401 says.
struct LoginView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var path: [Route] = []
    /// shared with Criar conta: going back keeps what was typed
    @State private var email = ""
    /// step 1 of the entry transition (spec §4): the form rises and fades
    @State private var exiting = false

    enum Route: Hashable {
        case register
        case forgot
        /// the account Criar conta just made rides in the route itself: a
        /// `@State` read inside `navigationDestination` was still `nil` when
        /// the destination was built (an empty, black screen)
        case verify(RegisteredAccount)
    }

    /// `Me` isn't `Hashable`; one account is one id.
    struct RegisteredAccount: Hashable {
        let me: Me

        static func == (a: Self, b: Self) -> Bool { a.me.id == b.me.id }
        func hash(into hasher: inout Hasher) { hasher.combine(me.id) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            SignInScreen(email: $email, path: $path, onSignedIn: leave)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .register: RegisterView(email: $email, onSignedIn: registeredAccount)
                    case .forgot: ForgotPasswordView(email: email)
                    case .verify(let account):
                        VerifyEmailView(context: .signUp, email: account.me.email ?? email) { verified in
                            leave(verified ?? account.me)
                        }
                    }
                }
        }
        .tint(Color.fg)
        .opacity(exiting ? 0 : 1)
        .offset(y: exiting && !reduceMotion ? -14 : 0)
        .scaleEffect(exiting && !reduceMotion ? 0.98 : 1)
        .allowsHitTesting(!exiting)
    }

    /// Criar conta made the account (token saved): the code step, then the
    /// app. A backend without verification answers `emailVerified: true`.
    private func registeredAccount(_ me: Me) {
        guard !me.emailVerified else { return leave(me) }
        path.append(.verify(RegisteredAccount(me: me)))
    }

    /// Signed in (the token is saved): play the exit, then hand over to the
    /// app, which runs the rest of the transition over the destination.
    private func leave(_ me: Me) {
        let exit: Animation = reduceMotion
            ? .linear(duration: 0.2)
            : .timingCurve(0.4, 0, 0.6, 1, duration: 0.32)
        withAnimation(exit) {
            exiting = true
        } completion: {
            session.enter(me, animated: true)
        }
    }
}

private struct SignInScreen: View {
    @Environment(SessionStore.self) private var session
    @Binding var email: String
    @Binding var path: [LoginView.Route]
    let onSignedIn: (Me) -> Void
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var failure: Failure?
    @State private var showServer = false
    @FocusState private var emailFocused: Bool
    /// UIKit field, outside the `FocusState` (see `EntryPasswordField`)
    @State private var passwordFocused = false

    /// Kept as a case, not text, so a language change also redraws it.
    private enum Failure {
        case invalidCredentials
        case other
    }

    private var canSubmit: Bool {
        !isSubmitting && !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    var body: some View {
        EntryScroll(submitID: "submit", focused: emailFocused || passwordFocused) {
            brand
                .padding(.top, 48)

            Spacer(minLength: 40)

            EntryHeading(title: "auth.login.welcomeTitle", subtitle: "auth.login.welcomeSubtitle")

            if session.signedOutNotice == .accountDeleted {
                Label {
                    Text("auth.login.accountDeleted", bundle: .l10n)
                } icon: {
                    Image(systemName: "checkmark.circle")
                }
                .font(Font.geist(14, relativeTo: .subheadline))
                .foregroundStyle(Color.mutedFg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 14)
            }

            VStack(spacing: 12) {
                TextField(text: $email) {
                    Text("auth.login.emailLabel", bundle: .l10n).foregroundStyle(Color.mutedFg)
                }
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($emailFocused)
                .onSubmit { passwordFocused = true }
                .entryFieldBox()

                EntryPasswordField(
                    label: "auth.login.passwordLabel", text: $password, isNew: false,
                    isFocused: $passwordFocused
                ) {
                    if canSubmit { Task { await submit() } }
                }

                Button {
                    path.append(.forgot)
                } label: {
                    Text("auth.login.forgotPassword", bundle: .l10n)
                        .font(Font.geist(14, relativeTo: .subheadline))
                        .foregroundStyle(Color.mutedFg)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.top, 28)

            if let failure {
                failureView(failure)
                    .padding(.top, 10)
            }

            Button {
                Task { await submit() }
            } label: {
                if isSubmitting {
                    ProgressView().tint(Color.accFg)
                } else {
                    Text("auth.login.submitLogin", bundle: .l10n)
                }
            }
            .buttonStyle(EntryButtonStyle())
            .disabled(!canSubmit)
            .padding(.top, 14)
            .id("submit")

            // the Apple button and the "ou" divider go here once the paid
            // developer account exists (spec §7); nothing renders until then

            HStack(spacing: 4) {
                Text("auth.login.noAccount", bundle: .l10n)
                    .foregroundStyle(Color.mutedFg)
                Button {
                    path.append(.register)
                } label: {
                    Text("auth.login.submitRegister", bundle: .l10n)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.accTx)
                }
                .buttonStyle(.plain)
            }
            .font(Font.geist(15, relativeTo: .subheadline))
            .frame(maxWidth: .infinity)
            .padding(.top, 24)

            EntryLegalLinks()
                .padding(.top, 20)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showServer) { ServerSheet() }
    }

    /// Logo and name; a long press opens the server sheet (dev only in
    /// practice: pointing the build at a server on the LAN).
    private var brand: some View {
        HStack(spacing: 10) {
            LogoMark().frame(width: 40, height: 40)
            Text(verbatim: "SoTreina")
                .font(Font.geist(28, relativeTo: .title).weight(.semibold))
                .tracking(-1.1)
                .foregroundStyle(Color.fg)
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.8) { showServer = true }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func failureView(_ failure: Failure) -> some View {
        switch failure {
        case .invalidCredentials:
            // a Strava-only account has no password: say how to get one
            EntryError(text: Text("auth.login.invalidCredentials", bundle: .l10n)) {
                Text("auth.login.stravaOnly", bundle: .l10n)
                    .font(Font.geist(13, relativeTo: .footnote))
                    .foregroundStyle(Color.mutedFg)
                Link(destination: WebLinks.home) {
                    Text("auth.login.openWeb", bundle: .l10n)
                        .font(Font.geist(13, relativeTo: .footnote).weight(.medium))
                        .foregroundStyle(Color.accTx)
                }
            }
        case .other:
            EntryError(text: Text("auth.login.genericError", bundle: .l10n))
        }
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        failure = nil

        do {
            let me = try await session.login(email: email, password: password, baseURL: APIClient.storedBaseURL)
            onSignedIn(me)
        } catch APIError.unauthorized {
            // same as the web: credentials that proved wrong don't stay
            failure = .invalidCredentials
            password = ""
            passwordFocused = true
        } catch {
            failure = .other
        }
    }
}
