import CoreText
import os
import SwiftUI
import UIKit

/// Geist and Geist Mono, the web's fonts (`@fontsource-variable/geist*`),
/// shipped as SwiftPM resources and registered at runtime — no UIAppFonts
/// entry in Info.plist. The files are the variable TTFs from the `geist` npm
/// package (OFL, license next to them in Resources/Fonts). Lives in this
/// target so the app and the Live Activity (another process) both get them.
public enum AppFonts {
    public static let sans = "Geist"
    public static let mono = "Geist Mono"

    /// Lazy: the first `Font.geist`/`Font.geistMono` call registers both files
    /// in the calling process.
    public static let registered: Bool = {
        let log = Logger(subsystem: "com.feroleto.sotreina", category: "fonts")
        var ok = true
        for name in ["Geist-Variable", "GeistMono-Variable"] {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts") else {
                log.error("font file missing: \(name, privacy: .public)")
                ok = false
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                log.error("register \(name, privacy: .public) failed: \(String(describing: error?.takeRetainedValue()), privacy: .public)")
                ok = false
            }
        }
        log.notice("fonts registered: \(ok, privacy: .public) in \(Bundle.main.bundleIdentifier ?? "?", privacy: .public)")
        return ok
    }()

    /// UIKit font for appearance proxies (navigation bar titles), scaled with
    /// Dynamic Type like `Font.custom(_:size:relativeTo:)`.
    /// `weight` is the CSS weight (400 regular … 700 bold). A variable font
    /// ignores the UIKit weight trait, so it goes on the `wght` axis.
    public static func uiFont(_ size: CGFloat, weight: Int, relativeTo style: UIFont.TextStyle) -> UIFont {
        _ = registered
        guard let base = UIFont(name: sans, size: size) else {
            return UIFontMetrics(forTextStyle: style).scaledFont(for: .systemFont(ofSize: size, weight: .semibold))
        }
        let wghtAxis = 0x7767_6874  // 'wght'
        let weighted = base.fontDescriptor.addingAttributes([
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [wghtAxis: weight],
        ])
        return UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont(descriptor: weighted, size: size))
    }
}

extension Font {
    /// Geist scaled with Dynamic Type relative to `style`.
    public static func geist(_ size: CGFloat, relativeTo style: TextStyle = .body) -> Font {
        _ = AppFonts.registered
        return .custom(AppFonts.sans, size: size, relativeTo: style)
    }

    public static func geistMono(_ size: CGFloat, relativeTo style: TextStyle = .body) -> Font {
        _ = AppFonts.registered
        return .custom(AppFonts.mono, size: size, relativeTo: style)
    }
}
