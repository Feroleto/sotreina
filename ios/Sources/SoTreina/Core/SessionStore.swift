import Foundation
import Observation
import os
import SoTreinaKit

@MainActor
@Observable
final class SessionStore {
    enum State {
        case loading
        case loggedOut
        case loggedIn(Me)
    }

    private(set) var state: State = .loading
    private let log = Logger(subsystem: "com.feroleto.sotreina", category: "session")

    private var api: APIClient {
        APIClient(baseURL: APIClient.storedBaseURL, token: Keychain.readToken())
    }

    /// On launch: no token → login screen; a token → validate it with
    /// `GET /auth/me` (empty body = invalidated, e.g. logout on another device).
    func bootstrap() async {
        guard Keychain.readToken() != nil else {
            state = .loggedOut
            return
        }
        do {
            if let me: Me = try await api.get("auth/me") {
                state = .loggedIn(me)
            } else {
                signOutLocally()
            }
        } catch APIError.unauthorized {
            signOutLocally()
        } catch {
            // network down / Render waking up: keep the token, retry on next
            // launch — dropping it here would force a re-login on bad signal
            log.error("bootstrap failed: \(String(describing: error), privacy: .public)")
            state = .loggedOut
        }
    }

    func login(email: String, password: String, baseURL: URL) async throws {
        APIClient.storedBaseURL = baseURL
        let client = APIClient(baseURL: baseURL, token: nil)
        guard let response: TokenResponse = try await client.post(
            "auth/token",
            body: LoginRequest(email: email.trimmingCharacters(in: .whitespaces), password: password)
        ) else { throw APIError.invalidResponse }

        Keychain.saveToken(response.token)
        state = .loggedIn(response.user)
        log.info("logged in as \(response.user.id, privacy: .public)")
    }

    /// Bumps tokenVersion on the server — logs out the web too, by design
    /// (same semantics as the web's logout button).
    func logout() async {
        do {
            try await api.postEmpty("auth/logout")
        } catch {
            log.error("logout request failed: \(String(describing: error), privacy: .public)")
        }
        signOutLocally()
    }

    private func signOutLocally() {
        Keychain.deleteToken()
        state = .loggedOut
    }
}
