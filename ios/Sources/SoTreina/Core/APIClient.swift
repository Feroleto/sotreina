import Foundation
import os
import SoTreinaKit

enum APIError: Error {
    /// 401 — token missing, expired (30d JWT) or invalidated by a logout elsewhere
    case unauthorized
    case http(status: Int)
    case invalidResponse
}

/// Thin URLSession wrapper. Auth is a Bearer token (never cookies): the
/// backend's SessionService.extractSession reads the header first.
struct APIClient {
    /// Goes through the Vercel proxy, same as the web — keeps the Render
    /// host an implementation detail. Must be the canonical host: the other
    /// domains answer 308 to www.sotreina.com, and URLSession drops the
    /// Authorization header on a cross-host redirect (every authed call would
    /// look logged out, and bootstrap would wipe the token).
    static let defaultBaseURL = URL(string: "https://www.sotreina.com/api")!
    /// Hosts that only redirect to `defaultBaseURL` — a stored one (saved by
    /// an older build's login) is read as the default.
    private static let redirectingHosts: Set<String> = ["sotreina.vercel.app", "sotreina.com"]
    private static let baseURLKey = "apiBaseURL"
    private static let log = Logger(subsystem: "com.feroleto.sotreina", category: "api")

    static var storedBaseURL: URL {
        get {
            guard let stored = UserDefaults.standard.string(forKey: baseURLKey).flatMap(URL.init(string:)),
                  !redirectingHosts.contains(stored.host() ?? "")
            else { return defaultBaseURL }
            return stored
        }
        set { UserDefaults.standard.set(newValue.absoluteString, forKey: baseURLKey) }
    }

    var baseURL: URL = APIClient.storedBaseURL
    var token: String?

    func get<Response: Decodable>(_ path: String) async throws -> Response? {
        try await send("GET", path, body: Optional<String>.none)
    }

    func post<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response? {
        try await send("POST", path, body: body)
    }

    func postEmpty(_ path: String) async throws {
        let _: EmptyResponse? = try await send("POST", path, body: Optional<String>.none)
    }

    /// Returns `nil` for an empty 2xx body — `GET /auth/me` answers 200 with
    /// no body (not 401) for a visitor without a valid session.
    private func send<Body: Encodable, Response: Decodable>(
        _ method: String,
        _ path: String,
        body: Body?
    ) async throws -> Response? {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // the backend localizes exercise names by this header; the app is PT-only
        request.setValue("pt", forHTTPHeaderField: "Accept-Language")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try APICoding.makeEncoder().encode(body)
        }

        let started = Date()
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        Self.log.debug("\(method, privacy: .public) \(path, privacy: .public) → \(http.statusCode) in \(Date().timeIntervalSince(started), format: .fixed(precision: 2))s")

        switch http.statusCode {
        case 200..<300:
            if data.isEmpty || Response.self == EmptyResponse.self { return nil }
            return try APICoding.makeDecoder().decode(Response.self, from: data)
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.http(status: http.statusCode)
        }
    }
}

private struct EmptyResponse: Decodable {}
