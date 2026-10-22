import Testing
@testable import SoTreinaKit

@Suite struct WorkoutFormatTests {
    @Test(arguments: [(0, "0:00"), (65, "1:05"), (725, "12:05"), (3725, "1:02:05"), (-3, "0:00")])
    func elapsedClock(seconds: Int, expected: String) {
        #expect(WorkoutFormat.elapsed(seconds) == expected)
    }

    @Test(arguments: [(20.0, "20"), (22.5, "22,5"), (1.25, "1,25"), (80.004, "80"), (0.0, "0")])
    func weightUsesCommaAndDropsTrailingZero(kg: Double, expected: String) {
        #expect(WorkoutFormat.weight(kg) == expected)
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

    @Test(arguments: [(0.0, "0"), (950.0, "950"), (1820.0, "1.820"), (12345.5, "12.345,5"), (1_234_567.04, "1.234.567")])
    func volumeGroupsThousands(kg: Double, expected: String) {
        #expect(WorkoutFormat.volume(kg) == expected)
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
