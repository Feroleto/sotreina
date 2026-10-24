import Testing
@testable import SoTreinaKit

@Suite struct TabBarCollapseTests {
    private func scroll(_ offsets: [Double], from start: TabBarCollapse = TabBarCollapse(), max: Double = 2000) -> TabBarCollapse {
        var state = start
        for offset in offsets { state.scrolled(to: offset, maxOffset: max) }
        return state
    }

    @Test func collapsesAfterFortyPointsDown() {
        // the first sample is only a baseline
        #expect(!scroll([100, 130]).isCollapsed)
        #expect(scroll([100, 130, 140]).isCollapsed)
        // from the top, past the zone
        #expect(scroll([0, 45]).isCollapsed)
    }

    @Test func neverCollapsesNearTheTop() {
        // a long fling that stays inside the first 40pt
        #expect(!scroll([0, 10, 20, 30, 40]).isCollapsed)
    }

    @Test func expandsAfterTwentyPointsUp() {
        let collapsed = scroll([0, 100, 200])
        #expect(collapsed.isCollapsed)
        #expect(scroll([190], from: collapsed).isCollapsed)
        #expect(!scroll([190, 180], from: collapsed).isCollapsed)
    }

    @Test func jitterNeverFlips() {
        let collapsed = scroll([0, 100, 200])
        // up and down by less than the threshold, many times
        #expect(scroll([190, 200, 185, 195, 182], from: collapsed).isCollapsed)
    }

    @Test func distanceRestartsOnEveryChangeOfDirection() {
        // 30 down, 10 up, 30 down: no single run reaches 40
        #expect(!scroll([100, 130, 120, 150]).isCollapsed)
    }

    @Test func reachingTheTopZoneExpands() {
        let collapsed = scroll([0, 100, 200])
        #expect(!scroll([30], from: collapsed).isCollapsed)
    }

    @Test func bounceIsIgnored() {
        // negative offset (pull to refresh) is inside the top zone
        #expect(!scroll([0, -60]).isCollapsed)
        // past the bottom and springing back up never expands
        let collapsed = scroll([1800, 1900, 2000])
        #expect(collapsed.isCollapsed)
        #expect(scroll([2060, 2030, 2000], from: collapsed).isCollapsed)
    }

    @Test func resetExpandsAndForgetsTheLastOffset() {
        var state = scroll([0, 100, 200])
        state.reset()
        #expect(!state.isCollapsed)
        // another scroll view far down: the first sample is only a baseline
        state.scrolled(to: 900, maxOffset: 2000)
        #expect(!state.isCollapsed)
        state.scrolled(to: 945, maxOffset: 2000)
        #expect(state.isCollapsed)
    }

    @Test func startsCollapsedForValidation() {
        #expect(TabBarCollapse(isCollapsed: true).isCollapsed)
    }

    @Test func reselect() {
        #expect(TabReselect(atRoot: true) == .scrollToTop)
        #expect(TabReselect(atRoot: false) == .popToRoot)
    }
}
