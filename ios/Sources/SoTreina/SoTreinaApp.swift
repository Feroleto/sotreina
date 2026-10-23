import SoTreinaDesign
import SwiftUI
import UserNotifications

@main
struct SoTreinaApp: App {
    @State private var session = SessionStore()
    // held as state so a language change re-renders the whole app
    @State private var language = AppLanguageStore.shared

    init() {
        // the delegate is weak: a static instance keeps it alive
        UNUserNotificationCenter.current().delegate = ForegroundNotificationPresenter.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(language)
                // number/date formatting and localized strings follow the app's language
                .environment(\.locale, language.locale)
                .monolitoTheme()
        }
    }
}
