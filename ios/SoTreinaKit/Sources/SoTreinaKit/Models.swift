import Foundation

/// `GET /auth/me` — mirror of `MeResponse` in server/src/auth/auth.service.ts.
/// Hand-written on purpose (see .plans/app-ios-nativo-spec.md §5.4); the
/// decode tests run against JSON captured from the real API.
public struct Me: Codable, Equatable, Sendable {
    public var id: String
    /// nil for a Strava-only account (Strava never shares it)
    public var email: String?
    public var firstName: String?
    public var profileImgUrl: String?
    public var maxHr: Int?
    public var hasStravaAccount: Bool
    public var hasPassword: Bool
    /// Display units (`UnitConversion`); `.km`/`.kg` when the payload has none.
    public var distanceUnit: DistanceUnit
    public var weightUnit: WeightUnit
    /// Areas the user follows; empty = not chosen yet (the area picker shows).
    public var enabledAreas: [Area]
    /// Proved the email with the 6-digit code (spec login-app-ios §3.3).
    /// `true` when the payload has none: a backend from before verification
    /// has nothing to verify with.
    public var emailVerified: Bool

    public init(
        id: String,
        email: String? = nil,
        firstName: String? = nil,
        profileImgUrl: String? = nil,
        maxHr: Int? = nil,
        hasStravaAccount: Bool = false,
        hasPassword: Bool = true,
        distanceUnit: DistanceUnit = .km,
        weightUnit: WeightUnit = .kg,
        enabledAreas: [Area] = [],
        emailVerified: Bool = true
    ) {
        self.id = id
        self.email = email
        self.firstName = firstName
        self.profileImgUrl = profileImgUrl
        self.maxHr = maxHr
        self.hasStravaAccount = hasStravaAccount
        self.hasPassword = hasPassword
        self.distanceUnit = distanceUnit
        self.weightUnit = weightUnit
        self.enabledAreas = enabledAreas
        self.emailVerified = emailVerified
    }

    // the unit fields arrived later: a response from an older backend, or
    // one cached before them, must still decode
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        firstName = try c.decodeIfPresent(String.self, forKey: .firstName)
        profileImgUrl = try c.decodeIfPresent(String.self, forKey: .profileImgUrl)
        maxHr = try c.decodeIfPresent(Int.self, forKey: .maxHr)
        hasStravaAccount = try c.decode(Bool.self, forKey: .hasStravaAccount)
        hasPassword = try c.decode(Bool.self, forKey: .hasPassword)
        distanceUnit = try c.decodeIfPresent(DistanceUnit.self, forKey: .distanceUnit) ?? .km
        weightUnit = try c.decodeIfPresent(WeightUnit.self, forKey: .weightUnit) ?? .kg
        // an area value this build doesn't know is skipped, not a failed decode
        let rawAreas = try c.decodeIfPresent([String].self, forKey: .enabledAreas) ?? []
        enabledAreas = rawAreas.compactMap(Area.init(rawValue:))
        emailVerified = try c.decodeIfPresent(Bool.self, forKey: .emailVerified) ?? true
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
