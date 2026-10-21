import Foundation

/// `GET /auth/me` — mirror of `MeResponse` in server/src/auth/auth.service.ts.
/// Hand-written on purpose (see .plans/app-ios-nativo-spec.md §5.4); the
/// decode tests run against JSON captured from the real API.
public struct Me: Codable, Equatable, Sendable {
    public var id: String
    public var firstName: String?
    public var profileImgUrl: String?
    public var maxHr: Int?
    public var hasStravaAccount: Bool
    public var hasPassword: Bool

    public init(
        id: String,
        firstName: String? = nil,
        profileImgUrl: String? = nil,
        maxHr: Int? = nil,
        hasStravaAccount: Bool = false,
        hasPassword: Bool = true
    ) {
        self.id = id
        self.firstName = firstName
        self.profileImgUrl = profileImgUrl
        self.maxHr = maxHr
        self.hasStravaAccount = hasStravaAccount
        self.hasPassword = hasPassword
    }
}

/// `POST /auth/token` — the JWT goes to the Keychain and is sent back as
/// `Authorization: Bearer` on every request.
public struct TokenResponse: Codable, Equatable, Sendable {
    public var token: String
    public var user: Me
}

public struct LoginRequest: Codable, Equatable, Sendable {
    public var email: String
    public var password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}
