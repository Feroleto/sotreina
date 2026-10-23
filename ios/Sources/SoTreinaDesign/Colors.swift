import SoTreinaKit
import SwiftUI
import UIKit

/// The Monolito tokens (`Monolito` in the Kit) as dynamic colors: each one
/// resolves to its light or dark value from the trait collection, so the
/// theme switch (system or the Auto/Claro/Escuro choice) needs no re-render.
extension Color {
    public static let pageBg = monolito(.pageBg)
    public static let fg = monolito(.foreground)
    public static let card = monolito(.card)
    public static let mutedFg = monolito(.mutedForeground)
    public static let border = monolito(.border)
    public static let chip = monolito(.chip)
    public static let bar = monolito(.bar)
    public static let gridAx = monolito(.gridAx)
    /// mustard: progress, charts, active state, primary button background
    public static let acc = monolito(.acc)
    /// text and icons on `acc` — always this, never white
    public static let accFg = monolito(.accFg)
    /// mustard used as text/tint on the page background
    public static let accTx = monolito(.accTx)
    /// `--acc-bg`: tinted chip/badge background
    public static let accBg = Color(uiColor: UIColor { traits in
        let opacity = traits.userInterfaceStyle == .dark ? Monolito.accBgOpacity.dark : Monolito.accBgOpacity.light
        return uiColor(Monolito.color(.acc).light).withAlphaComponent(opacity)
    })
    public static let pos = monolito(.pos)
    public static let neg = monolito(.neg)

    private static func monolito(_ token: Monolito.Token) -> Color {
        Color(uiColor: monolitoUIColor(token))
    }
}

public func monolitoUIColor(_ token: Monolito.Token) -> UIColor {
    let pair = Monolito.color(token)
    return UIColor { traits in
        uiColor(traits.userInterfaceStyle == .dark ? pair.dark : pair.light)
    }
}

private func uiColor(_ hex: UInt32) -> UIColor {
    let c = Monolito.rgb(hex)
    return UIColor(red: c.red, green: c.green, blue: c.blue, alpha: 1)
}
