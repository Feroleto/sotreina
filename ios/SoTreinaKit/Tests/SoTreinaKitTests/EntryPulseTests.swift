import Foundation
import Testing
@testable import SoTreinaKit

@Suite struct EntryPulseTests {
    /// Runs the travel frame by frame (60 fps) until the ball arrives or
    /// `limit` seconds pass; `loadedAt` is when the destination is ready.
    private func run(loadedAt: Double, limit: Double = 20) -> (arrivedAt: Double?, trace: [(t: Double, p: Double)]) {
        let dt = 1.0 / 60
        var p = 0.0
        var t = 0.0
        var trace: [(Double, Double)] = []
        while t < limit {
            t += dt
            p = EntryPulse.step(progress: p, elapsed: t, dt: dt, loaded: t >= loadedAt)
            trace.append((t, p))
            if p >= 1 { return (t, trace) }
        }
        return (nil, trace)
    }

    @Test func easeInOutQuadEndsAndMiddle() {
        #expect(EntryPulse.ease(0) == 0)
        #expect(EntryPulse.ease(0.5) == 0.5)
        #expect(EntryPulse.ease(1) == 1)
        #expect(EntryPulse.ease(0.25) < 0.25)
    }

    @Test func anInstantLoadStillTakesTheMinimumDuration() throws {
        let arrivedAt = try #require(run(loadedAt: 0).arrivedAt)
        // 96 frames of 1/60 s add up to 1.5999999999999992
        #expect(arrivedAt >= EntryPulse.minDuration - 1e-9)
        #expect(arrivedAt < EntryPulse.minDuration + 0.2)
    }

    @Test func aSlowLoadHoldsAtEightyEightPercentThenFinishes() throws {
        let result = run(loadedAt: 4)
        let beforeLoad = result.trace.filter { $0.t < 4 }
        #expect(beforeLoad.allSatisfy { $0.p <= EntryPulse.holdAt })
        // it got there and waited, it didn't stall early
        #expect(beforeLoad.last.map { $0.p > 0.87 } == true)
        let arrivedAt = try #require(result.arrivedAt)
        #expect(arrivedAt > 4)
        #expect(arrivedAt < 4.5)
    }

    @Test func progressNeverRecedes() {
        let result = run(loadedAt: 2.5)
        for (previous, next) in zip(result.trace, result.trace.dropFirst()) {
            #expect(next.p >= previous.p)
        }
        // a progress ahead of the curve is kept, not pulled back
        #expect(EntryPulse.step(progress: 0.6, elapsed: 0.1, dt: 1.0 / 60, loaded: true) == 0.6)
    }

    @Test func nothingMovesBeforeTheTravelStarts() {
        #expect(EntryPulse.step(progress: 0, elapsed: -0.3, dt: 1.0 / 60, loaded: true) == 0)
    }

    @Test func theBallRunsTheStrokeThenOnToTheDot() {
        let start = EntryPulse.ballPoint(at: 0)
        #expect(start == EntryPulse.Point(x: 3, y: 27))
        let end = EntryPulse.ballPoint(at: 1)
        #expect(abs(end.x - 41) < 1e-9 && abs(end.y - 27) < 1e-9)
        // the peak of the beat (17, 13) is 24 units in, out of ~72.67
        let peak = EntryPulse.ballPoint(at: 24.5602 / EntryPulse.ballLength)
        #expect(abs(peak.x - 17) < 0.01 && abs(peak.y - 13) < 0.01)
    }

    @Test func theLineIsFullyLitWhenTheBallLeavesTheStroke() {
        #expect(EntryPulse.litFraction(0) == 0)
        #expect(abs(EntryPulse.litFraction(EntryPulse.strokeLength / EntryPulse.ballLength) - 1) < 1e-9)
        #expect(EntryPulse.litFraction(1) == 1)
        #expect(EntryPulse.litFraction(0.5) > 0.5)
    }
}
