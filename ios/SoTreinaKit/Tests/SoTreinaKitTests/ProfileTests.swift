import Foundation
import Testing
@testable import SoTreinaKit

@Suite struct ProfileTests {
    // users-me.json is derived by hand from MeSnapshot (server/src/users/
    // users.service.ts), with an unknown area added on purpose
    @Test func settingsDecodeSkippingAnUnknownArea() throws {
        let url = try #require(Bundle.module.url(forResource: "users-me", withExtension: "json", subdirectory: "Fixtures"))
        let settings = try APICoding.makeDecoder().decode(MeSettings.self, from: Data(contentsOf: url))
        #expect(settings.dailyKcalGoal == 2200)
        #expect(settings.weeklyRunKmGoal == 25)
        #expect(settings.enabledAreas == [.run, .gym])
        #expect(settings.distanceUnit == .mi)
        #expect(settings.maxHr == nil)
    }

    @Test func aPatchSendsOnlyItsFields() throws {
        let json = try String(decoding: JSONEncoder().encode(MeSettingsPatch(weightUnit: .lb)), as: UTF8.self)
        #expect(json == #"{"weightUnit":"LB"}"#)
    }

    @Test func aPatchAppliesLocallyAndCopiesBackToMe() {
        let settings = MeSettingsPatch(firstName: "Bia", enabledAreas: [.diet], distanceUnit: .mi)
            .applied(to: MeSettings(firstName: "Ana", enabledAreas: [.run, .diet]))
        #expect(settings.firstName == "Bia")
        #expect(settings.enabledAreas == [.diet])
        #expect(settings.dailyKcalGoal == 2000)
        let me = Me(id: "u1", firstName: "Ana", hasStravaAccount: true, enabledAreas: [.run]).applying(settings)
        #expect(me.firstName == "Bia")
        #expect(me.enabledAreas == [.diet])
        #expect(me.distanceUnit == .mi)
        #expect(me.hasStravaAccount)
    }

    @Test func theNameIsTrimmedAndOnlySavedWhenChanged() {
        #expect(ProfileRules.nameToSave("  Bia ", current: "Ana") == "Bia")
        #expect(ProfileRules.nameToSave("Ana ", current: "Ana") == nil)
        #expect(ProfileRules.nameToSave("   ", current: nil) == nil)
        #expect(ProfileRules.nameToSave("Ana", current: nil) == "Ana")
    }

    @Test func initialsAreTwoUppercaseLetters() {
        #expect(ProfileRules.initials("ana") == "AN")
        #expect(ProfileRules.initials(nil) == "—")
        #expect(ProfileRules.initials("") == "—")
    }

    @Test func theLastAreaCantBeTurnedOff() {
        #expect(ProfileRules.toggling(.gym, in: [.gym]) == nil)
        #expect(ProfileRules.isLocked(.gym, in: [.gym]))
        #expect(!ProfileRules.isLocked(.gym, in: [.gym, .diet]))
        #expect(!ProfileRules.isLocked(.run, in: [.gym]))
        #expect(ProfileRules.toggling(.gym, in: [.run, .gym]) == [.run])
        // turning one on lands it in the server's order
        #expect(ProfileRules.toggling(.run, in: [.diet]) == [.run, .diet])
    }

    @Test func runGoalRangeAndSaveFollowTheUnit() {
        #expect(ProfileRules.runGoalRange(.km) == 1...300)
        #expect(ProfileRules.runGoalRange(.mi) == 1...186)
        // 25 km shows as 16 mi; untouched it goes back as 25, not 26
        #expect(ProfileRules.runKmToSave(display: 16, storedKm: 25, unit: .mi) == 25)
        #expect(ProfileRules.runKmToSave(display: 17, storedKm: 25, unit: .mi) == 27)
        #expect(ProfileRules.runKmToSave(display: 30, storedKm: 25, unit: .km) == 30)
    }

    @Test func macroPercentagesAndMatchMirrorGoalPage() {
        #expect(ProfileRules.pctOfCalories(grams: 150, kcalPerGram: 4, kcalGoal: 2000) == 30)
        #expect(ProfileRules.pctOfCalories(grams: 65, kcalPerGram: 9, kcalGoal: 0) == 0)
        // defaults: 150×4 + 250×4 + 65×9 = 2185 kcal, 9% above 2000
        #expect(ProfileRules.calculatedKcal(protein: 150, carbs: 250, fat: 65) == 2185)
        #expect(ProfileRules.macroMatch(kcalGoal: 2000, protein: 150, carbs: 250, fat: 65) == .above(pct: 9))
        #expect(ProfileRules.macroMatch(kcalGoal: 2185, protein: 150, carbs: 250, fat: 65) == .matches)
        // 3% apart still matches, 4% doesn't
        #expect(ProfileRules.macroMatch(kcalGoal: 2250, protein: 150, carbs: 250, fat: 65) == .matches)
        #expect(ProfileRules.macroMatch(kcalGoal: 2280, protein: 150, carbs: 250, fat: 65) == .below(pct: 4))
    }
}
