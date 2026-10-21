import SwiftUI
import SoTreinaKit

struct RootView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        switch session.state {
        case .loading:
            ProgressView()
                .task { await session.bootstrap() }
        case .loggedOut:
            LoginView()
        case .loggedIn(let me):
            HomeView(me: me)
        }
    }
}
