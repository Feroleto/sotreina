import Foundation
import Testing
@testable import SoTreinaKit

// Plano da semana (.plans/plano-semanal-spec.md §6.1). The edge cases mirror
// server/test/plans/plan-rules.test.ts, so the app and the API refuse the same
// things.

private func fixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try APICoding.makeDecoder().decode(T.self, from: Data(contentsOf: url))
}

private let saoPaulo: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
    return calendar
}()

private func local(_ day: Int, hour: Int = 15, month: Int = 10) -> Date {
    saoPaulo.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
}

private func run(_ startDate: Date) -> ActivityListItem {
    ActivityListItem(
        id: "\(startDate.timeIntervalSince1970)", name: "Run", type: "Run", workoutType: "EASY_OR_LONG",
        startDate: startDate, distanceKm: 8, movingTimeSec: 2400, paceRawSecKm: nil,
        elevationGainM: nil, averageBpm: nil, maxBpm: nil, averageCadence: nil
    )
}

private func workout(_ startedAt: Date) -> WorkoutHistoryItem {
    WorkoutHistoryItem(
        id: "\(startedAt.timeIntervalSince1970)", startedAt: startedAt, finishedAt: startedAt,
        durationSec: 3600, exerciseCount: 6, volumeKg: 5000, templateId: nil, templateName: nil
    )
}

private func template(_ id: String, _ name: String, lastPerformed: Date? = nil) -> TemplateSummary {
    TemplateSummary(
        id: id, name: name, description: nil, exerciseCount: 5, exercisePreview: [], muscleGroups: [],
        lastPerformedAt: lastPerformed
    )
}

private func entry(
    _ area: Area, _ state: PlanEntryState = .planned, source: PlanSource = .pattern, templateId: String? = nil,
    templateName: String? = nil, movedFrom: String? = nil, movedTo: String? = nil
) -> PlanEntry {
    PlanEntry(
        area: area, state: state, source: source, templateId: templateId, templateName: templateName,
        movedFrom: movedFrom, movedTo: movedTo
    )
}

private func day(_ date: String, _ entries: [PlanEntry], active: Bool = true) -> PlanDay {
    PlanDay(date: date, active: active, entries: entries)
}

// MARK: Decoding

@Suite struct WeekPlanDecodingTests {
    @Test func decodesThePattern() throws {
        let pattern = try fixture("plan-pattern", as: WeekPattern.self)
        #expect(pattern.effectiveFrom == "2026-10-01")
        #expect(pattern.isActive)
        #expect(pattern.slots.count == 6)
        #expect(pattern.slots.first == PatternSlot(weekday: 1, area: .gym, templateId: "cmvo0nd360001vfx0sjes7702", templateName: "Peito"))
        #expect(pattern.slots.contains { $0.area == .run && $0.templateId == nil })
    }

