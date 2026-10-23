import Foundation

/// The two languages the app speaks — same pair as the web (`client/src/i18n`).
public enum Lang: String, Codable, Hashable, Sendable, CaseIterable {
    case pt
    case en

    /// `Accept-Language` for the API (the backend localizes exercise names).
    public var acceptLanguage: String { rawValue }

    /// For `Locale(identifier:)`: number and date formatting follow the language.
    public var localeIdentifier: String {
        switch self {
        case .pt: "pt_BR"
        case .en: "en_US"
        }
    }

    /// Same rule as the web's `navigator.language` detection: any Portuguese
    /// variant is PT, everything else (including unsupported languages) is EN.
    public static func resolve(preferredLanguages: [String]) -> Lang {
        guard let first = preferredLanguages.first?.lowercased() else { return .en }
        return first.hasPrefix("pt") ? .pt : .en
    }
}

/// What the user picked in Perfil. `auto` follows the iPhone's language.
public enum AppLanguage: String, Codable, Hashable, Sendable, CaseIterable {
    case auto
    case pt
    case en

    public func resolved(preferredLanguages: [String]) -> Lang {
        switch self {
        case .auto: Lang.resolve(preferredLanguages: preferredLanguages)
        case .pt: .pt
        case .en: .en
        }
    }
}
