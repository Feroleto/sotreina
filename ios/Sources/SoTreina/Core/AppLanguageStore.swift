import Foundation
import Observation
import SoTreinaKit

/// The language the app speaks (spec §2): the iPhone's by default, or the one
/// picked in Perfil. Applied at the root as the SwiftUI `locale`, sent to the
/// API as `Accept-Language` and to the Live Activity in its state.
@MainActor
@Observable
final class AppLanguageStore {
    static let shared = AppLanguageStore()

    private nonisolated static let key = "appLanguage"

    var choice: AppLanguage {
        didSet { UserDefaults.standard.set(choice.rawValue, forKey: Self.key) }
    }

    /// `SOTREINA_LANG` from a validation launch wins over the saved choice,
    /// without replacing it (debug only, `ValidationLaunch`)
    var lang: Lang { ValidationLaunch.current.lang ?? choice.resolved(preferredLanguages: Locale.preferredLanguages) }

    var locale: Locale { Locale(identifier: lang.localeIdentifier) }

    private init() {
        choice = Self.storedChoice
    }

    /// For code off the main actor (the API client): reads the same setting.
    nonisolated static var current: Lang {
        ValidationLaunch.current.lang ?? storedChoice.resolved(preferredLanguages: Locale.preferredLanguages)
    }

    private nonisolated static var storedChoice: AppLanguage {
        UserDefaults.standard.string(forKey: key).flatMap(AppLanguage.init(rawValue:)) ?? .auto
    }
}