    @Test func decodesAPatternThatNeverExisted() throws {
        let pattern = try APICoding.makeDecoder().decode(WeekPattern.self, from: Data(#"{"effectiveFrom":null,"slots":[]}"#.utf8))
        #expect(pattern.effectiveFrom == nil)
        #expect(!pattern.isActive)
    }

    @Test func decodesDaysWithEveryKindOfEntry() throws {
        let days = try fixture("plan-days", as: [PlanDay].self)
        #expect(days.count == 14)
        #expect(days[0].date == "2026-10-19")
        // Folga on a past Wednesday
        #expect(days[2].entry(.gym) == entry(.gym, .skipped, source: .adjustment))
        // the two halves of a move
        #expect(days[7].entry(.gym)?.movedTo == "2026-10-27")
        #expect(days[8].entry(.gym)?.movedFrom == "2026-10-26")
        #expect(days[8].entries.map(\.area) == [.run, .gym])
        // Sunday: active but a Dia livre
        #expect(days[13].active && days[13].entries.isEmpty)
    }

    @Test func decodesInactiveDays() throws {
        let days = try fixture("plan-days-inactive", as: [PlanDay].self)
        #expect(days.allSatisfy { !$0.active && $0.entries.isEmpty })
    }
}

// MARK: Dates

@Suite struct PlanDateTests {
    @Test func weekdayIsISO() {
        #expect(PlanDate.weekday("2026-10-26") == 1)
        #expect(PlanDate.weekday("2026-11-01") == 7)
    }

    @Test func windowRunsFromThisMondayToNextSunday() {
        #expect(PlanDate.window(today: "2026-10-26") == PlanDate.Range(from: "2026-10-26", to: "2026-11-08"))
        #expect(PlanDate.window(today: "2026-11-01") == PlanDate.Range(from: "2026-10-26", to: "2026-11-08"))
    }

    @Test func addDaysCrossesMonthsAndDST() {
        #expect(PlanDate.add(2, to: "2026-10-31") == "2026-11-02")
        // Brazil has no DST, but the US changes on 2026-11-01: calendar days never shift
        #expect(PlanDate.add(1, to: "2026-11-01") == "2026-11-02")
        #expect(PlanDate.week(of: "2026-10-28") == ["2026-10-26", "2026-10-27", "2026-10-28", "2026-10-29", "2026-10-30", "2026-10-31", "2026-11-01"])
    }
}

// MARK: Area state

@Suite struct PlanAreaStateTests {
    let today = "2026-10-28"

    @Test func plannedFollowsTheDay() {
        let d = day("2026-10-27", [entry(.gym)])
        #expect(PlanStatus.state(.gym, on: d, done: true, today: today) == .done)
        #expect(PlanStatus.state(.gym, on: d, done: false, today: today) == .missed)
        #expect(PlanStatus.state(.gym, on: day(today, [entry(.gym)]), done: false, today: today) == .pending)
        #expect(PlanStatus.state(.gym, on: day("2026-10-29", [entry(.gym)]), done: false, today: today) == .upcoming)
    }

    @Test func folgaAndDiaLivre() {
        let skipped = day(today, [entry(.gym, .skipped, source: .adjustment)])
        #expect(PlanStatus.state(.gym, on: skipped, done: false, today: today) == .skipped)
        #expect(PlanStatus.state(.gym, on: skipped, done: true, today: today) == .extra)
        let free = day(today, [entry(.run)])
        #expect(PlanStatus.state(.gym, on: free, done: false, today: today) == .free)
        #expect(PlanStatus.state(.gym, on: free, done: true, today: today) == .extra)
    }

    @Test func dietIsPlannedEveryDay() {
        let free = day(today, [])
        #expect(PlanStatus.state(.diet, on: free, done: false, today: today) == .pending)
        #expect(PlanStatus.state(.diet, on: day("2026-10-27", []), done: false, today: today) == .missed)
        #expect(PlanStatus.state(.diet, on: day("2026-10-30", []), done: false, today: today) == .upcoming)
    }

    @Test func withoutAnActivePlanEveryAreaIsPlanned() {
        // the old Hoje: everything pending every day
        let inactive = day(today, [], active: false)
        #expect(PlanStatus.state(.gym, on: inactive, done: false, today: today) == .pending)
        #expect(PlanStatus.state(.run, on: nil, done: true, today: today) == .done)
    }
}

// MARK: Week

@Suite struct PlanWeekTests {
    /// Wednesday: Mon gym done, Tue run missed, Wed gym pending + run extra,
    /// Thu gym moved in, Fri Folga, Sat run upcoming, Sun Dia livre.
    let now = local(28)
    let planDays = [
        day("2026-10-26", [entry(.gym, templateId: "t1", templateName: "Peito")]),
        day("2026-10-27", [entry(.run)]),
        day("2026-10-28", [entry(.gym)]),
        day("2026-10-29", [entry(.gym, source: .adjustment, movedFrom: "2026-10-30")]),
        day("2026-10-30", [entry(.gym, .skipped, source: .adjustment, movedTo: "2026-10-29")]),
        day("2026-10-31", [entry(.run)]),
        day("2026-11-01", []),
    ]

    func columns(areas: [Area] = [.run, .gym, .diet]) -> [PlanStatus.Column] {
        PlanStatus.week(
            now: now, calendar: saoPaulo, areas: areas, planDays: planDays,
            activities: [run(local(28, hour: 7))], workouts: [workout(local(26))],
            dietPoints: [DailyHistoryPoint(date: "2026-10-26", totalKcal: 1900, totalProtein: 0, totalCarbs: 0, totalFat: 0)],
            kcalGoal: 2000
        )
    }

    @Test func oneColumnPerDayMondayToSunday() {
        let week = columns()
        #expect(week.map(\.date) == PlanDate.week(of: "2026-10-28"))
        #expect(week.map(\.isToday) == [false, false, true, false, false, false, false])
    }

    @Test func eachColumnKeepsTheAreaOrderAndItsStates() {
        let week = columns()
        #expect(week[0].states == [.init(area: .run, state: .free), .init(area: .gym, state: .done), .init(area: .diet, state: .done)])
        #expect(week[1].state(.run) == .missed)
        #expect(week[2].state(.gym) == .pending)
        #expect(week[2].state(.run) == .extra)
        #expect(week[3].state(.gym) == .upcoming)
        #expect(week[4].state(.gym) == .skipped)
        #expect(week[6].state(.diet) == .upcoming)
    }

    @Test func segmentsLeaveOutFolgaAndDiaLivre() {
        let week = columns(areas: [.run, .gym])
        #expect(week[0].segments.map(\.area) == [.gym])
        #expect(week[2].segments.map(\.area) == [.run, .gym])
        #expect(week[4].segments.isEmpty && week[4].isRest)
        #expect(week[6].isRest)
    }

    @Test func onlyEnabledAreasShowUp() {
        #expect(columns(areas: [.gym]).allSatisfy { $0.states.map(\.area) == [.gym] })
    }

    @Test func progressCountsPlannedDaysAndExtras() {
        let week = columns()
        // gym planned Mon, Wed, Thu (Fri was moved away): Mon done
        #expect(PlanStatus.progress(.gym, week: week) == PlanStatus.Progress(planned: 3, doneOnPlanned: 1, extra: 0))
        // run planned Tue, Sat; the Wednesday run is an Extra
        #expect(PlanStatus.progress(.run, week: week) == PlanStatus.Progress(planned: 2, doneOnPlanned: 0, extra: 1))
    }

    @Test func progressIgnoresDaysBeforeThePlanStarted() {
        // plan created Wednesday: Mon/Tue have no plan, their workout is an Extra
        let partial = planDays.enumerated().map { i, d in i < 2 ? day(d.date, [], active: false) : d }
        let week = PlanStatus.week(
            now: now, calendar: saoPaulo, areas: [.gym], planDays: partial, activities: [],
            workouts: [workout(local(26))], dietPoints: [], kcalGoal: 2000
        )
        #expect(PlanStatus.progress(.gym, week: week) == PlanStatus.Progress(planned: 2, doneOnPlanned: 0, extra: 1))
    }

    @Test func nextPlannedDaySkipsTodayAndFolgas() {
        let next = PlanStatus.nextPlannedDay(planDays, after: "2026-10-28", areas: [.run, .gym])
        #expect(next?.date == "2026-10-29")
        #expect(next?.areas == [.gym])
        #expect(PlanStatus.nextPlannedDay(planDays, after: "2026-10-28", areas: [.run])?.date == "2026-10-31")
        #expect(PlanStatus.nextPlannedDay(planDays, after: "2026-10-31", areas: [.run, .gym]) == nil)
    }
}

// MARK: Next Treino

@Suite struct PlanNextGymTests {
    let today = "2026-10-28"
    let peito = template("t1", "Peito", lastPerformed: local(20))
    let costas = template("t2", "Costas", lastPerformed: local(10))

    @Test func todaysPlannedRoutineWins() {
        let days = [day(today, [entry(.gym, templateId: "t1", templateName: "Peito")])]
        #expect(PlanStatus.nextGym(days, templates: [peito, costas], today: today, doneToday: false)
            == PlanStatus.NextGym(template: peito, date: today))
    }

    @Test func todayWithoutARoutineFallsBackToTheRotation() {
        let days = [day(today, [entry(.gym)])]
        // Costas was done longest ago
        #expect(PlanStatus.nextGym(days, templates: [peito, costas], today: today, doneToday: false)?.template == costas)
    }

    @Test func aDeletedRoutineFallsBackToo() {
        let days = [day(today, [entry(.gym, templateId: "gone", templateName: "Pernas")])]
        #expect(PlanStatus.nextGym(days, templates: [peito, costas], today: today, doneToday: false)?.template == costas)
    }

    @Test func noTreinoTodayPointsAtTheNextPlannedDay() {
        let days = [
            day(today, [entry(.run)]),
            day("2026-10-29", [entry(.gym, .skipped, source: .adjustment)]),
            day("2026-10-30", [entry(.gym, templateId: "t1", templateName: "Peito")]),
        ]
        #expect(PlanStatus.nextGym(days, templates: [peito, costas], today: today, doneToday: false)
            == PlanStatus.NextGym(template: peito, date: "2026-10-30"))
    }

