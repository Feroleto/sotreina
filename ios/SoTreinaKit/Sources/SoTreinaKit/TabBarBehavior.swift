import Foundation

/// When the floating tab bar folds into its circle (spec
/// ios-floating-tab-bar §3): after 40pt scrolled down, never within the first
/// 40pt of the content, and back after 20pt up. Distances add up from the
/// last change of direction, so small jitters never flip it. The elastic
/// bounce past either end is ignored.
public struct TabBarCollapse: Equatable, Sendable {
    public static let topZone: Double = 40
    public static let collapseDistance: Double = 40
    public static let expandDistance: Double = 20

    public private(set) var isCollapsed: Bool
    private var lastOffset: Double?
    /// where the current run in one direction started
    private var anchor: Double = 0
    /// 1 down, -1 up, 0 not moving yet
    private var direction = 0

    public init(isCollapsed: Bool = false) {
        self.isCollapsed = isCollapsed
    }

    /// `offset` is 0 at the top of the content; `maxOffset` is the bottom.
    public mutating func scrolled(to offset: Double, maxOffset: Double) {
        if offset <= Self.topZone {
            isCollapsed = false
            lastOffset = max(offset, 0)
            anchor = max(offset, 0)
            direction = 0
            return
        }
        // the bounce at the bottom springs back up on its own
        guard offset <= max(maxOffset, 0) else { return }
        guard let last = lastOffset else {
            lastOffset = offset
            anchor = offset
            return
        }
        let delta = offset - last
        guard delta != 0 else { return }
        let step = delta > 0 ? 1 : -1
        if step != direction {
            direction = step
            anchor = last
        }
        lastOffset = offset
        let travelled = offset - anchor
        if direction > 0, travelled >= Self.collapseDistance {
            isCollapsed = true
        } else if direction < 0, -travelled >= Self.expandDistance {
            isCollapsed = false
        }
    }

    /// Expanded, and the next offset starts a fresh measure (a tab switch, a
    /// push or pop, a tap on the circle: another scroll view, or the same one
    /// somewhere else).
    public mutating func reset() {
        isCollapsed = false
        lastOffset = nil
        direction = 0
    }
}

/// A tap on the tab that's already selected: pop to the tab's root, or
/// scroll the root to the top when already there (iOS convention).
public enum TabReselect: Equatable, Sendable {
    case popToRoot
    case scrollToTop

    public init(atRoot: Bool) {
        self = atRoot ? .scrollToTop : .popToRoot
    }
}
