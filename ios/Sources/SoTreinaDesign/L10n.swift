import Foundation
import SoTreinaKit

/// The interface strings: `Localizable.strings`/`.stringsdict` in
/// `Resources/Strings/{pt,en}.lproj`, in this target so the app and the Live
/// Activity (another process) read the same files. `.xcstrings` doesn't build
/// with xtool (see ios/README.md, "Localização").
///
/// Keys follow the web's (`client/src/i18n/locales`), namespace included:
/// `gym.summary.done`. An interpolated value adds its format to the key, the
/// way `LocalizedStringKey` builds it: `Text("gym.summary.prFrom \(set)")`
/// looks up `"gym.summary.prFrom %@"`, an `Int` adds `%lld`.
public enum L10n {
    /// For views: `Text("key", bundle: .l10n)`. The root `\.locale` (from
    /// `AppLanguageStore`) picks the `.lproj`, so a language change redraws.
    public static let bundle = Bundle.module

    /// The `.lproj` of one language. Outside SwiftUI (notifications, error
    /// text, the Live Activity) the `\.locale` doesn't reach, so the language
    /// has to be explicit.
    public static func bundle(for lang: Lang) -> Bundle {
        Bundle.module.path(forResource: lang.rawValue, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .module
    }

    /// `string("gym.summary.prFrom %@", lang: .en, "20 kg × 5")`. Plurals in
    /// the `.stringsdict` resolve through the same call.
    public static func string(_ key: String, lang: Lang, _ args: CVarArg...) -> String {
        string(key, lang: lang, arguments: args)
    }

    public static func string(_ key: String, lang: Lang, arguments args: [CVarArg]) -> String {
        let format = bundle(for: lang).localizedString(forKey: key, value: nil, table: nil)
        guard !args.isEmpty else { return format }
        return String(format: format, locale: Locale(identifier: lang.localeIdentifier), arguments: args)
    }
}

extension Bundle {
    /// `Text("key", bundle: .l10n)`
    public static var l10n: Bundle { L10n.bundle }
}