    @Test func doneTodayAlsoPointsAhead() {
        let days = [day(today, [entry(.gym)]), day("2026-10-30", [entry(.gym)])]
        #expect(PlanStatus.nextGym(days, templates: [peito, costas], today: today, doneToday: true)?.date == "2026-10-30")
    }

    @Test func nothingPlannedAheadKeepsTheRotationWithoutADate() {
        let days = [day(today, [entry(.run)])]
        #expect(PlanStatus.nextGym(days, templates: [peito, costas], today: today, doneToday: false)
            == PlanStatus.NextGym(template: costas, date: nil))
    }

    @Test func withoutAnActivePlanTodayItsTheCallersOldRule() {
        let days = [day(today, [], active: false)]
        #expect(PlanStatus.nextGym(days, templates: [peito, costas], today: today, doneToday: false) == nil)
    }
}

// MARK: Pattern draft

@Suite struct PatternDraftTests {
    let pattern = WeekPattern(effectiveFrom: "2026-10-01", slots: [
        PatternSlot(weekday: 1, area: .gym, templateId: "t1", templateName: "Peito"),
        PatternSlot(weekday: 2, area: .run, templateId: nil, templateName: nil),
    ])

    @Test func startsCleanFromThePattern() {
        let draft = PatternDraft(pattern)
        #expect(!draft.isDirty)
        #expect(draft.isOn(1, .gym) && draft.isOn(2, .run) && !draft.isOn(3, .gym))
        #expect(draft.templateId(1) == "t1")
        #expect(draft.gymDays == 1)
    }

