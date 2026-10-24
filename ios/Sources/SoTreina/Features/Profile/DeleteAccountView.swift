import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// Perfil › Conta › Excluir conta (spec login-app-ios §3.5): says what goes
/// and that it can't be undone, confirms with the password. On success the
/// session store signs out and Entrar says "Conta excluída".
struct DeleteAccountView: View {
    @Environment(SessionStore.self) private var session
    @State private var password = ""
    @State private var deleting = false
    @State private var failure: AccountDeletion.Failure?

    var body: some View {
        Form {
            Section {
                Text("nav.profile.deleteIntro", bundle: .l10n)
                ForEach(Self.deletedItems, id: \.self) { key in
                    Label {
                        Text(LocalizedStringKey(key), bundle: .l10n)
                    } icon: {
                        Image(systemName: "minus.circle").foregroundStyle(Color.neg)
                    }
                }
                Text("nav.profile.deleteIrreversible", bundle: .l10n)
                    .fontWeight(.medium)
            }
            .font(DSFont.row)

            Section {
                SecureField(text: $password) {
                    Text("auth.login.passwordLabel", bundle: .l10n)
                }
                .textContentType(.password)
                .submitLabel(.done)
                .onSubmit { Task { await delete() } }
            } header: {
                Text("nav.profile.deletePasswordHeader", bundle: .l10n)
            }

            Section {
                if let failure {
                    Text(failureKey(failure), bundle: .l10n)
                        .font(DSFont.caption)
                        .foregroundStyle(Color.neg)
                }
                Button {
                    Task { await delete() }
                } label: {
                    Group {
                        if deleting {
                            ProgressView().tint(.white)
                        } else {
                            Text("nav.profile.deleteAccount", bundle: .l10n)
                        }
                    }
                    .font(DSFont.button)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .foregroundStyle(.white)
                    .background(Color.neg, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .opacity(canSubmit ? 1 : 0.5)
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .monolitoForm()
        .navigationTitle(Text("nav.profile.deleteAccount", bundle: .l10n))
        .navigationBarTitleDisplayMode(.inline)
    }

    private static let deletedItems = [
        "nav.profile.deleteItemGym",
        "nav.profile.deleteItemDiet",
        "nav.profile.deleteItemRun",
        "nav.profile.deleteItemStrava",
    ]

    private var canSubmit: Bool {
        !deleting && AccountDeletion.canSubmit(password: password)
    }

    private func failureKey(_ failure: AccountDeletion.Failure) -> LocalizedStringKey {
        switch failure {
        case .wrongPassword: "nav.profile.deleteWrongPassword"
        case .tooManyAttempts: "nav.profile.deleteTooManyAttempts"
        case .other: "nav.profile.deleteError"
        }
    }

    private func delete() async {
        guard canSubmit else { return }
        deleting = true
        failure = nil
        do {
            // success swaps the whole app back to Entrar; nothing left to do here
            try await session.deleteAccount(password: password)
        } catch APIError.http(let status) {
            failure = AccountDeletion.failure(status: status)
            if failure == .wrongPassword { password = "" }
        } catch APIError.unauthorized {
            // expired session: the store already signed out
        } catch {
            failure = AccountDeletion.failure(status: nil)
        }
        deleting = false
    }
}
