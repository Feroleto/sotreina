import Foundation
import Testing
@testable import SoTreinaKit

@Suite struct RestTimerTests {
    private let t0 = Date(timeIntervalSince1970: 1_792_000_000)

    @Test func startsWithTheDefaultAndCountsDownByTimestamp() {
        var timer = RestTimer()
        timer.start(now: t0)

        #expect(timer.active == RestTimer.Active(endsAt: t0.addingTimeInterval(90), duration: 90))
        #expect(timer.remaining(now: t0.addingTimeInterval(30)) == 60)
        #expect(!timer.isFinished(now: t0.addingTimeInterval(89)))
        #expect(timer.isFinished(now: t0.addingTimeInterval(90)))
        // never negative, however late the check
        #expect(timer.remaining(now: t0.addingTimeInterval(500)) == 0)
    }

    @Test func plus15ExtendsAndBecomesTheNextDefault() {
        var timer = RestTimer(duration: 90)
        timer.start(now: t0)
        timer.add(seconds: 15, now: t0.addingTimeInterval(30))

        #expect(timer.remaining(now: t0.addingTimeInterval(30)) == 75)
        #expect(timer.duration == 75)
        #expect(timer.active?.duration == 105)
    }

    @Test func minus15FloorsAtNow() {
        var timer = RestTimer(duration: 90)
        timer.start(now: t0)
        timer.add(seconds: -15, now: t0.addingTimeInterval(80))

        #expect(timer.isFinished(now: t0.addingTimeInterval(80)))
        // the remembered default never drops below the 15s minimum
        #expect(timer.duration == 15)
    }

    @Test func addWithoutARunningRestDoesNothing() {
        var timer = RestTimer(duration: 120)
        timer.add(seconds: 15, now: t0)
        #expect(timer.active == nil)
        #expect(timer.duration == 120)
    }

    @Test func skipStopsButKeepsTheDefault() {
        var timer = RestTimer(duration: 120)
        timer.start(now: t0)
        timer.skip()
        #expect(timer.active == nil)
        #expect(timer.duration == 120)
    }

    @Test func restoringDropsARestThatEndedWhileClosed() {
        let elapsed = RestTimer.Active(endsAt: t0.addingTimeInterval(-1), duration: 90)
        let running = RestTimer.Active(endsAt: t0.addingTimeInterval(40), duration: 90)

        #expect(RestTimer(restoring: elapsed, now: t0).active == nil)
        #expect(RestTimer(restoring: running, now: t0).remaining(now: t0) == 40)
    }

    @Test func durationIsClamped() {
        #expect(RestTimer(duration: 5).duration == 15)
        #expect(RestTimer(duration: 9_999).duration == 600)
        var timer = RestTimer()
        timer.setDuration(150)
        #expect(timer.duration == 150)
    }

    @Test func perExerciseRestRunsWithoutBecomingTheDefault() {
        var timer = RestTimer(duration: 90)
        timer.start(seconds: 180, now: t0)
        #expect(timer.remaining(now: t0) == 180)

        timer.add(seconds: 15, now: t0)
        #expect(timer.remaining(now: t0) == 195)
        #expect(timer.duration == 90)

        timer.skip()
        timer.start(now: t0)
        #expect(timer.remaining(now: t0) == 90)
    }

    @Test func overriddenFlagSurvivesPersistenceAndOldDataReadsAsFalse() throws {
        let active = RestTimer.Active(endsAt: t0, duration: 120, overridden: true)
        let data = try JSONEncoder().encode(active)
        #expect(try JSONDecoder().decode(RestTimer.Active.self, from: data) == active)

        let legacy = Data(#"{"endsAt": 0, "duration": 90}"#.utf8)
        #expect(try JSONDecoder().decode(RestTimer.Active.self, from: legacy).overridden == false)
    }
}