    @Test func togglingOffATreinoDropsItsRoutine() {
        var draft = PatternDraft(pattern)
        draft.toggle(1, .gym)
        #expect(draft.isDirty && !draft.isOn(1, .gym))
        draft.toggle(1, .gym)
        #expect(draft.templateId(1) == nil)
        #expect(draft.isDirty)
    }

    @Test func undoingAChangeIsClean() {
        var draft = PatternDraft(pattern)
        draft.toggle(3, .gym)
        draft.toggle(3, .gym)
        #expect(!draft.isDirty)
    }

    @Test func aRoutineOnlyGoesOnAnActiveTreino() {
        var draft = PatternDraft(pattern)
        draft.setTemplate(3, "t2")
        #expect(draft.templateId(3) == nil && !draft.isDirty)
        draft.setTemplate(1, nil)
        #expect(draft.templateId(1) == nil && draft.isDirty)
    }

    @Test func theRequestKeepsSlotsOfDisabledAreasInWeekdayOrder() {
        // the editor only shows enabled areas; a Corrida hidden by a disabled
        // area stays in the plan
        var draft = PatternDraft(pattern)
        draft.toggle(5, .gym)
        #expect(draft.request == PatternWriteRequest(slots: [
            .init(weekday: 1, area: .gym, templateId: "t1"),
            .init(weekday: 2, area: .run, templateId: nil),
            .init(weekday: 5, area: .gym, templateId: nil),
        ]))
    }

    @Test func emptyMeansNoPlan() {
        var draft = PatternDraft(WeekPattern(effectiveFrom: nil, slots: []))
        #expect(draft.isEmpty)
        draft.toggle(1, .run)
        #expect(!draft.isEmpty)
        #expect(!PatternDraft(pattern).isEmpty)
    }

    @Test func emptyCountsOnlyEnabledAreas() {
        // a plan with only a Corrida, while Corrida is disabled, looks empty to the editor
        #expect(PatternDraft(pattern).isEmpty(among: [.diet]))
        #expect(!PatternDraft(pattern).isEmpty(among: [.run]))
    }
}

