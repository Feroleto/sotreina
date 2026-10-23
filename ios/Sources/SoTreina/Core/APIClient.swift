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

    func get<Response: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> Response? {
        try await send("GET", path, query: query, body: Optional<String>.none)
    }

    /// The raw 2xx body (empty for "no content") — what CachedAPI stores.
    func getData(_ path: String, query: [URLQueryItem] = []) async throws -> Data {
        try await sendData("GET", path, query: query, body: Optional<String>.none)
    }

    func post<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response? {
        try await send("POST", path, body: body)
    }

    /// A POST whose answer doesn't matter (`{ok:true}`).
    func postIgnoringBody<Body: Encodable>(_ path: String, body: Body) async throws {
        _ = try await sendData("POST", path, body: body)
    }

    func postEmpty(_ path: String) async throws {
        let _: EmptyResponse? = try await send("POST", path, body: Optional<String>.none)
    }

    func patch<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response? {
        try await send("PATCH", path, body: body)
    }

    func put<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response? {
        try await send("PUT", path, body: body)
    }

    func delete<Response: Decodable>(_ path: String) async throws -> Response? {
        try await send("DELETE", path, body: Optional<String>.none)
    }

    func deleteEmpty(_ path: String) async throws {
        let _: EmptyResponse? = try await send("DELETE", path, body: Optional<String>.none)
    }

    /// Returns `nil` for an empty 2xx body — `GET /auth/me` answers 200 with
    /// no body (not 401) for a visitor without a valid session.
    private func send<Body: Encodable, Response: Decodable>(
        _ method: String,
        _ path: String,
        query: [URLQueryItem] = [],
        body: Body?
    ) async throws -> Response? {
        let data = try await sendData(method, path, query: query, body: body)
        if data.isEmpty || Response.self == EmptyResponse.self { return nil }
        return try APICoding.makeDecoder().decode(Response.self, from: data)
    }

    /// The 2xx body as received; 401 and other statuses throw.
    private func sendData<Body: Encodable>(
        _ method: String,
        _ path: String,
        query: [URLQueryItem] = [],
        body: Body?
    ) async throws -> Data {
        // query items go in separately: appending(path:) would encode a "?"
        var url = baseURL.appending(path: path)
        if !query.isEmpty { url.append(queryItems: query) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        // Bearer only: `POST /auth/register` answers with the web's session
        // cookie, which must not ride along on later requests
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // the backend localizes exercise names by this header
        request.setValue(AppLanguageStore.current.acceptLanguage, forHTTPHeaderField: "Accept-Language")
        // the diet's "today" is cut at local midnight (backend falls back to UTC without it)
        request.setValue(TimeZone.current.identifier, forHTTPHeaderField: "X-Time-Zone")
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
        Self.log.notice("\(method, privacy: .public) \(path, privacy: .public) -> \(http.statusCode) in \(Date().timeIntervalSince(started), format: .fixed(precision: 2))s")

        switch http.statusCode {
        case 200..<300:
            return data
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.http(status: http.statusCode)
        }
    }
}

private struct EmptyResponse: Decodable {}
