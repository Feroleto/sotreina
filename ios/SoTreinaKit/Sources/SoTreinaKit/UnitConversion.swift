import Foundation

/// `User.distanceUnit` — display/entry preference only: the API and the
/// database always speak km.
public enum DistanceUnit: String, Codable, Sendable, CaseIterable {
    case km = "KM"
    case mi = "MI"
}

/// `User.weightUnit` — display/entry preference only: the API and the
/// database always speak kg (`weightKg` is `Decimal(6,2)`).
public enum WeightUnit: String, Codable, Sendable, CaseIterable {
    case kg = "KG"
    case lb = "LB"
}

/// Port of `client/src/lib/units.ts`: conversion happens only at the edges,
/// when a number is shown and when one typed by the user is sent. Volume,
/// PRs and set proposals always compare in kg.
public enum UnitConversion {
    /// Exact by definition (international yard and pound, 1959).
    public static let kmPerMile = 1.609344
    public static let kgPerPound = 0.45359237

    // MARK: Distance

    public static func display(km: Double, in unit: DistanceUnit) -> Double {
        unit == .mi ? km / kmPerMile : km
    }

    public static func km(fromDisplay value: Double, in unit: DistanceUnit) -> Double {
        unit == .mi ? value * kmPerMile : value
    }

    /// "km" | "mi" — the same in pt and en.
    public static func label(_ unit: DistanceUnit) -> String {
        unit == .mi ? "mi" : "km"
    }

    /// Seconds per km → seconds per display unit (pace grows with the unit).
    public static func pace(secondsPerKm: Double, in unit: DistanceUnit) -> Double {
        unit == .mi ? secondsPerKm * kmPerMile : secondsPerKm
    }

    /// Weekly distance goals are whole km in the DB and whole units on
    /// screen. Any whole mile survives the trip: the km rounding error
    /// (≤ 0.5 km) is under half a mile.
    public static func goalDisplay(km: Int, in unit: DistanceUnit) -> Int {
        Int(display(km: Double(km), in: unit).rounded())
    }

    public static func goalKm(fromDisplay value: Int, in unit: DistanceUnit) -> Int {
        Int(km(fromDisplay: Double(value), in: unit).rounded())
    }

    // MARK: Weight

    /// A stored weight in the display unit. lb is shown to 0.1: 45 lb is
    /// stored as 20.41 kg, which reads back as 44.996 lb — one decimal is
    /// what lands the round trip on 45 again.
    public static func display(kg: Double, in unit: WeightUnit) -> Double {
        unit == .lb ? round(kg / kgPerPound, places: 1) : round(kg, places: 2)
    }

    /// A typed weight → what goes into `weightKg` (2 decimals, like the column).
    public static func kg(fromDisplay value: Double, in unit: WeightUnit) -> Double {
        round(unit == .lb ? value * kgPerPound : value, places: 2)
    }

    /// "kg" | "lb"
    public static func label(_ unit: WeightUnit) -> String {
        unit == .lb ? "lb" : "kg"
    }

    /// The weight stepper's increment, in the display unit.
    public static func step(_ unit: WeightUnit) -> Double {
        unit == .lb ? 5 : 2.5
    }

    /// One stepper tap (`direction` = +1 or -1) on a stored weight: the step
    /// is taken in the display unit, so 45 lb + 1 tap is exactly 50 lb, then
    /// stored back in kg. Never below zero.
    public static func stepped(kg: Double, direction: Int, in unit: WeightUnit) -> Double {
        let next = display(kg: kg, in: unit) + Double(direction.signum()) * step(unit)
        return Self.kg(fromDisplay: max(0, next), in: unit)
    }

    /// Training volume (Σ weight × reps) in thousands of the display unit,
    /// read together with `volumeLabel` ("t" | "k lb").
    public static func volumeThousands(kg: Double, in unit: WeightUnit) -> Double {
        (unit == .lb ? kg / kgPerPound : kg) / 1000
    }

    public static func volumeLabel(_ unit: WeightUnit) -> String {
        unit == .lb ? "k lb" : "t"
    }

    private static func round(_ value: Double, places: Int) -> Double {
        let factor = pow(10, Double(places))
        return (value * factor).rounded() / factor
    }
}