@Suite struct RoutineAbbreviationTests {
    @Test func firstLetterWhenUnique() {
        #expect(RoutineAbbreviation.make(["Peito", "Costas"]) == ["Peito": "P", "Costas": "C"])
    }

    @Test func initialsForSeveralWords() {
        #expect(RoutineAbbreviation.make(["Peito e Tríceps", "Pernas"])["Peito e Tríceps"] == "PT")
    }

    @Test func collidingNamesGetTheFirstLetterThatDiffers() {
        #expect(RoutineAbbreviation.make(["Peito", "Pernas"]) == ["Peito": "Pi", "Pernas": "Pr"])
        #expect(RoutineAbbreviation.make(["Treino A", "Treino B"]) == ["Treino A": "TA", "Treino B": "TB"])
    }

    @Test func identicalNamesShareOne() {
        #expect(RoutineAbbreviation.make(["Full", "Full"]) == ["Full": "F"])
    }
}

// MARK: Move targets

@Suite struct MoveTargetsTests {
    let today = "2026-10-28"
    let window = [
        day("2026-10-26", [entry(.gym)]),
        day("2026-10-27", [entry(.run)]),
        day("2026-10-28", [entry(.gym, templateId: "t1", templateName: "Peito")]),
        day("2026-10-29", [entry(.run)]),
        day("2026-10-30", [entry(.gym)]),
        day("2026-10-31", [entry(.gym, .skipped, source: .adjustment)]),
        day("2026-11-01", [entry(.gym, .skipped, source: .adjustment, movedTo: "2026-11-02")]),
        day("2026-11-02", [entry(.gym, source: .adjustment, movedFrom: "2026-11-01")]),
        day("2026-11-03", [], active: false),
    ]

    @Test func targetsRunFromTodayToTheEndOfTheWindow() {
        let targets = PlanStatus.moveTargets(.gym, from: today, window: window, today: today)
        #expect(targets.map(\.date) == ["2026-10-28", "2026-10-29", "2026-10-30", "2026-10-31", "2026-11-01", "2026-11-02", "2026-11-03"])
    }

    @Test func eachTargetSaysWhyItIsRefused() {
        let byDate = Dictionary(uniqueKeysWithValues: PlanStatus.moveTargets(.gym, from: today, window: window, today: today).map { ($0.date, $0.refusal) })
        #expect(byDate["2026-10-28"] == .sameDay)
        #expect(byDate["2026-10-29"] == .some(nil))
        #expect(byDate["2026-10-30"] == .alreadyPlanned)
        // landing on a Folga of the same area replaces it
        #expect(byDate["2026-10-31"] == .some(nil))
        #expect(byDate["2026-11-01"] == .partOfMove)
        #expect(byDate["2026-11-02"] == .alreadyPlanned)
        #expect(byDate["2026-11-03"] == .noPlan)
    }

    @Test func nothingToMoveFromAPastDayOrAMoveHalf() {
        #expect(!PlanStatus.canMove(.gym, from: "2026-10-26", window: window, today: today))
        #expect(!PlanStatus.canMove(.gym, from: "2026-11-02", window: window, today: today))
        #expect(!PlanStatus.canMove(.run, from: today, window: window, today: today))
        #expect(PlanStatus.canMove(.gym, from: today, window: window, today: today))
    }
}

