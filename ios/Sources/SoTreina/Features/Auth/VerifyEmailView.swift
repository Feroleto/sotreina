import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// "Confirme seu email" (spec login-app-ios §3.3, web `EmailCodeForm`): six
/// digits that submit on their own, iOS offers the code read from Mail.
/// Never blocking:
/// - right after Criar conta (`.signUp`): the first code is already on its
///   way, there's no going back to the form (the account exists), and
///   "Fazer depois" or a verified code both enter the app;
/// - from Perfil › Conta (`.profile`): asks for a fresh code on appear, the
///   back button is the way out.
struct VerifyEmailView: View {
    enum Context {
        case signUp
        case profile
    }

    let context: Context
    let email: String
    /// verified (the updated user) or skipped (`nil`, sign-up only)
    let onDone: (Me?) -> Void

    @Environment(SessionStore.self) private var session
    @State private var code = ""
    @State private var isSubmitting = false
    @State private var failure: Failure?
    @State private var resent = false
    @State private var resendAt: Date
    @FocusState private var focused: Bool

    private enum Failure {
        case invalidCode
        case verify
        case send
    }

    init(context: Context, email: String, onDone: @escaping (Me?) -> Void) {
        self.context = context
        self.email = email
        self.onDone = onDone
        // sign-up already sent one: the server's cooldown is running
        _resendAt = State(initialValue: context == .signUp
            ? .now.addingTimeInterval(TimeInterval(EmailCode.resendCooldown))
            : .now)
    }

    var body: some View {
        EntryScroll {
            EntryHeading(title: "auth.verify.title", subtitle: "auth.verify.subtitle \(email)")
                .padding(.top, 12)

            codeField
                .padding(.top, 28)

            if let failure {
                EntryError(text: failureText(failure))
                    .padding(.top, 10)
            } else if resent {
                Text("auth.verify.resent", bundle: .l10n)
                    .font(Font.geist(14, relativeTo: .subheadline))
                    .foregroundStyle(Color.mutedFg)
                    .padding(.top, 10)
            }

            HStack {
                resendButton
                Spacer()
                if context == .signUp {
                    Button {
                        onDone(nil)
                    } label: {
                        Text("auth.verify.later", bundle: .l10n)
                            .foregroundStyle(Color.mutedFg)
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(Font.geist(15, relativeTo: .subheadline).weight(.medium))
            .padding(.top, 20)
        }
        .entryPushedScreen()
        .navigationBarBackButtonHidden(context == .signUp)
        .onAppear { focused = true }
        .task {
            guard context == .profile else { return }
            await send(isResend: false)
        }
    }

    private var codeField: some View {
        TextField(text: $code) {
            Text(verbatim: "000000").foregroundStyle(Color.mutedFg.opacity(0.5))
        }
        .font(Font.geistMono(22, relativeTo: .title2))
        .tracking(8)
        .multilineTextAlignment(.center)
        .keyboardType(.numberPad)
        .textContentType(.oneTimeCode)
        .focused($focused)
        .disabled(isSubmitting)
        .entryFieldBox()
        .overlay(alignment: .trailing) {
            if isSubmitting {
                ProgressView().padding(.trailing, 16)
            }
        }
        .accessibilityLabel(Text("auth.verify.codeLabel", bundle: .l10n))
        .onChange(of: code) { _, typed in
            let digits = EmailCode.sanitize(typed)
            if digits != typed { code = digits }
            if EmailCode.isComplete(digits) { Task { await verify(digits) } }
        }
    }

    private var resendButton: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let left = max(0, Int(resendAt.timeIntervalSince(context.date).rounded(.up)))
            Button {
                Task { await send(isResend: true) }
            } label: {
                if left > 0 {
                    Text("auth.verify.resendIn \(left)", bundle: .l10n)
                        .foregroundStyle(Color.mutedFg)
                        .monospacedDigit()
                } else {
                    Text("auth.verify.resend", bundle: .l10n)
                        .foregroundStyle(Color.accTx)
                }
            }
            .buttonStyle(.plain)
            .disabled(left > 0 || isSubmitting)
        }
    }

    private func failureText(_ failure: Failure) -> Text {
        switch failure {
        case .invalidCode: Text("auth.verify.invalidCode", bundle: .l10n)
        case .verify: Text("auth.verify.genericError", bundle: .l10n)
        case .send: Text("auth.verify.sendError", bundle: .l10n)
        }
    }

    private func send(isResend: Bool) async {
        failure = nil
        resent = false
        do {
            if let wait = try await session.sendEmailCode() {
                // one is already on its way: count down, no error
                resendAt = .now.addingTimeInterval(TimeInterval(wait))
            } else {
                resendAt = .now.addingTimeInterval(TimeInterval(EmailCode.resendCooldown))
                resent = isResend
            }
        } catch APIError.unauthorized {
            session.expire()
        } catch {
            failure = .send
        }
    }

    private func verify(_ digits: String) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        failure = nil
        resent = false
        do {
            let me = try await session.verifyEmail(code: digits)
            focused = false
            onDone(me)
        } catch APIError.unauthorized {
            session.expire()
        } catch APIError.http(let status) {
            failure = EmailCode.verifyFailure(status: status) == .invalidCode ? .invalidCode : .verify
            code = ""
        } catch {
            failure = .verify
            code = ""
        }
    }
}

/// Perfil › Conta: the email, verified or not, and the way to verify it.
struct ProfileEmailRow: View {
    let me: Me

    var body: some View {
        if let email = me.email {
            if me.emailVerified {
                row(email: email) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.pos)
                        .accessibilityLabel(Text("nav.profile.emailVerified", bundle: .l10n))
                }
            } else {
                NavigationLink {
                    VerifyEmailPushed(email: email)
                } label: {
                    row(email: email) {
                        Text("nav.profile.verifyEmail", bundle: .l10n)
                            .font(DSFont.pill)
                            .foregroundStyle(Color.accTx)
                    }
                }
            }
        }
    }

    private func row(email: String, @ViewBuilder trailing: () -> some View) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("nav.profile.email", bundle: .l10n).font(DSFont.row)
                HStack(spacing: 6) {
                    Text(verbatim: email)
                        .lineLimit(1)
                    if !me.emailVerified {
                        Text("nav.profile.emailUnverified", bundle: .l10n)
                            .foregroundStyle(Color.neg)
                    }
                }
                .font(DSFont.caption)
                .foregroundStyle(Color.mutedFg)
            }
            Spacer()
            trailing()
        }
    }
}

/// The Perfil push: pops itself once verified (`setMe` already flipped the
/// row to the check).
private struct VerifyEmailPushed: View {
    let email: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VerifyEmailView(context: .profile, email: email) { _ in dismiss() }
    }
}
