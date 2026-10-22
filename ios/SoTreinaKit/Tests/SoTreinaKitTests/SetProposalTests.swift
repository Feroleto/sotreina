import Foundation
import Testing
@testable import SoTreinaKit

@Suite struct SetProposalTests {
    private func last(_ sets: [(Double?, Int?)]) -> LastPerformance {
        LastPerformance(
            workoutId: "w0",
            startedAt: Date(timeIntervalSince1970: 0),
            sets: sets.enumerated().map { index, values in
                LastPerformanceSet(
                    id: "s\(index)", setNumber: index + 1, weightKg: values.0,
                    reps: values.1, rpe: nil, setType: "WORKING"
                )
            }
        )
    }

    @Test func sameSetNumberFromLastTimeWins() {
        let proposal = SetProposal.propose(
            setNumber: 2,
            lastPerformance: last([(20, 8), (22.5, 6)]),
            previousInWorkout: (25, 5)
        )
        #expect(proposal == SetProposal(weightKg: 22.5, reps: 6, source: .lastTime))
    }

    @Test func previousSetOfThisWorkoutWhenLastTimeHadFewerSets() {
        let proposal = SetProposal.propose(
            setNumber: 3,
            lastPerformance: last([(20, 8), (20, 8)]),
            previousInWorkout: (25, 5)
        )
        #expect(proposal == SetProposal(weightKg: 25, reps: 5, source: .previousSet))
    }

    @Test func lastTimesFinalSetWhenNothingElseFits() {
        // first set of a session whose lastPerformance only has an empty set 1
        let proposal = SetProposal.propose(
            setNumber: 1,
            lastPerformance: last([(nil, nil), (30, 10)]),
            previousInWorkout: nil
        )
        #expect(proposal == SetProposal(weightKg: 30, reps: 10, source: .lastTime))
    }

    @Test func nothingForANeverDoneExerciseWithoutSets() {
        #expect(SetProposal.propose(setNumber: 1, lastPerformance: nil, previousInWorkout: nil) == nil)
        #expect(SetProposal.propose(setNumber: 1, lastPerformance: nil, previousInWorkout: (nil, nil)) == nil)
    }

    @Test func bodyweightSetKeepsTheMissingWeight() {
        let proposal = SetProposal.propose(setNumber: 1, lastPerformance: last([(nil, 12)]), previousInWorkout: nil)
        #expect(proposal == SetProposal(weightKg: nil, reps: 12, source: .lastTime))
    }

    @Test func parsesTypedWeightAndReps() {
        #expect(SetInput.weight("22,5") == 22.5)
        #expect(SetInput.weight(" 80 ") == 80)
        #expect(SetInput.weight("") == nil)
        #expect(SetInput.weight("-5") == nil)
        #expect(SetInput.weight("abc") == nil)
        #expect(SetInput.reps("12") == 12)
        #expect(SetInput.reps("12,5") == nil)
        #expect(SetInput.reps("") == nil)
    }
}