// MARK: Requests

@Suite struct PlanRequestTests {
    func json(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    @Test func dayChangeEncodesUndoAsNull() throws {
        let request = DayChangeRequest([.gym: nil, .run: .init(state: .skipped)])
        #expect(try json(request) == #"{"entries":{"GYM":null,"RUN":{"state":"SKIPPED","templateId":null}}}"#)
    }

    @Test func dayChangeCarriesTheRoutine() throws {
        #expect(try json(DayChangeRequest([.gym: .init(state: .planned, templateId: "t1")]))
            == #"{"entries":{"GYM":{"state":"PLANNED","templateId":"t1"}}}"#)
    }

    @Test func patternAndMove() throws {
        #expect(try json(PatternWriteRequest(slots: [.init(weekday: 1, area: .run, templateId: nil)]))
            == #"{"slots":[{"area":"RUN","templateId":null,"weekday":1}]}"#)
        #expect(try json(PlanMoveRequest(area: .gym, from: "2026-10-28", to: "2026-10-29"))
            == #"{"area":"GYM","from":"2026-10-28","to":"2026-10-29"}"#)
    }
}

@Suite struct PlanLabelsTests {
    @Test func weekdayNames() {
        #expect(PlanDate.weekdayShort("2026-10-28", lang: .pt) == "Qua")
        #expect(PlanDate.weekdayShort("2026-11-01", lang: .en) == "Sun")
        #expect(PlanDate.weekdayLong("2026-10-26", lang: .pt) == "Segunda")
    }

    @Test func localMidnightIsInTheCalendarsZone() {
        let midnight = PlanDate.localMidnight("2026-10-28", calendar: saoPaulo)
        #expect(DietFormat.localDate(midnight, calendar: saoPaulo) == "2026-10-28")
        #expect(saoPaulo.component(.hour, from: midnight) == 0)
    }
}

@Suite struct PlanPreviewTests {
    @Test func coversTheWindowAroundToday() {
        let days = PlanPreview.days(today: "2026-10-28", restDay: false)
        #expect(days.map(\.date) == (0..<14).map { PlanDate.add($0, to: "2026-10-26") })
        #expect(days.allSatisfy { $0.active })
        #expect(days[2].entries.map(\.area) == [.run, .gym])
    }

    @Test func restDayLeavesTodayEmpty() {
        #expect(PlanPreview.days(today: "2026-10-28", restDay: true)[2].entries.isEmpty)
    }

    @Test func showsAFolgaAndAMove() {
        let days = PlanPreview.days(today: "2026-10-28", restDay: false)
        #expect(days[1].entry(.run)?.movedTo == "2026-11-01")
        #expect(days[6].entry(.run)?.movedFrom == "2026-10-27")
        #expect(days[4].entry(.gym)?.state == .skipped)
    }
}

@Suite struct WeeklyGoalAreasTests {
    @Test func thePlanTakesOverTheTreinoGoal() {
        #expect(ProfileRules.weeklyGoalAreas([.run, .gym, .diet], planned: false) == [.run, .gym])
        #expect(ProfileRules.weeklyGoalAreas([.run, .gym, .diet], planned: true) == [.run])
        #expect(ProfileRules.weeklyGoalAreas([.gym], planned: true).isEmpty)
        #expect(ProfileRules.weeklyGoalAreas([.diet], planned: false).isEmpty)
    }
}

// MARK: Day sheet

@Suite struct PlanDaySheetTests {
    let today = "2026-10-28"
    let both: [Area] = [.run, .gym, .diet]

    func sheet(_ date: String, _ window: [PlanDay], areas: [Area]? = nil) -> PlanDaySheet? {
        PlanDaySheet.make(date: date, window: window, areas: areas ?? both, today: today)
    }

