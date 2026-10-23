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

    /// A client carrying the current token — what every feature store uses.
    var api: APIClient {
        APIClient(baseURL: APIClient.storedBaseURL, token: Keychain.readToken())
    }

    /// `GET`s through the read cache, scoped to the signed-in user; nil when
    /// signed out.
    var cachedAPI: CachedAPI? {
        guard case .loggedIn(let me) = state else { return nil }
        return CachedAPI(api: api, userId: me.id)
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
        log.notice("logged in as \(response.user.id, privacy: .public)")
    }

    /// `POST /auth/register` returns the web's cookie session, not a token,
    /// so the Bearer comes from logging in with the same credentials (spec
    /// §3, Entrada: no backend change). A 409 means the email is taken.
    func register(_ request: RegisterRequest, baseURL: URL) async throws {
        APIClient.storedBaseURL = baseURL
        let client = APIClient(baseURL: baseURL, token: nil)
        let _: Me? = try await client.post("auth/register", body: request)
        log.notice("registered")
        try await login(email: request.email, password: request.password, baseURL: baseURL)
    }

    /// Always succeeds on the server's side when it answers (anti-enumeration);
    /// only a network failure throws.
    func requestPasswordReset(email: String, baseURL: URL) async throws {
        let client = APIClient(baseURL: baseURL, token: nil)
        try await client.postIgnoringBody("auth/forgot-password", body: ForgotPasswordRequest(email: email))
    }

    /// The area picker and Perfil's toggles: `PATCH /users/me`, then the
    /// signed-in `Me` takes the server's (canonical) list, which redraws the tabs.
    func saveAreas(_ areas: [Area]) async throws {
        guard case .loggedIn(var me) = state else { return }
        do {
            let saved: EnabledAreasPatch? = try await api.patch("users/me", body: EnabledAreasPatch(enabledAreas: areas))
            me.enabledAreas = saved?.enabledAreas ?? areas
            state = .loggedIn(me)
        } catch APIError.unauthorized {
            expire()
            throw APIError.unauthorized
        }
    }

    /// Perfil's saves (`ProfileStore`): the signed-in `Me` with the name,
    /// areas or units already applied — optimistically, then the server's.
    func setMe(_ me: Me) {
        guard case .loggedIn(let current) = state, current.id == me.id else { return }
        state = .loggedIn(me)
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

    /// A 401 anywhere means the JWT expired (30d) or a logout elsewhere bumped
    /// tokenVersion: drop it and go back to the login screen.
    func expire() {
        log.notice("session expired")
        signOutLocally()
    }

    private func signOutLocally() {
        Keychain.deleteToken()
        // nothing of the leaving account stays on the device
        CachedAPI.cache.clearAll()
        // the workout's Live Activity belongs to the account leaving
        LiveActivityController.endEverything()
        state = .loggedOut
    }
}
