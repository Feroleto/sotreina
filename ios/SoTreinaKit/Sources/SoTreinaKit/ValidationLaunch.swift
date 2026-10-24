import Foundation

/// Debug-only launch state for the visual validation (README "Validação
/// visual"): `scripts/launch.sh SOTREINA_SCREEN=gymRoutines SOTREINA_THEME=dark
/// SOTREINA_LANG=en` opens the app straight on that screen, so the agent can
/// walk the checklist alone. Overrides the saved preferences without writing
/// them: a normal launch afterwards is back to what the user picked. Unknown
/// values are ignored, never an error.
public struct ValidationLaunch: Equatable, Sendable {
    public enum Destination: Equatable, Sendable {
        /// a tab's root (`today` or an area's landing page)
        case tab(AppTab)
        case page(AppPage)
        /// Perfil, pushed over Hoje (it isn't a tab: the account menu opens it)
        case profile
        /// Hoje with the account menu open
        case accountMenu
        /// the open workout, full screen
        case session
        /// the open workout folded into the bar above the tab bar
        case sessionMinimized
    }

    public var destination: Destination?
    public var theme: ThemePreference?
    public var lang: Lang?

    public init(destination: Destination? = nil, theme: ThemePreference? = nil, lang: Lang? = nil) {
        self.destination = destination
        self.theme = theme
        self.lang = lang
    }

    public static let screenKey = "SOTREINA_SCREEN"
    public static let themeKey = "SOTREINA_THEME"
    public static let langKey = "SOTREINA_LANG"

    public init(environment: [String: String]) {
        destination = environment[Self.screenKey].flatMap(Destination.init(name:))
        // `auto` would mean "don't override", so only the two explicit ones
        theme = environment[Self.themeKey].flatMap(ThemePreference.init(rawValue:)).flatMap { $0 == .auto ? nil : $0 }
        lang = environment[Self.langKey].flatMap(Lang.init(rawValue:))
    }

    /// This process's launch. Always empty in a release build.
    public static let current: ValidationLaunch = {
        #if DEBUG
        ValidationLaunch(environment: ProcessInfo.processInfo.environment)
        #else
        ValidationLaunch()
        #endif
    }()

    /// The tab the app opens on, if the destination names one.
    public var tab: AppTab? {
        switch destination {
        case .tab(let tab): tab
        case .page(let page): page.tab
        case .profile, .accountMenu: .today
        case .session, .sessionMinimized, nil: nil
        }
    }

    /// Whether an open workout starts folded into the bar. Any screen other
    /// than the session itself needs it, or the session would cover it.
    public var startsSessionMinimized: Bool {
        switch destination {
        case .session, nil: false
        case .tab, .page, .profile, .accountMenu, .sessionMinimized: true
        }
    }
}

extension ValidationLaunch.Destination {
    /// `session`, `sessionMinimized`, `profile`, `accountMenu`, an `AppPage`
    /// (`gymRoutines`) or an `AppTab` (`gym`).
    public init?(name: String) {
        switch name {
        case "session": self = .session
        case "sessionMinimized": self = .sessionMinimized
        case "profile": self = .profile
        case "accountMenu": self = .accountMenu
        default:
            if let page = AppPage(rawValue: name) {
                self = .page(page)
            } else if let tab = AppTab(rawValue: name) {
                self = .tab(tab)
            } else {
                return nil
            }
        }
    }
}

extension AppPage {
    /// The tab whose header lists this page.
    public var tab: AppTab {
        AppTab.allCases.first { $0.pages.contains(self) }!
    }
}