    func row(_ sheet: PlanDaySheet?, _ area: Area) -> PlanDaySheet.Row? { sheet?.rows.first { $0.area == area } }

    @Test func onlyRunAndGymAmongTheEnabledAreas() {
        let window = [day(today, [entry(.gym)])]
        #expect(sheet(today, window)?.rows.map(\.area) == [.run, .gym])
        #expect(sheet(today, window, areas: [.gym, .diet])?.rows.map(\.area) == [.gym])
    }

    @Test func noSheetWithoutAnActivePlanOrOutsideTheWindow() {
        #expect(sheet(today, [day(today, [], active: false)]) == nil)
        #expect(sheet("2026-11-20", [day(today, [entry(.gym)])]) == nil)
    }

    @Test func aPlannedTreinoCanChangeRoutineMoveAndSkip() {
        let window = [day(today, [entry(.gym, templateId: "t1", templateName: "Peito")]), day("2026-10-29", [])]
        let gym = row(sheet(today, window), .gym)
        #expect(gym?.kind == .planned(templateName: "Peito", adjusted: false))
        #expect(gym?.actions == [.changeRoutine, .move, .skip])
    }

    @Test func aPlannedCorridaHasNoRoutine() {
        let window = [day(today, [entry(.run, source: .adjustment)])]
        let run = row(sheet(today, window), .run)
        #expect(run?.kind == .planned(templateName: nil, adjusted: true))
        #expect(run?.actions == [.move, .skip])
    }

    @Test func aFreeAreaCanBeAdded() {
        let run = row(sheet(today, [day(today, [entry(.gym)])]), .run)
        #expect(run?.kind == .free)
        #expect(run?.actions == [.add])
    }

    @Test func aFolgaCanBeUndone() {
        let gym = row(sheet(today, [day(today, [entry(.gym, .skipped, source: .adjustment)])]), .gym)
        #expect(gym?.kind == .skipped)
        #expect(gym?.actions == [.undo])
    }

    @Test func bothHalvesOfAMoveOnlyUndo() {
        let window = [
            day(today, [entry(.gym, .skipped, source: .adjustment, movedTo: "2026-11-02")]),
            day("2026-11-02", [entry(.gym, source: .adjustment, templateName: "Peito", movedFrom: today)]),
        ]
        #expect(row(sheet(today, window), .gym) == .init(area: .gym, kind: .movedTo("2026-11-02"), actions: [.undo]))
        #expect(row(sheet("2026-11-02", window), .gym) == .init(area: .gym, kind: .movedFrom(today, templateName: "Peito"), actions: [.undo]))
    }

    @Test func aMoveWithAHalfInThePastIsFrozen() {
        let window = [
            day("2026-10-27", [entry(.gym, .skipped, source: .adjustment, movedTo: "2026-10-29")]),
            day("2026-10-29", [entry(.gym, source: .adjustment, movedFrom: "2026-10-27")]),
        ]
        #expect(row(sheet("2026-10-27", window), .gym)?.actions == [])
        #expect(row(sheet("2026-10-29", window), .gym)?.actions == [])
    }

    @Test func pastDaysOnlyTakeAFolgaOfThePadrao() {
        let window = [
            day("2026-10-26", [entry(.gym), entry(.run, source: .adjustment)]),
            day("2026-10-27", [entry(.gym, .skipped, source: .adjustment)]),
        ]
        let monday = sheet("2026-10-26", window)
        #expect(monday?.isPast == true)
        #expect(row(monday, .gym)?.actions == [.skip])
        // an Ajuste added it: the server can't tell a Folga from undoing it
        #expect(row(monday, .run)?.actions == [])
        #expect(row(sheet("2026-10-27", window), .gym)?.actions == [.undo])
        #expect(row(sheet("2026-10-27", window), .run)?.actions == [])
    }

