import Foundation

/// The 6-digit email verification (spec login-app-ios §3.3): right after
/// Criar conta and from Perfil › Conta. Never blocking. Same rules as the
/// web's `EmailCodeForm`.
public enum EmailCode {
    public static let length = 6
    /// the server's per-account cooldown between codes (seconds)
    public static let resendCooldown = 60

    /// What the field keeps of what was typed or pasted (or autofilled from
    /// Mail): digits only, at most six.
    public static func sanitize(_ raw: String) -> String {
        String(raw.filter(\.isASCIIDigit).prefix(length))
    }

    /// Six digits: submit on its own, no button.
    public static func isComplete(_ code: String) -> Bool {
        code.count == length
    }

    /// `POST /auth/email/send-code` answers 429 with `retryAfterSeconds`
    /// while a code is already on its way (or the hourly cap was hit): the
    /// "Reenviar" countdown, not an error.
    public static func retryAfterSeconds(from body: Data) -> Int {
        struct TooMany: Decodable { var retryAfterSeconds: Int }
        return (try? JSONDecoder().decode(TooMany.self, from: body))?.retryAfterSeconds ?? resendCooldown
    }

    public enum VerifyFailure: Equatable, Sendable {
        /// wrong or expired: check the latest email or ask for another
        case invalidCode
        case other
    }

    /// `POST /auth/email/verify`: 400 is a wrong or expired code.
    public static func verifyFailure(status: Int?) -> VerifyFailure {
        status == 400 ? .invalidCode : .other
    }
}

/// `POST /auth/email/verify` — answers with the whole `Me`.
public struct VerifyEmailRequest: Codable, Equatable, Sendable {
    public var code: String

    public init(code: String) {
        self.code = code
    }
}

extension Character {
    fileprivate var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
