import Foundation
import Testing
@testable import SoTreinaKit

@Suite struct LangTests {
    @Test(arguments: [
        (["pt-BR", "en-US"], Lang.pt),
        (["pt-PT"], .pt),
        (["PT"], .pt),
        (["en-GB", "pt-BR"], .en),
        (["es-ES"], .en),
        ([], .en),
    ])
    func autoFollowsTheFirstPreferredLanguage(preferred: [String], expected: Lang) {
        #expect(Lang.resolve(preferredLanguages: preferred) == expected)
        #expect(AppLanguage.auto.resolved(preferredLanguages: preferred) == expected)
    }

    @Test func anExplicitChoiceWinsOverTheIPhone() {
        #expect(AppLanguage.en.resolved(preferredLanguages: ["pt-BR"]) == .en)
        #expect(AppLanguage.pt.resolved(preferredLanguages: ["en-US"]) == .pt)
    }

    @Test func headersAndLocales() {
        #expect(Lang.pt.acceptLanguage == "pt")
        #expect(Lang.en.acceptLanguage == "en")
        #expect(Lang.pt.localeIdentifier == "pt_BR")
    }
}

@Suite struct EnglishFormatTests {
    private let now = Date(timeIntervalSince1970: 1_792_000_000)

    @Test(arguments: [(0.5, "today"), (1.2, "yesterday"), (1, "yesterday"), (3, "3 days ago"), (7, "1 week ago"),
                      (100, "3 months ago"), (365, "1 year ago")])
    func lastPerformedInEnglish(days: Double, expected: String) {
        #expect(RoutineFormat.lastPerformed(now.addingTimeInterval(-days * 86_400), now: now, lang: .en) == expected)
    }

    @Test func neverPerformedAndMusclesInEnglish() {
        #expect(RoutineFormat.lastPerformed(nil, now: now, lang: .en) == "not done yet")
        #expect(MuscleGroup.label("ABDOMINALS", lang: .en) == "Abs")
        #expect(MuscleGroup.label("ABDOMINALS") == "Abdômen")
        #expect(MuscleGroup.label("NEW_GROUP", lang: .en) == "NEW_GROUP")
    }

    @Test func targetsInEnglish() {
        #expect(WorkoutFormat.target(sets: 3, repsMin: nil, repsMax: nil, lang: .en) == "3 sets")
        #expect(WorkoutFormat.target(sets: 1, repsMin: nil, repsMax: nil, lang: .en) == "1 set")
        #expect(WorkoutFormat.target(sets: nil, repsMin: nil, repsMax: 10, lang: .en) == "up to 10 reps")
        #expect(WorkoutFormat.target(sets: 2, repsMin: 5, repsMax: 9, lang: .en) == "2 × 5–9")
    }

    @Test func numbersInEnglishUseDotDecimals() {
        #expect(WorkoutFormat.weight(22.5, lang: .en) == "22.5")
        #expect(WorkoutFormat.weight(20, lang: .en) == "20")
        #expect(WorkoutFormat.set(weightKg: 22.5, reps: 8, lang: .en) == "22.5 kg × 8")
        #expect(WorkoutFormat.volume(12_345.5, lang: .en) == "12.3 t")
        #expect(WorkoutFormat.volume(1820) == "1,8 t")
    }

    @Test func expiryBannerInEnglish() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        func date(_ day: Int, _ hour: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
        }
        #expect(AppExpiry.banner(expiration: date(29, 16), now: date(27, 17), calendar: calendar, lang: .en)
            == "The app expires on Thursday. Run ios/scripts/deploy.sh.")
        #expect(AppExpiry.banner(expiration: date(29, 16), now: date(28, 9), calendar: calendar, lang: .en)
            == "The app expires tomorrow at 16:00. Run ios/scripts/deploy.sh.")
        #expect(AppExpiry.banner(expiration: date(29, 16), now: date(29, 17), calendar: calendar, lang: .en)
            == "The app has expired. Run ios/scripts/deploy.sh.")
    }

    @Test func liveActivitySetLabelFollowsItsLang() {
        let snapshot = WorkoutActivitySnapshot(
            exerciseName: "Bench", workoutExerciseId: "we1", setNumber: 2, targetSets: 3,
            restEndsAt: nil, restDuration: nil, proposal: nil, hasFailedSet: false, logSetURL: nil, lang: .en
        )
        #expect(snapshot.setLabel == "Set 2 of 3")
        var legacy = snapshot
        legacy.lang = nil
        #expect(legacy.setLabel == "Série 2 de 3")
    }

    @Test func aSnapshotSavedWithoutLangStillDecodes() throws {
        let json = Data(#"{"setNumber":1,"hasFailedSet":false}"#.utf8)
        let snapshot = try JSONDecoder().decode(WorkoutActivitySnapshot.self, from: json)
        #expect(snapshot.lang == nil)
        #expect(snapshot.weightUnit == nil)
        #expect(snapshot.setLabel == "Série 1")
    }
}
