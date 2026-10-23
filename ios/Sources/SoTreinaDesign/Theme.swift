import SoTreinaKit
import SwiftUI
import UIKit

extension View {
    /// Root of the app: applies the Auto/Claro/Escuro choice, the accent as
    /// tint, Geist as the default font and the Geist navigation titles.
    public func monolitoTheme() -> some View {
        modifier(MonolitoTheme())
    }

    /// Flat Monolito list: page background, hairline separators, no cards.
    public func monolitoList() -> some View {
        listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.pageBg)
            .listRowSeparatorTint(Color.border)
    }

    /// Grouped form (login, account, sheets): page background, `--card` rows.
    public func monolitoForm() -> some View {
        scrollContentBackground(.hidden)
            .background(Color.pageBg)
            .environment(\.defaultMinListRowHeight, 46)
            .listRowSeparatorTint(Color.border)
    }
}

private struct MonolitoTheme: ViewModifier {
    @AppStorage(ThemePreference.storageKey) private var themeRaw = ThemePreference.auto.rawValue

    func body(content: Content) -> some View {
        content
            .tint(Color.accTx)
            // no root foregroundStyle: it would override the tint of every
            // button (toolbar actions, destructive red)
            .font(DSFont.body)
            .onAppear {
                NavigationBarStyle.install()
                applyTheme()
            }
            .onChange(of: themeRaw) { applyTheme() }
    }

    /// On the windows, not `preferredColorScheme`: that one doesn't reach
    /// sheets reliably and doesn't go back to the system value from `nil`.
    private func applyTheme() {
        // a validation launch's `SOTREINA_THEME` wins without being saved
        let theme = ValidationLaunch.current.theme ?? ThemePreference(stored: themeRaw)
        let style: UIUserInterfaceStyle = switch theme {
        case .auto: .unspecified
        case .light: .light
        case .dark: .dark
        }
        for scene in UIApplication.shared.connectedScenes {
            for window in (scene as? UIWindowScene)?.windows ?? [] {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}

private enum NavigationBarStyle {
    @MainActor static func install() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = monolitoUIColor(.pageBg)
        appearance.shadowColor = monolitoUIColor(.border)
        appearance.largeTitleTextAttributes = [
            .font: AppFonts.uiFont(28, weight: 600, relativeTo: .largeTitle),
            .foregroundColor: monolitoUIColor(.foreground),
            .kern: -0.56,
        ]
        appearance.titleTextAttributes = [
            .font: AppFonts.uiFont(16, weight: 600, relativeTo: .headline),
            .foregroundColor: monolitoUIColor(.foreground),
        ]
        let proxy = UINavigationBar.appearance()
        proxy.standardAppearance = appearance
        proxy.scrollEdgeAppearance = appearance
        proxy.compactAppearance = appearance
    }
}

/// Auto / Claro / Escuro, stored per device under the web's key and values.
public struct ThemePicker: View {
    @AppStorage(ThemePreference.storageKey) private var themeRaw = ThemePreference.auto.rawValue

    public init() {}

    public var body: some View {
        Picker(selection: $themeRaw) {
            Text("common.theme.auto", bundle: .l10n).tag(ThemePreference.auto.rawValue)
            Text("common.theme.light", bundle: .l10n).tag(ThemePreference.light.rawValue)
            Text("common.theme.dark", bundle: .l10n).tag(ThemePreference.dark.rawValue)
        } label: {
            Text("nav.profile.theme", bundle: .l10n)
        }
        .pickerStyle(.segmented)
    }
}
