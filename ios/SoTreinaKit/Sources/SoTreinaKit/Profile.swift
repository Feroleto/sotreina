import Foundation

/// `GET`/`PATCH /users/me` — mirror of `MeSnapshot` in
/// server/src/users/users.service.ts: the goals and preferences behind
/// Perfil. Not `Me` (`/auth/me`), which carries identity and is what the
/// rest of the app reads; `Me.applying(_:)` copies the overlap back.
public struct MeSettings: Codable, Equatable, Sendable {
    public var maxHr: Int?
    public var dailyKcalGoal: Int
    public var dailyProteinGoal: Int
    public var dailyCarbsGoal: Int
    public var dailyFatGoal: Int
    public var weeklyRunKmGoal: Int
    public var weeklyWorkoutsGoal: Int
    public var firstName: String?
    public var enabledAreas: [Area]
    public var distanceUnit: DistanceUnit
    public var weightUnit: WeightUnit

    public init(
        maxHr: Int? = nil,
        dailyKcalGoal: Int = 2000,
        dailyProteinGoal: Int = 150,
        dailyCarbsGoal: Int = 250,
        dailyFatGoal: Int = 65,
        weeklyRunKmGoal: Int = 20,
        weeklyWorkoutsGoal: Int = 3,
        firstName: String? = nil,
        enabledAreas: [Area] = [],
        distanceUnit: DistanceUnit = .km,
        weightUnit: WeightUnit = .kg
    ) {
        self.maxHr = maxHr
        self.dailyKcalGoal = dailyKcalGoal
        self.dailyProteinGoal = dailyProteinGoal
        self.dailyCarbsGoal = dailyCarbsGoal
        self.dailyFatGoal = dailyFatGoal
        self.weeklyRunKmGoal = weeklyRunKmGoal
        self.weeklyWorkoutsGoal = weeklyWorkoutsGoal
        self.firstName = firstName
        self.enabledAreas = enabledAreas
        self.distanceUnit = distanceUnit
        self.weightUnit = weightUnit
    }

    // same tolerance as `Me`: an area value this build doesn't know is skipped
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        maxHr = try c.decodeIfPresent(Int.self, forKey: .maxHr)
        dailyKcalGoal = try c.decode(Int.self, forKey: .dailyKcalGoal)
        dailyProteinGoal = try c.decode(Int.self, forKey: .dailyProteinGoal)
        dailyCarbsGoal = try c.decode(Int.self, forKey: .dailyCarbsGoal)
        dailyFatGoal = try c.decode(Int.self, forKey: .dailyFatGoal)
        weeklyRunKmGoal = try c.decode(Int.self, forKey: .weeklyRunKmGoal)
        weeklyWorkoutsGoal = try c.decode(Int.self, forKey: .weeklyWorkoutsGoal)
        firstName = try c.decodeIfPresent(String.self, forKey: .firstName)
        let rawAreas = try c.decodeIfPresent([String].self, forKey: .enabledAreas) ?? []
        enabledAreas = rawAreas.compactMap(Area.init(rawValue:))
        distanceUnit = try c.decodeIfPresent(DistanceUnit.self, forKey: .distanceUnit) ?? .km
        weightUnit = try c.decodeIfPresent(WeightUnit.self, forKey: .weightUnit) ?? .kg
    }
}

/// `PATCH /users/me` with any subset of its fields: a `nil` is left out of
/// the body, so the server doesn't touch it. The response is `MeSettings`.
public struct MeSettingsPatch: Codable, Equatable, Sendable {
    public var dailyKcalGoal: Int?
    public var dailyProteinGoal: Int?
    public var dailyCarbsGoal: Int?
    public var dailyFatGoal: Int?
    public var weeklyRunKmGoal: Int?
    public var weeklyWorkoutsGoal: Int?
    public var firstName: String?
    public var enabledAreas: [Area]?
    public var distanceUnit: DistanceUnit?
    public var weightUnit: WeightUnit?

    public init(
        dailyKcalGoal: Int? = nil,
        dailyProteinGoal: Int? = nil,
        dailyCarbsGoal: Int? = nil,
        dailyFatGoal: Int? = nil,
        weeklyRunKmGoal: Int? = nil,
        weeklyWorkoutsGoal: Int? = nil,
        firstName: String? = nil,
        enabledAreas: [Area]? = nil,
        distanceUnit: DistanceUnit? = nil,
        weightUnit: WeightUnit? = nil
    ) {
        self.dailyKcalGoal = dailyKcalGoal
        self.dailyProteinGoal = dailyProteinGoal
        self.dailyCarbsGoal = dailyCarbsGoal
        self.dailyFatGoal = dailyFatGoal
        self.weeklyRunKmGoal = weeklyRunKmGoal
        self.weeklyWorkoutsGoal = weeklyWorkoutsGoal
        self.firstName = firstName
        self.enabledAreas = enabledAreas
        self.distanceUnit = distanceUnit
        self.weightUnit = weightUnit
    }

