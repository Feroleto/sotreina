import Foundation
import Testing
@testable import SoTreinaKit

/// Corrida › detalhe: the `GET /activities/:id` decode, `polyline.ts` and
/// the detail's parts of `activityFormat.ts` (`lapLabels` with the web's tests).
private func fixture(_ name: String) throws -> ActivityDetail {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try APICoding.makeDecoder().decode(ActivityDetail.self, from: Data(contentsOf: url))
}

private func lap(_ id: String, _ type: String = "STEADY", distanceM: Double = 1000, pace: Double = 300) -> ActivityLap {
    ActivityLap(id: id, lapIndex: 0, lapType: type, movingDurationSec: 300, distanceM: distanceM, avgPaceSecKm: pace)
}

@Suite struct ActivityDetailDecodingTests {
    @Test func decodesAGpsIntervalRun() throws {
        let a = try fixture("activity-detail")
        #expect(a.name == "Afternoon Run")
        #expect(a.workoutType == "INTERVAL")
        #expect(a.stravaId == "19602653359")
        #expect(a.stravaURL.absoluteString == "https://www.strava.com/activities/19602653359")
        #expect(a.laps.count == 16)
        #expect(a.laps[0].lapType == "WARMUP")
        #expect(a.laps[0].maxHr == 140)
        #expect(a.laps[0].elevGainM == -11.7)
        let route = try #require(a.route)
        #expect(route.count > 100)
        // same first point and bounding box as decoding it in Python
        #expect(route[0] == LatLng(lat: -29.77391, lng: -51.13129))
        #expect(route.map(\.lat).min() == -29.78383 && route.map(\.lat).max() == -29.76933)
        #expect(route.map(\.lng).min() == -51.14385 && route.map(\.lng).max() == -51.12716)
    }

    @Test func aTreadmillRunHasNoRoute() throws {
        let a = try fixture("activity-detail-treadmill")
        #expect(a.summaryPolyline == nil)
        #expect(a.route == nil)
        #expect(a.laps.count == 9)
    }
}

@Suite struct PolylineTests {
    @Test func decodesGooglesReferenceExample() {
        let points = Polyline.decode("_p~iF~ps|U_ulLnnqC_mqNvxq`@")
        #expect(points == [
            LatLng(lat: 38.5, lng: -120.2),
            LatLng(lat: 40.7, lng: -120.95),
            LatLng(lat: 43.252, lng: -126.453),
        ])
    }

    @Test func emptyAndTruncatedStrings() {
        #expect(Polyline.decode("").isEmpty)
        // the second point lost its longitude: only the first survives
        #expect(Polyline.decode("_p~iF~ps|U_ulL") == [LatLng(lat: 38.5, lng: -120.2)])
    }

    @Test func aSinglePointIsNoRoute() throws {
        var a = try fixture("activity-detail")
        a.summaryPolyline = "_p~iF~ps|U"
        #expect(a.route == nil)
        a.summaryPolyline = ""
        #expect(a.route == nil)
    }
}

@Suite struct LapLabelsTests {
    private func keys(_ laps: [ActivityLap]) -> [String] {
        RunFormat.lapLabels(laps).map { label in label.number.map { "\(label.key) \($0)" } ?? label.key }
    }

    @Test func kmAlignedSteadyLapsAllowAPartialLastSplit() {
        let laps = [lap("1", distanceM: 1005), lap("2", distanceM: 998), lap("3", distanceM: 300)]
        #expect(keys(laps) == ["activity.lapType.steady 1", "activity.lapType.steady 2", "activity.lapType.steady 3"])
    }

    @Test func steadyLapsNotKmAlignedFallBackToTheGenericLabel() {
        let laps = [lap("1", distanceM: 1500), lap("2", distanceM: 1500), lap("3"), lap("4")]
        #expect(keys(laps) == ["activity.lapType.run 1", "activity.lapType.run 2", "activity.lapType.run 3", "activity.lapType.run 4"])
    }

    @Test func aSingleSteadyLapKeepsTheBareLabel() {
        #expect(keys([lap("1", distanceM: 350)]) == ["activity.lapType.steady"])
    }

    @Test func otherLapTypesAreNumberedPerType() {
        let laps = [lap("1", "WARMUP", distanceM: 800), lap("2", "WORKOUT", distanceM: 400), lap("3", "REST", distanceM: 200), lap("4", "WORKOUT", distanceM: 400)]
        #expect(keys(laps) == ["activity.lapType.warmup", "activity.lapType.workout 1", "activity.lapType.rest", "activity.lapType.workout 2"])
    }

    @Test func anUnknownTypeShowsItself() {
        #expect(keys([lap("1", "SPRINT")]) == ["SPRINT"])
    }
}

@Suite struct ActivityDetailFormatTests {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return c
    }()

    @Test func minSecRollsOverAtSixty() {
        #expect(RunFormat.minSec(272) == "4:32")
        #expect(RunFormat.minSec(59.6) == "1:00")
        #expect(RunFormat.minSec(65) == "1:05")
    }

    @Test func lapDistanceHasTwoDecimalsInTheUnit() {
        #expect(RunFormat.lapDistance(1000, unit: .km, lang: .pt) == "1,00")
        #expect(RunFormat.lapDistance(965, unit: .km, lang: .en) == "0.96")
        #expect(RunFormat.lapDistance(1609.344, unit: .mi, lang: .en) == "1.00")
    }

    @Test func fullDateLikeTheWeb() throws {
        let a = try fixture("activity-detail") // 2026-08-04T18:48:57Z, a Tuesday
        #expect(RunFormat.dateFull(a.startDate, lang: .pt, calendar: calendar) == "Terça-feira, 04 de agosto · 15:48")
        #expect(RunFormat.dateFull(a.startDate, lang: .en, calendar: calendar) == "Tuesday, August 04 · 03:48 PM")
        let midnight = calendar.date(from: DateComponents(year: 2026, month: 1, day: 4, hour: 0, minute: 5))!
        #expect(RunFormat.dateFull(midnight, lang: .en, calendar: calendar) == "Sunday, January 04 · 12:05 AM")
    }

    @Test func fastestLapIgnoresLapsWithoutPace() {
        var a = ActivityDetailFixture.empty
        a.laps = [lap("1", pace: 300), lap("2", pace: 0), lap("3", pace: 280)]
        #expect(a.fastestLapPace == 280)
        a.laps = [lap("1", pace: 0)]
        #expect(a.fastestLapPace == nil)
    }

    @Test func workoutTypeKeys() {
        #expect(RunFormat.workoutTypeKey("INTERVAL") == "common.workout.interval")
        #expect(RunFormat.workoutTypeKey("EASY_OR_LONG") == "common.workout.easyLong")
        #expect(RunFormat.workoutTypeKey("HILL_REPEATS") == "common.workout.hillRepeats")
        #expect(RunFormat.workoutTypeKey("OTHER") == nil)
    }
}

private enum ActivityDetailFixture {
    static let empty = ActivityDetail(
        id: "a", stravaId: "1", name: "Run", type: "Run", workoutType: "EASY_OR_LONG", startDate: .now,
        distanceKm: nil, movingTimeSec: 0, paceRawSecKm: nil, elevationGainM: nil, averageBpm: nil,
        maxBpm: nil, averageCadence: nil, summaryPolyline: nil, laps: []
    )
}
