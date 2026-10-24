import Foundation

/// An area the user follows (`User.enabledAreas` on the server; `Area` in
/// GLOSSARY.md).
public enum Area: String, Codable, Hashable, Sendable, CaseIterable {
    case run = "RUN"
    case gym = "GYM"
    case diet = "DIET"
}

/// One tab of the app's tab bar — the web's `MobileTabId`
/// (client/src/features/nav/navConfig.ts).
public enum AppTab: String, Hashable, Sendable, CaseIterable {
    case today
    case run
    case gym
    case diet

    public var area: Area? {
        switch self {
        case .run: .run
        case .gym: .gym
        case .diet: .diet
        case .today: nil
        }
    }

    /// Same rule as the web's `mobileTabsFor`: Hoje plus one tab per enabled
    /// area. Perfil lives in the account menu (the avatar at the top right).
    /// With a single area Hoje already is that area's summary, so its own tab
    /// drops out and only Hoje is left — see `showsTabBar`.
    public static func tabs(for areas: [Area]) -> [AppTab] {
        allCases.filter { tab in
            guard let area = tab.area else { return true }
            return areas.count > 1 && areas.contains(area)
        }
    }

    /// A bar with only Hoje navigates nowhere: the web drops its pill, the
    /// app hides its tab bar.
    public static func showsTabBar(for areas: [Area]) -> Bool {
        tabs(for: areas).count > 1
    }

    /// The tab bar's short names (`nav:tabs.*`).
    public func label(_ lang: Lang) -> String {
        switch (self, lang) {
        case (.today, .pt): "Hoje"
        case (.today, .en): "Today"
        case (.run, .pt): "Corrida"
        case (.run, .en): "Run"
        case (.gym, .pt): "Treino"
        case (.gym, .en): "Training"
        case (.diet, .pt): "Dieta"
        case (.diet, .en): "Diet"
        }
    }

    /// The sub-pages shown as text tabs under the area's title (web
    /// `mobileSubPages`); empty for Hoje.
    public var pages: [AppPage] {
        switch self {
        case .run: [.runOverview, .runActivities]
        case .gym: [.gymOverview, .gymRoutines, .gymHistory]
        case .diet: [.dietOverview, .dietHistory]
        case .today: []
        }
    }

    /// Where tapping the tab lands (the web's `MOBILE_TABS[].page`).
    public var landingPage: AppPage? {
        switch self {
        case .run: .runActivities
        case .gym: .gymOverview
        case .diet: .dietOverview
        case .today: nil
        }
    }
}

/// A sub-page of an area — the web's `PageId` for the areas. Run's Analysis
/// stays out: it's disabled on the web (`DISABLED_PAGES`).
public enum AppPage: String, Hashable, Sendable, CaseIterable {
    case runOverview
    case runActivities
    case gymOverview
    case gymRoutines
    case gymHistory
    case dietOverview
    case dietHistory

    /// `nav:sections.*`
    public func label(_ lang: Lang) -> String {
        switch (self, lang) {
        case (.runOverview, .pt), (.gymOverview, .pt), (.dietOverview, .pt): "Visão geral"
        case (.runOverview, .en), (.gymOverview, .en), (.dietOverview, .en): "Overview"
        case (.runActivities, .pt): "Atividades"
        case (.runActivities, .en): "Activities"
        case (.gymRoutines, .pt): "Rotinas"
        case (.gymRoutines, .en): "Routines"
        case (.gymHistory, .pt), (.dietHistory, .pt): "Histórico"
        case (.gymHistory, .en), (.dietHistory, .en): "History"
        }
    }
}
