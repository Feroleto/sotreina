import Foundation
import Testing
@testable import SoTreinaKit

@Suite struct NavigationTests {
    @Test func tabsFollowTheWebsMobileTabsFor() {
        #expect(AppTab.tabs(for: [.run, .gym, .diet]) == [.today, .run, .gym, .diet])
        #expect(AppTab.tabs(for: [.gym, .diet]) == [.today, .gym, .diet])
        // a single area: Hoje is already its summary, so its tab drops out
        #expect(AppTab.tabs(for: [.gym]) == [.today])
        #expect(AppTab.tabs(for: []) == [.today])
    }

    @Test func tabBarOnlyWithSomewhereToGo() {
        #expect(AppTab.showsTabBar(for: [.run, .gym]))
        #expect(!AppTab.showsTabBar(for: [.gym]))
        #expect(!AppTab.showsTabBar(for: []))
    }

    @Test func areaOrderInTheTabBarIsFixedNotThePayloads() {
        #expect(AppTab.tabs(for: [.diet, .run]) == [.today, .run, .diet])
    }

    @Test func subPagesAndLandingPages() {
        #expect(AppTab.gym.pages == [.gymOverview, .gymRoutines, .gymHistory])
        #expect(AppTab.run.landingPage == .runActivities)
        #expect(AppTab.today.pages.isEmpty)
        #expect(AppTab.today.landingPage == nil)
        for tab in AppTab.allCases {
            if let landing = tab.landingPage { #expect(tab.pages.contains(landing)) }
        }
    }

    @Test func labelsInBothLanguages() {
        #expect(AppTab.gym.label(.pt) == "Treino")
        #expect(AppTab.gym.label(.en) == "Training")
        #expect(AppPage.gymRoutines.label(.pt) == "Rotinas")
        #expect(AppPage.dietHistory.label(.en) == "History")
    }

    @Test func meDecodesEnabledAreasAndSkipsUnknownOnes() throws {
        let json = Data(#"{"id":"u1","hasStravaAccount":false,"hasPassword":true,"enabledAreas":["GYM","SWIM","DIET"]}"#.utf8)
        let me = try JSONDecoder().decode(Me.self, from: json)
        #expect(me.enabledAreas == [.gym, .diet])

        let old = Data(#"{"id":"u1","hasStravaAccount":false,"hasPassword":true}"#.utf8)
        #expect(try JSONDecoder().decode(Me.self, from: old).enabledAreas.isEmpty)
    }
}
