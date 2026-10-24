import AuthenticationServices
import SoTreinaKit
import UIKit

/// Strava's authorize page in an `ASWebAuthenticationSession` (spec
/// login-app-ios §5.2): not ephemeral, so a Strava login already made in
/// Safari is reused. Tested with the xtool build (`ios/README.md`, "Login web
/// no app").
@MainActor
enum StravaWebAuth {
    /// the session has to stay referenced while it's on screen
    private static var current: ASWebAuthenticationSession?
    private static let anchor = Anchor()

    /// The `sotreina://` URL the callback redirected to; nil when the user
    /// closed the sheet.
    static func run(_ url: URL) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url, callbackURLScheme: StravaConnectReturn.callbackScheme
            ) { callback, error in
                if let callback {
                    continuation.resume(returning: callback)
                } else if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(throwing: error ?? URLError(.unknown))
                }
                Task { @MainActor in current = nil }
            }
            session.presentationContextProvider = anchor
            session.prefersEphemeralWebBrowserSession = false
            current = session
            if !session.start() {
                current = nil
                continuation.resume(throwing: URLError(.cannotLoadFromNetwork))
            }
        }
    }

    private final class Anchor: NSObject, ASWebAuthenticationPresentationContextProviding {
        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            MainActor.assumeIsolated {
                UIApplication.shared.connectedScenes
                    .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                    .first ?? ASPresentationAnchor()
            }
        }
    }
}
