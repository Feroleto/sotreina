import Testing
@testable import SoTreinaKit

@Suite struct WorkoutFormatTests {
    @Test(arguments: [(0, "0:00"), (65, "1:05"), (725, "12:05"), (3725, "1:02:05"), (-3, "0:00")])
    func elapsedClock(seconds: Int, expected: String) {
        #expect(WorkoutFormat.elapsed(seconds) == expected)
    }

    @Test(arguments: [(20.0, "20"), (22.5, "22,5"), (1.25, "1,25"), (80.004, "80"), (0.0, "0")])
    func weightUsesCommaAndDropsTrailingZero(kg: Double, expected: String) {
        #expect(WorkoutFormat.weight(kg, lang: .pt) == expected)
    }

    @Test func setLine() {
        #expect(WorkoutFormat.set(weightKg: 22.5, reps: 8) == "22,5 kg × 8")
        #expect(WorkoutFormat.set(weightKg: nil, reps: 12) == "× 12")
        #expect(WorkoutFormat.set(weightKg: 40, reps: nil) == "40 kg")
        #expect(WorkoutFormat.set(weightKg: nil, reps: nil) == "—")
    }

    @Test(arguments: [(57, "1min"), (0, "0min"), (3120, "52min"), (3900, "1h05"), (7260, "2h01")])
    func durationShortMatchesTheWeb(seconds: Int, expected: String) {
        #expect(WorkoutFormat.durationShort(seconds) == expected)
    }

    @Test func weightInPounds() {
        // 45 lb is stored as 20.41 kg and has to read back as 45
        #expect(WorkoutFormat.weight(20.41, unit: .lb, lang: .pt) == "45")
        #expect(WorkoutFormat.weight(20, unit: .lb, lang: .pt) == "44,1")
        #expect(WorkoutFormat.weight(20, unit: .lb, lang: .en) == "44.1")
        #expect(WorkoutFormat.weight(22.5, unit: .kg, lang: .en) == "22.5")
    }

    @Test func setLineInPounds() {
        #expect(WorkoutFormat.set(weightKg: 20.41, reps: 5, unit: .lb) == "45 lb × 5")
        #expect(WorkoutFormat.set(weightKg: 20.41, reps: nil, unit: .lb, lang: .en) == "45 lb")
        #expect(WorkoutFormat.set(weightKg: nil, reps: 12, unit: .lb) == "× 12")
    }

    /// Same as the web's `formatVolume` + `volumeLabel`: thousands of the
    /// display unit, always one decimal
    @Test func volumeInThousandsLikeTheWeb() {
        #expect(WorkoutFormat.volume(1820, unit: .kg, lang: .pt) == "1,8 t")
        #expect(WorkoutFormat.volume(1820, unit: .kg, lang: .en) == "1.8 t")
        #expect(WorkoutFormat.volume(0, unit: .kg, lang: .pt) == "0,0 t")
        #expect(WorkoutFormat.volume(12345.5, unit: .kg, lang: .en) == "12.3 t")
        // 1814.37 kg = 4000 lb
        #expect(WorkoutFormat.volume(1814.37, unit: .lb, lang: .en) == "4.0 k lb")
    }

    @Test func targetLine() {
        #expect(WorkoutFormat.target(sets: 3, repsMin: 12, repsMax: 12) == "3 × 12")
        #expect(WorkoutFormat.target(sets: 2, repsMin: 5, repsMax: 9) == "2 × 5–9")
        #expect(WorkoutFormat.target(sets: 3, repsMin: nil, repsMax: nil) == "3 séries")
        #expect(WorkoutFormat.target(sets: 1, repsMin: nil, repsMax: nil) == "1 série")
        #expect(WorkoutFormat.target(sets: nil, repsMin: 8, repsMax: nil) == "8+ reps")
        #expect(WorkoutFormat.target(nil) == nil)
        #expect(WorkoutFormat.target(ExerciseTarget(sets: nil, repsMin: nil, repsMax: nil)) == nil)
    }
}
