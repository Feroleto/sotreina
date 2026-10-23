import Foundation

/// The web's "Monolito" palette (client/src/index.css, `:root` and `.dark`),
/// as plain hex pairs so the app and the Live Activity draw the same colors.
/// `MonolitoTests` reads index.css and fails when the two drift.
public enum Monolito {
    public enum Token: CaseIterable, Sendable {
        case pageBg, foreground, card, mutedForeground, border, chip, bar, gridAx
        case acc, accFg, accTx
        case pos, neg
        /// history dots: a free workout, and the routines in first-seen order
        case dotEasy, chart1, chart2, chart4

        /// The CSS custom property it mirrors; nil for tokens the web derives
        /// with `color-mix` (precomputed here, pinned by a test).
        public var cssName: String? {
            switch self {
            case .pageBg: "page-bg"
            case .foreground: "foreground"
            case .card: "card"
            case .mutedForeground: "muted-foreground"
            case .border: "border"
            case .chip: "chip"
            case .bar: "bar"
            case .gridAx: "grid-ax"
            case .acc: "acc"
            case .accFg: "acc-fg"
            case .accTx: nil
            case .pos: "pos"
            case .neg: "neg"
            case .dotEasy: "dot-easy"
            // oklch() on the web, converted to sRGB here and pinned by a test
            case .chart1, .chart2, .chart4: nil
            }
        }
    }

    public struct Pair: Equatable, Sendable {
        public let light: UInt32
        public let dark: UInt32
    }

    public static func color(_ token: Token) -> Pair {
        switch token {
        case .pageBg: Pair(light: 0xF4F3F0, dark: 0x0B0B0C)
        case .foreground: Pair(light: 0x151515, dark: 0xF3F2EF)
        case .card: Pair(light: 0xFFFFFF, dark: 0x161618)
        case .mutedForeground: Pair(light: 0x68665F, dark: 0x93928E)
        case .border: Pair(light: 0xE2DFD9, dark: 0x26262A)
        case .chip: Pair(light: 0xE7E5E0, dark: 0x222225)
        case .bar: Pair(light: 0xD6D3CC, dark: 0x2E2E33)
        case .gridAx: Pair(light: 0xD6D3CC, dark: 0x2E2E33)
        // the mustard accent: progress, charts, active state, primary button
        case .acc: Pair(light: 0xD9A441, dark: 0xD9A441)
        // text on mustard — never white (unreadable on the accent)
        case .accFg: Pair(light: 0x141414, dark: 0x141414)
        // mustard as text: darkened on light backgrounds
        case .accTx: Pair(light: 0x674C1A, dark: 0xD9A441)
        case .pos: Pair(light: 0x2F7D55, dark: 0x5FBF8A)
        case .neg: Pair(light: 0xB8431F, dark: 0xE5765A)
        case .dotEasy: Pair(light: 0xA8A59E, dark: 0x5C5B58)
        // --chart-1/2/4: light oklch(0.646 0.222 41.116) / (0.6 0.118 184.704) /
        // (0.828 0.189 84.429); dark (0.488 0.243 264.376) / (0.696 0.17 162.48) /
        // (0.627 0.265 303.9)
        case .chart1: Pair(light: 0xF54900, dark: 0x1447E6)
        case .chart2: Pair(light: 0x009689, dark: 0x00BC7D)
        case .chart4: Pair(light: 0xFFB900, dark: 0xAD46FF)
        }
    }

    /// `--acc-bg`: the accent over the background at this opacity (16% light,
    /// 18% dark) — chips and badges.
    public static let accBgOpacity = (light: 0.16, dark: 0.18)

    public static func rgb(_ hex: UInt32) -> (red: Double, green: Double, blue: Double) {
        (
            Double((hex >> 16) & 0xFF) / 255,
            Double((hex >> 8) & 0xFF) / 255,
            Double(hex & 0xFF) / 255
        )
    }
}

/// Auto/Claro/Escuro, per device like the web's `localStorage.theme` (same
/// stored values). Auto follows the system.
public enum ThemePreference: String, CaseIterable, Sendable {
    case auto, light, dark

    public static let storageKey = "theme"

    public init(stored: String) {
        self = ThemePreference(rawValue: stored) ?? .auto
    }
}
