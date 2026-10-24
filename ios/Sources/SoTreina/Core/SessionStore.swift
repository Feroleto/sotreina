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
    /// Set by `enter(_:animated:)` after the entry form signs in: `RootView`
    /// plays the "bola percorre o pulso" transition over the destination,
    /// then calls `entryTransitionEnded()`. Never on a cold launch.
    private(set) var entryTransition = false
    /// Why the app is back at Entrar, when it's worth saying (shown there
    /// until the next sign-in).
    private(set) var signedOutNotice: SignedOutNotice?
    /// Set when a Strava connect came back `ok`: the callback started the
    /// import, but skips it when another sync holds the server's lock, so
    /// Corrida starts one itself if the status says idle (`RunStore`).
    var stravaJustConnected = false
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

    /// Saves the token and returns the user, without leaving the login
    /// screen: the entry form plays its exit first, then calls `enter`.
    func login(email: String, password: String, baseURL: URL) async throws -> Me {
        APIClient.storedBaseURL = baseURL
        let client = APIClient(baseURL: baseURL, token: nil)
        guard let response: TokenResponse = try await client.post(
            "auth/token",
            body: LoginRequest(email: email.trimmingCharacters(in: .whitespaces), password: password)
        ) else { throw APIError.invalidResponse }

        Keychain.saveToken(response.token)
        log.notice("logged in as \(response.user.id, privacy: .public)")
        return response.user
    }

    /// `POST /auth/register-token`: creates the account, sends the first
    /// verification code and answers with the Bearer, in one call. Like
    /// `login`, it doesn't leave the entry screens (the code step comes
    /// next). A 409 means the email is taken.
    func register(_ request: RegisterRequest, baseURL: URL) async throws -> Me {
        APIClient.storedBaseURL = baseURL
        let client = APIClient(baseURL: baseURL, token: nil)
        guard let response: TokenResponse = try await client.post("auth/register-token", body: request)
        else { throw APIError.invalidResponse }

        Keychain.saveToken(response.token)
        log.notice("registered as \(response.user.id, privacy: .public)")
        return response.user
    }

    /// Asks for a verification code. `nil` when one went out; otherwise the
    /// seconds until another can (a 429: one is already on its way).
    /// Already verified (409) counts as sent: the verify call settles it.
    func sendEmailCode() async throws -> Int? {
        let (status, body) = try await api.postRaw("auth/email/send-code")
        switch status {
        case 200..<300, 409: return nil
        case 429: return EmailCode.retryAfterSeconds(from: body)
        default: throw APIError.http(status: status)
        }
    }

    /// `POST /auth/email/verify` → the user with `emailVerified: true`. Also
    /// updates the signed-in `Me` (Perfil); during sign-up the caller enters
    /// the app with the returned one.
    func verifyEmail(code: String) async throws -> Me {
        guard let me: Me = try await api.post("auth/email/verify", body: VerifyEmailRequest(code: code))
        else { throw APIError.invalidResponse }
        setMe(me)
        return me
    }

    /// Leaves the entry screens for the app (the token is already saved).
    func enter(_ me: Me, animated: Bool) {
        entryTransition = animated
        signedOutNotice = nil
        state = .loggedIn(me)
    }

    func entryTransitionEnded() {
        entryTransition = false
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

    /// The signed-in user's weight unit (`.kg` signed out): display and entry
    /// only, the API always speaks kg.
    var weightUnit: WeightUnit {
        guard case .loggedIn(let me) = state else { return .kg }
        return me.weightUnit
    }

    /// Same for distance and pace: the API always speaks km.
    var distanceUnit: DistanceUnit {
        guard case .loggedIn(let me) = state else { return .km }
        return me.distanceUnit
    }

    /// Perfil's saves (`ProfileStore`): the signed-in `Me` with the name,
    /// areas or units already applied — optimistically, then the server's.
    func setMe(_ me: Me) {
        guard case .loggedIn(let current) = state, current.id == me.id else { return }
        state = .loggedIn(me)
    }

    /// `GET /auth/me` again, after something the server changed about the
    /// account (the Strava connection).
    func refreshMe() async {
        do {
            if let me: Me = try await api.get("auth/me") { setMe(me) } else { expire() }
        } catch APIError.unauthorized {
            expire()
        } catch {
            log.error("auth/me refresh failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Corrida's empty state and Perfil › Conta (spec login-app-ios §5.2):
    /// `POST /strava/connect/start`, then Strava's page in an
    /// ASWebAuthenticationSession, then `/auth/me` on `ok`. Nil when the user
    /// closed the sheet.
    func connectStrava() async throws -> StravaConnectReturn? {
        let start: StravaConnectStart?
        do {
            start = try await api.post("strava/connect/start")
        } catch APIError.unauthorized {
            expire()
            throw APIError.unauthorized
        }
        guard let start, let callback = try await StravaWebAuth.run(start.url) else { return nil }
        let result = StravaConnectReturn(url: callback)
        log.notice("strava connect: \(String(describing: result), privacy: .public)")
        if result == .ok {
            stravaJustConnected = true
            await refreshMe()
        }
        return result
    }

    /// Perfil › Conta (spec §5.4): `DELETE /strava/connect`, which deletes the
    /// imported runs. An account deleted with it (no password) signs out.
    func disconnectStrava() async throws {
        let response: StravaDisconnectResponse?
        do {
            response = try await api.delete("strava/connect")
        } catch APIError.unauthorized {
            expire()
            throw APIError.unauthorized
        }
        log.notice("strava disconnected")
        if response?.accountDeleted == true {
            signOutLocally()
        } else {
            await refreshMe()
        }
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

    /// Perfil › Excluir conta: `DELETE /users/me {password}`, then everything
    /// local goes like on logout and Entrar says "Conta excluída". A wrong
    /// password comes back as `APIError.http(403)` and leaves the session
    /// alone; a 401 is a real expiry, handled like everywhere else.
    func deleteAccount(password: String) async throws {
        do {
            try await api.deleteEmpty("users/me", body: DeleteAccountRequest(password: password))
        } catch APIError.unauthorized {
            expire()
            throw APIError.unauthorized
        }
        log.notice("account deleted")
        signOutLocally()
        signedOutNotice = .accountDeleted
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

enum SignedOutNotice {
    case accountDeleted
}
