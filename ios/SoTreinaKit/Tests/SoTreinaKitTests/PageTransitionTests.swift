import Testing
@testable import SoTreinaKit

@Suite struct PageTransitionTests {
    private typealias Place = PageTransition.Place

    @Test func samePlaceIsNoTransition() {
        let place = Place(tab: .gym, page: .gymRoutines)
        #expect(PageTransition.between(place, place, reduceMotion: false) == .none)
        #expect(PageTransition.between(Place(tab: .today), Place(tab: .today), reduceMotion: true) == .none)
    }

    @Test func tabSwitchFadesAndRises() {
        let transition = PageTransition.between(Place(tab: .run, page: .runOverview), Place(tab: .gym, page: .gymOverview), reduceMotion: false)
        #expect(transition == .tab(rise: 8, duration: 0.22))
    }

    @Test func todayToAPageIsOneTabTransition() {
        // the page comes along without its own cross-fade
        let transition = PageTransition.between(Place(tab: .today), Place(tab: .gym, page: .gymHistory), reduceMotion: false)
        #expect(transition == .tab(rise: 8, duration: 0.22))
    }

    @Test func subPageCrossFades() {
        let transition = PageTransition.between(Place(tab: .gym, page: .gymOverview), Place(tab: .gym, page: .gymRoutines), reduceMotion: false)
        #expect(transition == .subpage(duration: 0.18))
    }

    @Test func reduceMotionIsFadeOnly() {
        #expect(PageTransition.between(Place(tab: .run), Place(tab: .diet), reduceMotion: true) == .tab(rise: 0, duration: 0.15))
        #expect(PageTransition.between(Place(tab: .diet, page: .dietOverview), Place(tab: .diet, page: .dietHistory), reduceMotion: true) == .subpage(duration: 0.15))
    }
}

@Suite struct TabTransitionQueueTests {
    @Test func launchTabIsAloneAndUnanimated() {
        let queue = TabTransitionQueue(active: AppTab.today)
        #expect(queue.isVisible(.today))
        #expect(queue.below == nil)
        #expect(queue.activatedIn[.today] == 0)
    }

    @Test func reselectIsNoSwitch() {
        var queue = TabTransitionQueue(active: AppTab.run)
        let switched = queue.select(.run)
        #expect(!switched)
        #expect(queue.generation == 0)
        #expect(queue.below == nil)
    }

    @Test func oldTabStaysBelowUntilTheFadeEnds() {
        var queue = TabTransitionQueue(active: AppTab.run)
        let switched = queue.select(.gym)
        #expect(switched)
        #expect(queue.active == .gym)
        #expect(queue.isVisible(.run))
        queue.finish(queue.generation)
        #expect(!queue.isVisible(.run))
        #expect(queue.isVisible(.gym))
    }

    @Test func rapidTapsHideTheFirstAtOnceAndTheSecondOnTheLastFade() {
        var queue = TabTransitionQueue(active: AppTab.today)
        queue.select(.run)
        let toRun = queue.generation
        queue.select(.diet)
        let toDiet = queue.generation
        // Hoje is neither the new tab nor the one on top: gone now
        #expect(!queue.isVisible(.today))
        #expect(queue.below == .run)
        // Corrida's fade ending late hides nothing
        queue.finish(toRun)
        #expect(queue.isVisible(.run))
        queue.finish(toDiet)
        #expect(!queue.isVisible(.run))
        #expect(queue.active == .diet)
    }

    @Test func staleFinishNeverHidesTheActiveTab() {
        var queue = TabTransitionQueue(active: AppTab.today)
        queue.select(.run)
        let toRun = queue.generation
        // back to Hoje mid-fade: Corrida goes below
        queue.select(.today)
        queue.finish(toRun)
        #expect(queue.isVisible(.today))
        #expect(queue.below == .run)
    }

    @Test func everyActivationGetsANewGeneration() {
        var queue = TabTransitionQueue(active: AppTab.today)
        queue.select(.run)
        queue.select(.today)
        queue.select(.run)
        #expect(queue.activatedIn[.run] == 3)
        #expect(queue.activatedIn[.today] == 2)
    }
}
