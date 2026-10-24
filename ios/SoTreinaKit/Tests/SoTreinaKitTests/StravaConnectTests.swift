import Foundation
import Testing
@testable import SoTreinaKit

@Suite struct StravaConnectTests {
    @Test func readsTheStatusTheCallbackReturnsTo() {
        #expect(StravaConnectReturn(url: URL(string: "sotreina://strava/connected?status=ok")!) == .ok)
        #expect(StravaConnectReturn(url: URL(string: "sotreina://strava/connected?status=conflict")!) == .conflict)
        #expect(StravaConnectReturn(url: URL(string: "sotreina://strava/connected?status=error")!) == .error)
    }

    @Test func anythingElseIsAnError() {
        #expect(StravaConnectReturn(url: URL(string: "sotreina://strava/connected?status=weird")!) == .error)
        #expect(StravaConnectReturn(url: URL(string: "sotreina://strava/connected")!) == .error)
        #expect(StravaConnectReturn(url: URL(string: "sotreina://rest/skip?status=ok")!) == .error)
    }

    @Test func decodesTheIdleStatusOfAFreshAccount() throws {
        // real GET /strava/sync/status for an account that never synced
        let url = try #require(Bundle.module.url(forResource: "strava-sync-status", withExtension: "json", subdirectory: "Fixtures"))
        let status = try APICoding.makeDecoder().decode(SyncStatus.self, from: Data(contentsOf: url))
        #expect(status.state == .idle)
        #expect(status.phase == nil)
        #expect(status.total == nil)
        #expect(status.processed == 0)
    }

    @Test func decodesARateLimitedRun() throws {
        // derived by hand from SyncProgress in strava-sync.service.ts
        let json = #"""
        {"state":"running","phase":"rate_limited","total":120,"processed":40,"synced":39,"errors":1,
         "etaSeconds":300,"processingDate":"2021-03-14T09:30:00Z","startedAt":"2026-10-24T11:00:00.000Z",
         "finishedAt":null,"message":null,"rateLimitResetAt":"2026-10-24T11:15:00.000Z"}
        """#
        let status = try APICoding.makeDecoder().decode(SyncStatus.self, from: Data(json.utf8))
        #expect(status.state == .running)
        #expect(status.phase == .rateLimited)
        #expect(status.total == 120)
        #expect(status.processed == 40)
        #expect(status.processingDate == APICoding.parseDate("2021-03-14T09:30:00Z"))
        #expect(status.rateLimitResetAt == APICoding.parseDate("2026-10-24T11:15:00.000Z"))
    }

    // MARK: FirstSyncProgress

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    private static let now = APICoding.parseDate("2026-10-24T11:00:00Z")!

    private func progress(_ status: SyncStatus) -> FirstSyncProgress {
        FirstSyncProgress(status: status, now: Self.now, calendar: Self.utc)
    }

    @Test func listingHasNoCountYet() {
        let p = progress(SyncStatus(state: .running, phase: .listing))
        #expect(p.count == nil)
        #expect(p.fraction == nil)
        #expect(p.detail == nil)
        #expect(!p.isFinished)
    }

    @Test func processingCountsAndNamesTheYear() {
        let p = progress(SyncStatus(
            state: .running, phase: .processing, total: 120, processed: 30,
            processingDate: APICoding.parseDate("2021-03-14T09:30:00Z")
        ))
        #expect(p.count == .init(processed: 30, total: 120))
        #expect(p.fraction == 0.25)
        #expect(p.detail == .processingYear(2021))
    }

    @Test func anAccountWithoutRunsIsFull() {
        #expect(progress(SyncStatus(state: .running, phase: .processing, total: 0)).fraction == 1)
    }

    @Test func aRateLimitPauseCountsDownAndWinsOverTheYear() {
        let paused = SyncStatus(
            state: .running, phase: .rateLimited, total: 120, processed: 40,
            processingDate: APICoding.parseDate("2021-03-14T09:30:00Z"),
            rateLimitResetAt: APICoding.parseDate("2026-10-24T11:04:05.400Z")
        )
        #expect(progress(paused).detail == .rateLimited(secondsLeft: 245))
        #expect(FirstSyncProgress.countdown(245) == "4:05")

        var late = paused
        late.rateLimitResetAt = APICoding.parseDate("2026-10-24T10:59:00Z")
        #expect(progress(late).detail == .rateLimited(secondsLeft: 0))
    }

    @Test func doneAndErrorBothFinish() {
        #expect(progress(SyncStatus(state: .done, total: 3, processed: 3)).isFinished)
        #expect(progress(SyncStatus(state: .error, phase: .rateLimited)).isFinished)
        #expect(!progress(SyncStatus(state: .running, phase: .processing, total: 3)).isFinished)
    }
}
