import SoTreinaDesign
import SoTreinaKit
import SwiftUI

struct RootView: View {
    @Environment(SessionStore.self) private var session
    /// a Live Activity button opened the app; held here because on a cold
    /// launch the URL arrives before the session (and the workout screen) is up
    @State private var pendingLink: ActivityLink?

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
                AreaPickerView()
            case .loggedIn(let me):
                AppShell(session: session, me: me, pendingLink: $pendingLink)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { ExpiryBanner() }
        .onOpenURL { url in pendingLink = ActivityLink(url: url) }
        .task { ExpiryNotice.scheduleReminder() }
    }
}
