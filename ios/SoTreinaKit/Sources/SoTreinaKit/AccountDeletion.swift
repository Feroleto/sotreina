import Foundation

/// `DELETE /users/me` body (spec login-app-ios §3.5): the password confirms
/// it, sent as typed (it's never trimmed anywhere else either).
public struct DeleteAccountRequest: Codable, Equatable, Sendable {
    public var password: String

    public init(password: String) {
        self.password = password
    }
}

/// Perfil › Excluir conta. A wrong password is **403**, not 401: any 401
/// signs the app out (`SessionStore.expire()`), and here the session is fine.
public enum AccountDeletion {
    public enum Failure: Equatable, Sendable {
        case wrongPassword
        /// the 5/min throttle shared with login
        case tooManyAttempts
        case other
    }

    public static func canSubmit(password: String) -> Bool {
        !password.isEmpty
    }

    /// `status` is nil for a network failure.
    public static func failure(status: Int?) -> Failure {
        switch status {
        case 403: .wrongPassword
        case 429: .tooManyAttempts
        default: .other
        }
    }
}
