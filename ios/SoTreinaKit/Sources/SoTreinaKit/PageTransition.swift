import Foundation

/// How the app moves between pages it owns (spec ios-transicoes-de-pagina):
/// a tab switch fades the new tab in over the old one with its body rising a
/// little, a sub-page cross-fades, and anything else is the same page.
/// Pushes keep the system slide and aren't covered here.
public enum PageTransition: Equatable, Sendable {
    case none
    /// the new tab on top of the old, 0 → 1; its body rises by `rise` points
    case tab(rise: Double, duration: Double)
    /// the old and new sub-page cross-fade in place
    case subpage(duration: Double)

    /// The tokens, in seconds and points; tune on the iPhone here.
    public static let tabFadeIn = 0.22
    public static let tabRise = 8.0
    public static let subpageCrossfade = 0.18
    /// Reduce Motion: fades only, a little shorter
    public static let reducedFade = 0.15
    /// the sub-tab underline, the same curve as the pill's chip
    public static let underline = 0.32

    /// Where the user is: a tab, and its sub-page when it has them.
    public struct Place: Equatable, Sendable {
        public var tab: AppTab
        public var page: AppPage?

        public init(tab: AppTab, page: AppPage? = nil) {
            self.tab = tab
            self.page = page
        }
    }

    /// From one place to another. A tab switch that also lands on a page
    /// (Hoje's taps) is a tab transition alone: the page is applied without
    /// a second animation.
    public static func between(_ from: Place, _ to: Place, reduceMotion: Bool) -> PageTransition {
        if from.tab != to.tab {
            return reduceMotion ? .tab(rise: 0, duration: reducedFade) : .tab(rise: tabRise, duration: tabFadeIn)
        }
        if from.page != to.page {
            return .subpage(duration: reduceMotion ? reducedFade : subpageCrossfade)
        }
        return .none
    }
}

/// Which tabs are on screen while tab transitions run (spec §3.1): the
/// active one on top, fading in, and the one it covers kept opaque below
/// until the fade ends. A tap mid-fade wins: the tab on top then becomes the
/// one below, any other is hidden at once, and only the newest fade's end
/// hides what's below (`generation`).
public struct TabTransitionQueue<Tab: Hashable & Sendable>: Equatable, Sendable {
    public private(set) var active: Tab
    public private(set) var below: Tab?
    /// bumped on every switch; a fade's end must match it to hide `below`
    public private(set) var generation = 0
    /// the generation each tab last became active in (0: the launch tab)
    public private(set) var activatedIn: [Tab: Int]

    public init(active: Tab) {
        self.active = active
        activatedIn = [active: 0]
    }

    /// A tap on `tab`. False when it already is the active one (that's a
    /// reselect, not a switch).
    @discardableResult
    public mutating func select(_ tab: Tab) -> Bool {
        guard tab != active else { return false }
        below = active
        active = tab
        generation += 1
        activatedIn[tab] = generation
        return true
    }

    /// The fade started in `generation` ended. A stale one hides nothing.
    public mutating func finish(_ generation: Int) {
        guard generation == self.generation else { return }
        below = nil
    }

    public func isVisible(_ tab: Tab) -> Bool {
        tab == active || tab == below
    }
}