    @Test func folgaForTheWholeDayNeedsTwoSkippableAreas() {
        #expect(sheet(today, [day(today, [entry(.gym), entry(.run)])])?.canSkipAll == true)
        #expect(sheet(today, [day(today, [entry(.gym)])])?.canSkipAll == false)
        #expect(sheet(today, [day(today, [entry(.gym), entry(.run)])], areas: [.gym])?.canSkipAll == false)
    }
}

// MARK: Changes

@Suite struct PlanChangeTests {
    let today = "2026-10-28"
    let names = ["t1": "Peito", "t2": "Costas"]

    @Test func requestsGoToTheirRoutes() {
        #expect(PlanChange.skip(.gym, on: today).route == .day(today, DayChangeRequest([.gym: .init(state: .skipped)])))
        #expect(PlanChange.skipAll([.run, .gym], on: today).route
            == .day(today, DayChangeRequest([.run: .init(state: .skipped), .gym: .init(state: .skipped)])))
        #expect(PlanChange.undo(.run, on: today).route == .day(today, DayChangeRequest([.run: nil])))
        #expect(PlanChange.add(.run, on: today).route == .day(today, DayChangeRequest([.run: .init(state: .planned)])))
        #expect(PlanChange.routine("t2", on: today).route == .day(today, DayChangeRequest([.gym: .init(state: .planned, templateId: "t2")])))
        #expect(PlanChange.move(.gym, from: today, to: "2026-11-02").route == .move(PlanMoveRequest(area: .gym, from: today, to: "2026-11-02")))
    }

    @Test func aFolgaAndAnAdditionShowAtOnce() {
        let window = [day(today, [entry(.gym)])]
        let skipped = PlanChange.skip(.gym, on: today).applied(to: window, templateNames: names)
        #expect(skipped[0].entry(.gym)?.state == .skipped)
        let added = PlanChange.add(.run, on: today).applied(to: window, templateNames: names)
        #expect(added[0].entries.map(\.area) == [.run, .gym])
        #expect(added[0].entry(.run)?.state == .planned)
    }

    @Test func aRoutineChangeShowsItsName() {
        let window = [day(today, [entry(.gym, templateId: "t1", templateName: "Peito")])]
        let changed = PlanChange.routine("t2", on: today).applied(to: window, templateNames: names)
        #expect(changed[0].entry(.gym)?.templateName == "Costas")
        #expect(changed[0].entry(.gym)?.source == .adjustment)
        #expect(PlanChange.routine(nil, on: today).applied(to: window, templateNames: names)[0].entry(.gym)?.templateName == nil)
    }

    @Test func aMoveEmptiesOneDayAndFillsTheOther() {
        let window = [day(today, [entry(.gym, templateId: "t1", templateName: "Peito")]), day("2026-11-02", [entry(.run)])]
        let moved = PlanChange.move(.gym, from: today, to: "2026-11-02").applied(to: window, templateNames: names)
        #expect(moved[0].entry(.gym)?.movedTo == "2026-11-02")
        #expect(moved[0].entry(.gym)?.state == .skipped)
        #expect(moved[1].entry(.gym)?.movedFrom == today)
        #expect(moved[1].entry(.gym)?.templateName == "Peito")
        #expect(moved[1].entries.map(\.area) == [.run, .gym])
    }

    @Test func undoingAMoveHalfUndoesBoth() {
        let window = [
            day(today, [entry(.gym, .skipped, source: .adjustment, movedTo: "2026-11-02")]),
            day("2026-11-02", [entry(.gym, source: .adjustment, templateId: "t1", templateName: "Peito", movedFrom: today)]),
        ]
        for date in [today, "2026-11-02"] {
            let undone = PlanChange.undo(.gym, on: date).applied(to: window, templateNames: names)
            #expect(undone[0].entry(.gym) == entry(.gym, templateId: "t1", templateName: "Peito"))
            #expect(undone[1].entry(.gym) == nil)
        }
    }

    @Test func undoingAFolgaGoesBackToThePadrao() {
        let window = [day(today, [entry(.gym, .skipped, source: .adjustment)])]
        #expect(PlanChange.undo(.gym, on: today).applied(to: window, templateNames: names)[0].entry(.gym) == entry(.gym))
    }
}
