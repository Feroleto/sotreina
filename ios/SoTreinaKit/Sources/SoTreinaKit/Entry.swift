import Foundation

/// Why the register form can't be sent yet — the same checks the web makes
/// before `POST /auth/register` (the server enforces them again).
public enum RegisterProblem: Equatable, Sendable {
    case emailMissing
    /// under `EntryForm.minPasswordLength` (server/src/auth/dto.ts)
    case passwordTooShort
    case passwordMismatch
}

/// Rules of the entry screens: login, register and the area picker.
public enum EntryForm {
    public static let minPasswordLength = 8

    public static func registerProblem(email: String, password: String, confirm: String) -> RegisterProblem? {
        if email.trimmingCharacters(in: .whitespaces).isEmpty { return .emailMissing }
        if password.count < minPasswordLength { return .passwordTooShort }
        if password != confirm { return .passwordMismatch }
        return nil
    }

    /// The picked areas in the server's order (`Area.allCases`), like the
    /// web's `AREAS` — the server stores `enabledAreas` in that order too.
    public static func canonicalAreas(_ selected: Set<Area>) -> [Area] {
        Area.allCases.filter(selected.contains)
    }
}

/// `POST /auth/register`. It also sets the web's session cookie, which the
/// app ignores: the Bearer comes from a `POST /auth/token` right after.
public struct RegisterRequest: Codable, Equatable, Sendable {
    public var email: String
    public var password: String
    /// optional on the server; a blank name is left out, not sent empty
    public var firstName: String?

    public init(email: String, password: String, firstName: String?) {
        self.email = email.trimmingCharacters(in: .whitespaces)
        self.password = password
        let name = firstName?.trimmingCharacters(in: .whitespaces) ?? ""
        self.firstName = name.isEmpty ? nil : name
    }
}

/// `POST /auth/forgot-password` — always `{ok:true}`, whether or not the
/// email exists (anti-enumeration); the link in the email opens the web.
public struct ForgotPasswordRequest: Codable, Equatable, Sendable {
    public var email: String

    public init(email: String) {
        self.email = email.trimmingCharacters(in: .whitespaces)
    }
}

/// `PATCH /users/me` with only the areas. The response is the settings
/// snapshot (not `Me`); only its `enabledAreas` is read back.
public struct EnabledAreasPatch: Codable, Equatable, Sendable {
    public var enabledAreas: [Area]

    public init(enabledAreas: [Area]) {
        self.enabledAreas = enabledAreas
    }
}
