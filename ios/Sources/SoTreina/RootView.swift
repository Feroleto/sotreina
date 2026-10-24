import SoTreinaDesign
import SoTreinaKit
import SwiftUI

struct RootView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// a Live Activity button opened the app; held here because on a cold
    /// launch the URL arrives before the session (and the workout screen) is up
    @State private var pendingLink: ActivityLink?
    /// entry transition (spec login-app-ios §4): the destination finished its
    /// first load, and then came in from under the overlay
    @State private var entryReady = false
    @State private var entryRevealed = false

    /// under the overlay until it reveals it
    private var destinationHidden: Bool { session.entryTransition && !entryRevealed }

    var body: some View {
        Group {
            switch session.state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.pageBg)
                    .task { await session.bootstrap() }
            case .loggedOut:
                LoginView()
            case .loggedIn(let me) where me.enabledAreas.isEmpty:
                // nothing to load: the ball can finish as soon as it's allowed
                AreaPickerView()
                    .onAppear { entryReady = true }
            case .loggedIn(let me):
                AppShell(
                    session: session, me: me, pendingLink: $pendingLink,
                    holdsCovers: session.entryTransition,
                    onFirstLoad: { entryReady = true }
                )
            }
        }
        .opacity(destinationHidden ? 0 : 1)
        .offset(y: destinationHidden && !reduceMotion ? 12 : 0)
        .overlay {
            if session.entryTransition {
                EntryTransitionView(ready: entryReady) {
                    withAnimation(.easeOut(duration: 0.4)) { entryRevealed = true }
                } onFinish: {
                    session.entryTransitionEnded()
                    entryRevealed = false
                }
            }
        }
        // a ready flag left from an earlier session (logout, then sign in
        // again) must not let the ball run ahead of this load
        .onChange(of: session.entryTransition) { _, playing in
            if playing { entryReady = false }
        }
        .safeAreaInset(edge: .top, spacing: 0) { ExpiryBanner() }
        .onOpenURL { url in pendingLink = ActivityLink(url: url) }
        .task { ExpiryNotice.scheduleReminder() }
    }
}
