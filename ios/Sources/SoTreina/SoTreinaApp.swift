import SwiftUI

@main
struct SoTreinaApp: App {
    @State private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .tint(.soTreinaAccent)
        }
    }
}

extension Color {
    /// Same accent as the web (`--acc` in client/src/index.css)
    static let soTreinaAccent = Color(red: 0x39 / 255, green: 0x87 / 255, blue: 0xE5 / 255)
}
