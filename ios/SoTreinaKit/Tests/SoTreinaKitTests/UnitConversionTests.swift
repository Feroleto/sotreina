import Foundation
import Testing
@testable import SoTreinaKit

// Mirrors client/src/lib/units.test.ts — the web and the app must show the
// same number for the same stored value.
@Suite struct UnitConversionTests {
    @Test func distanceIsTheIdentityInKm() {
        #expect(UnitConversion.display(km: 10, in: .km) == 10)
        #expect(UnitConversion.km(fromDisplay: 10, in: .km) == 10)
    }

    @Test func marathonInMiles() {
        let mi = UnitConversion.display(km: 42.195, in: .mi)
        #expect(abs(mi - 26.2188) < 0.0001)
    }

    @Test func distanceRoundTrips() {
        let back = UnitConversion.km(fromDisplay: UnitConversion.display(km: 21.0975, in: .mi), in: .mi)
        #expect(abs(back - 21.0975) < 1e-10)
    }

    @Test func paceIsSlowerPerMile() {
        // 5:00/km ≈ 8:03/mi
        #expect(abs(UnitConversion.pace(secondsPerKm: 300, in: .mi) - 482.8) < 0.1)
        #expect(UnitConversion.pace(secondsPerKm: 300, in: .km) == 300)
    }

    @Test func everyWholeMileGoalSurvivesWholeKm() {
        for mi in 1...186 {
            let km = UnitConversion.goalKm(fromDisplay: mi, in: .mi)
            #expect(UnitConversion.goalDisplay(km: km, in: .mi) == mi)
        }
        #expect(UnitConversion.goalKm(fromDisplay: 10, in: .mi) == 16)
        #expect(UnitConversion.goalDisplay(km: 20, in: .km) == 20)
    }

    /// The spec's example: 45 lb is stored as 20.41 kg and reads back as 45.
    @Test func fortyFivePoundsRoundTripsThroughTheKgColumn() {
        let stored = UnitConversion.kg(fromDisplay: 45, in: .lb)
        #expect(stored == 20.41)
        #expect(UnitConversion.display(kg: stored, in: .lb) == 45)
    }

    @Test(arguments: [5.0, 10, 25, 35, 45, 95, 135, 225, 315, 405])
    func commonPlatesRoundTrip(lb: Double) {
        #expect(UnitConversion.display(kg: UnitConversion.kg(fromDisplay: lb, in: .lb), in: .lb) == lb)
    }

    @Test func kgKeepsTwoDecimals() {
        #expect(UnitConversion.kg(fromDisplay: 22.5, in: .kg) == 22.5)
        #expect(UnitConversion.kg(fromDisplay: 22.555, in: .kg) == 22.56)
        #expect(UnitConversion.display(kg: 20.41, in: .kg) == 20.41)
    }

    @Test func stepsAreTwoAndAHalfKgOrFivePounds() {
        #expect(UnitConversion.stepped(kg: 20, direction: 1, in: .kg) == 22.5)
        #expect(UnitConversion.stepped(kg: 20, direction: -1, in: .kg) == 17.5)
        // 45 lb + one tap lands exactly on 50 lb, not 50.0x
        let fifty = UnitConversion.stepped(kg: 20.41, direction: 1, in: .lb)
        #expect(UnitConversion.display(kg: fifty, in: .lb) == 50)
        #expect(UnitConversion.stepped(kg: 1, direction: -1, in: .kg) == 0)
        #expect(UnitConversion.stepped(kg: 0, direction: -1, in: .lb) == 0)
    }

    @Test func volumeInTonnesOrThousandsOfPounds() {
        #expect(abs(UnitConversion.volumeThousands(kg: 12_345, in: .kg) - 12.345) < 1e-9)
        #expect(abs(UnitConversion.volumeThousands(kg: 1000, in: .lb) - 2.2046) < 0.0001)
        #expect(UnitConversion.volumeLabel(.kg) == "t")
        #expect(UnitConversion.volumeLabel(.lb) == "k lb")
    }

    @Test func meDecodesTheUnitsAndFallsBackWithoutThem() throws {
        let withUnits = #"{"id":"u1","hasStravaAccount":false,"hasPassword":true,"distanceUnit":"MI","weightUnit":"LB"}"#
        let me = try JSONDecoder().decode(Me.self, from: Data(withUnits.utf8))
        #expect(me.distanceUnit == .mi)
        #expect(me.weightUnit == .lb)

        // an older backend (or a cached response) without the fields
        let without = #"{"id":"u1","hasStravaAccount":false,"hasPassword":true}"#
        let old = try JSONDecoder().decode(Me.self, from: Data(without.utf8))
        #expect(old.distanceUnit == .km)
        #expect(old.weightUnit == .kg)
    }
}