    /// The same fields applied locally — the optimistic state before the
    /// server answers.
    public func applied(to settings: MeSettings) -> MeSettings {
        var next = settings
        if let dailyKcalGoal { next.dailyKcalGoal = dailyKcalGoal }
        if let dailyProteinGoal { next.dailyProteinGoal = dailyProteinGoal }
        if let dailyCarbsGoal { next.dailyCarbsGoal = dailyCarbsGoal }
        if let dailyFatGoal { next.dailyFatGoal = dailyFatGoal }
        if let weeklyRunKmGoal { next.weeklyRunKmGoal = weeklyRunKmGoal }
        if let weeklyWorkoutsGoal { next.weeklyWorkoutsGoal = weeklyWorkoutsGoal }
        if let firstName { next.firstName = firstName }
        if let enabledAreas { next.enabledAreas = enabledAreas }
        if let distanceUnit { next.distanceUnit = distanceUnit }
        if let weightUnit { next.weightUnit = weightUnit }
        return next
    }
}

extension Me {
    /// The fields `/users/me` shares with `/auth/me`, from a settings snapshot.
    public func applying(_ settings: MeSettings) -> Me {
        var next = self
        next.firstName = settings.firstName
        next.enabledAreas = settings.enabledAreas
        next.distanceUnit = settings.distanceUnit
        next.weightUnit = settings.weightUnit
        return next
    }
}

/// Rules of Perfil, ported from client/src/features/profile/ProfilePage.tsx,
/// EditNamePage.tsx, today/WeeklyGoalsPage.tsx and diet/GoalPage.tsx.
public enum ProfileRules {
    // MARK: Name

    /// server/src/auth/dto.ts `parseFirstName`
    public static let maxNameLength = 60

    /// The trimmed name to send, or nil when there's nothing to save (blank,
    /// or the same as now).
    public static func nameToSave(_ typed: String, current: String?) -> String? {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != (current ?? "") else { return nil }
        return trimmed
    }

    /// The avatar's two letters, "—" without a name (no photo in the app).
    public static func initials(_ firstName: String?) -> String {
        guard let name = firstName, !name.isEmpty else { return "—" }
        return String(name.prefix(2)).uppercased()
    }

    // MARK: Areas

    /// The areas after flipping one, in the server's order; nil when it would
    /// turn off the last one (none is the "not chosen yet" state).
    public static func toggling(_ area: Area, in current: [Area]) -> [Area]? {
        var set = Set(current)
        if set.contains(area) { set.remove(area) } else { set.insert(area) }
        guard !set.isEmpty else { return nil }
        return Area.allCases.filter(set.contains)
    }

    /// The switch can't turn off the only area left.
    public static func isLocked(_ area: Area, in current: [Area]) -> Bool {
        current == [area]
    }

    /// Goal rows of the enabled areas, in the web's order.
    public static func goalAreas(_ enabled: [Area]) -> [Area] {
        Area.allCases.filter(enabled.contains)
    }

    // MARK: Weekly goals (server/src/users/dto.ts ranges)

    public static let runKmRange = 1...300
    public static let workoutsRange = 1...14

    /// The run stepper's range in whole display units.
    public static func runGoalRange(_ unit: DistanceUnit) -> ClosedRange<Int> {
        runKmRange.lowerBound...UnitConversion.goalDisplay(km: runKmRange.upperBound, in: unit)
    }

    /// What goes into `weeklyRunKmGoal`: untouched, the stored km as-is, so
    /// a round trip through miles never nudges a goal nobody edited.
    public static func runKmToSave(display: Int, storedKm: Int, unit: DistanceUnit) -> Int {
        display == UnitConversion.goalDisplay(km: storedKm, in: unit)
            ? storedKm
            : UnitConversion.goalKm(fromDisplay: display, in: unit)
    }

    // MARK: Daily diet goal (GoalPage)

    public static let kcalStep = 50
    public static let kcalRange = 800...6000
    public static let macroStep = 5
    public static let macroRange = 0...500
    public static let matchTolerancePct = 3

    /// "N% das calorias" under a macro stepper.
    public static func pctOfCalories(grams: Int, kcalPerGram: Int, kcalGoal: Int) -> Int {
        guard kcalGoal > 0 else { return 0 }
        return Int((Double(grams * kcalPerGram) / Double(kcalGoal) * 100).rounded())
    }

    public enum MacroMatch: Equatable, Sendable {
        case matches
        case above(pct: Int)
        case below(pct: Int)
    }

    /// The macros' kcal (p×4 + c×4 + g×9) against the kcal goal, ≤ 3% apart
    /// counting as a match.
    public static func calculatedKcal(protein: Int, carbs: Int, fat: Int) -> Int {
        protein * 4 + carbs * 4 + fat * 9
    }

    public static func macroMatch(kcalGoal: Int, protein: Int, carbs: Int, fat: Int) -> MacroMatch {
        let calculated = calculatedKcal(protein: protein, carbs: carbs, fat: fat)
        let diffPct = kcalGoal > 0
            ? Int((Double(abs(calculated - kcalGoal)) / Double(kcalGoal) * 100).rounded())
            : 0
        if diffPct <= matchTolerancePct { return .matches }
        return calculated > kcalGoal ? .above(pct: diffPct) : .below(pct: diffPct)
    }
}
