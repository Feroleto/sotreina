import SwiftUI
import SoTreinaKit

struct RootView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        Group {
            switch session.state {
            case .loading:
                ProgressView()
                    .task { await session.bootstrap() }
            case .loggedOut:
                LoginView()
            case .loggedIn(let me):
                WorkoutRootView(session: session, me: me)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { ExpiryBanner() }
        .task { ExpiryNotice.scheduleReminder() }
    }
}
