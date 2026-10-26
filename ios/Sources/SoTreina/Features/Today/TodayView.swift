import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// Hoje, the web's `TodayPage` (Redesign 18a/21): the day's status per area,
/// this week Monday to Sunday, each area against its goal (the pencil pushes
/// Perfil's weekly goals) and a mixed feed. Only the enabled areas show. Every
/// number derives from the stores the area tabs already hold (`TodayStatus`),
/// so Hoje never reads a figure the area's own tab wouldn't. A tap opens the
/// area's page in its tab, never a detail.
/// With an active Plano da semana (spec .plans/plano-semanal-spec.md §6.3,
/// `PlanStatus`) the status only shows what is planned today (plus Dieta and
/// any Extra), the week strip tells done from planned, and Treino/Corrida in
/// "Por área" count planned days. Without one, every area is planned every
/// day: the old Hoje.
struct TodayView: View {
    let me: Me
    let workout: WorkoutStore
    let run: RunStore
    let gymHistory: GymHistoryStore
    let diet: DietStore
    let dietHistory: DietHistoryStore
    let profile: ProfileStore
    let plan: PlanStore
    let onNavigate: (AppPage) -> Void
    /// refreshed on every load: a tab left open past midnight moves to the new day
    @State private var now = Date.now
    @State private var editingGoals = false
    /// the Padrão editor (open on a `weekPlanEditor` validation launch)
    @State private var editingPlan = ValidationLaunch.current.destination == .weekPlanEditor
    /// the day sheet (open on a `planDaySheet` validation launch)
    @State private var openDay: PlanDayItem? = {
        if case .planDaySheet(let past) = ValidationLaunch.current.destination {
            return PlanDayItem(date: PlanPreview.sheetDate(today: PlanStore.today(), past: past))
        }
        return nil
    }()
    /// the sheet's "Editar padrão semanal": the push waits for the dismissal
    @State private var editorAfterSheet = false
    @Environment(AppLanguageStore.self) private var language
    @Environment(\.scenePhase) private var scenePhase

    private let calendar = Calendar.current

    private var areas: [Area] { me.enabledAreas }
    /// a run feed needs Strava; without it Corrida stays empty
    private var readsRuns: Bool { areas.contains(.run) && me.hasStravaAccount }
    /// Dieta is never planned: a plan needs Corrida or Treino
    private var plansAreas: Bool { areas.contains(.run) || areas.contains(.gym) }
    /// the weekly goals the pencil edits: with a plan, Treino's comes from it
    private var goalAreas: [Area] { ProfileRules.weeklyGoalAreas(areas, planned: plan.isActiveToday) }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.pageBg)
            .onPopToRoot {
                editingGoals = false
                editingPlan = false
                openDay = nil
            }
            .navigationDestination(isPresented: $editingGoals) {
                if let settings = profile.settings {
                    WeeklyGoalsView(settings: settings, areas: goalAreas, unit: me.distanceUnit, store: profile)
                        .hidesFloatingTabBar()
                }
            }
            .navigationDestination(isPresented: $editingPlan) {
                WeekPlanEditorView(areas: areas, plan: plan, workout: workout, profile: profile)
            }
            .sheet(item: $openDay, onDismiss: {
                if editorAfterSheet {
                    editorAfterSheet = false
                    editingPlan = true
                }
            }) { day in
                PlanDaySheetView(date: day.date, areas: areas, plan: plan, workout: workout) {
                    editorAfterSheet = true
                    openDay = nil
                }
                .monolitoTheme()
            }
            // every time the page shows: a run, workout or Registro from
            // another tab (or the web) must count
            .taskOnTabActivation { await load() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await load() } }
            }
    }

    /// Spinner only until every enabled area answered once (from the cache
    /// or the network); a failed area then reads as empty, like the web.
    private var ready: Bool {
        func done(_ state: WorkoutStore.LoadState) -> Bool {
            state != .idle && state != .loading
        }
        let runReady: Bool = !readsRuns || run.loadState != .idle && run.loadState != .loading
        let gymReady = !areas.contains(.gym) || done(gymHistory.loadState)
        let dietReady = !areas.contains(.diet) || done(dietHistory.loadState)
        return runReady && gymReady && dietReady
    }

    @ViewBuilder private var content: some View {
        if ready {
            page
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func load() async {
        now = .now
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await profile.load() }
            if plansAreas { group.addTask { await plan.load() } }
            if readsRuns { group.addTask { await run.load() } }
            if areas.contains(.gym) {
                group.addTask { await gymHistory.load() }
                group.addTask { await workout.load() }
            }
            if areas.contains(.diet) {
                group.addTask { await dietHistory.load() }
                group.addTask { await diet.load() }
            }
        }
    }

    private var page: some View {
        let lang = language.lang
        let settings = profile.settings ?? MeSettings()
        let activities = readsRuns ? run.activities : []
        let workouts = areas.contains(.gym) ? gymHistory.items : []
        let points = areas.contains(.diet) ? dietHistory.points : []
        let totals = TodayStatus.buildTotals(activities: activities, workouts: workouts, now: now, calendar: calendar)
        let kcalToday = points.first { $0.date == DietFormat.localDate(now, calendar: calendar) }?.totalKcal ?? 0
        let week = PlanStatus.week(
            now: now, calendar: calendar, areas: areas, planDays: plansAreas ? plan.days : [],
            activities: activities, workouts: workouts, dietPoints: points, kcalGoal: settings.dailyKcalGoal
        )
        let todayColumn = week.first(where: \.isToday)
        let planned = plansAreas && todayColumn?.active == true
        let cells = statusCells(totals: totals, kcalToday: kcalToday, goal: settings.dailyKcalGoal, today: planned ? todayColumn : nil, lang: lang)
        // a Dia livre for Corrida and Treino, even with the Dieta cell up
        let restDay = planned && !(todayColumn?.states.contains { $0.area != .diet && $0.state.isPlanned } ?? true)
        let next = PlanStatus.nextPlannedDay(plan.days, after: DietFormat.localDate(now, calendar: calendar), areas: areas)

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: DietFormat.dayHeader(now, lang: lang, calendar: calendar))
                    .font(DSFont.meta)
                    .foregroundStyle(Color.mutedFg)
                    .padding(.top, 12)

                VStack(spacing: 0) {
                    if !cells.isEmpty { StatusGrid(cells: cells, open: onNavigate) }
                    if restDay { RestDay(next: next, standalone: cells.isEmpty) }
                }
                .padding(.top, 22)

                if plansAreas && !planned {
                    PlanInvite { editingPlan = true }
                }

                WeekStrip(columns: week, canEditPlan: plansAreas, onOpenDay: { openDay = PlanDayItem(date: $0) }) { editingPlan = true }
                    .padding(.top, 24)

                ByArea(
                    rows: areaRows(totals: totals, kcalToday: kcalToday, settings: settings, week: planned ? week : nil, lang: lang),
                    canEdit: profile.settings != nil && !goalAreas.isEmpty,
                    open: onNavigate
                ) { editingGoals = true }
                    .padding(.top, 24)

                Feed(rows: TodayStatus.buildFeed(
                    activities: activities, workouts: workouts, meals: areas.contains(.diet) ? diet.meals : [],
                    todayLogs: areas.contains(.diet) ? diet.logs : [], areas: areas
                ).map { feedRow($0, lang: lang) }, open: onNavigate)
                    .padding(.top, 24)

                // runs in the status and the feed are Strava data: the brand
                // guidelines want the attribution
                if readsRuns {
                    PoweredByStrava()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 32)
                }
            }
            .padding(.horizontal, pageGutter)
            .padding(.bottom, 44)
        }
        .refreshable { await load() }
        .floatingTabBarScroll()
    }

    // MARK: Rows

    /// With a plan (`today` set), only what is planned today, Dieta and any
    /// Extra; Folga and Dia livre leave the grid. Without one, every area.
    private func statusCells(
        totals: TodayStatus.Totals, kcalToday: Double, goal: Int, today: PlanStatus.Column?, lang: Lang
    ) -> [StatusCell] {
        let unit = UnitConversion.label(me.distanceUnit)
        let shown = today.map { $0.segments.map(\.area) } ?? areas
        return shown.map { area in
            let extra = today?.state(area) == .extra
            switch area {
            case .run:
                let done = totals.runKmToday > 0
                return StatusCell(
                    area: area, label: L10n.string("today.status.run", lang: lang), done: done, extra: extra,
                    sub: done
                        ? L10n.string("today.status.runDone %@ %@", lang: lang, RunFormat.distance(totals.runKmToday, unit: me.distanceUnit, lang: lang), unit)
                        : L10n.string("today.status.pending", lang: lang),
                    page: .runActivities
                )
            case .gym:
                return StatusCell(
                    area: area, label: L10n.string("today.status.gym", lang: lang),
                    done: !totals.workoutsToday.isEmpty, extra: extra, sub: gymSub(totals, lang: lang), page: .gymOverview
                )
            case .diet:
                return StatusCell(
                    area: area, label: L10n.string("today.status.diet", lang: lang),
                    done: TodayStatus.isDietDone(kcal: kcalToday, goal: goal), extra: false,
                    sub: "\(DietFormat.integer(Int(kcalToday.rounded()), lang: lang)) / \(DietFormat.integer(goal, lang: lang))",
                    page: .dietOverview
                )
            }
        }
    }

    /// An open workout first, then what's done today, then the next routine
    /// (today's planned one, with a plan).
    private func gymSub(_ totals: TodayStatus.Totals, lang: Lang) -> String {
        let free = L10n.string("gym.freeWorkout", lang: lang)
        if let active = workout.active {
            return L10n.string("today.status.gymInProgress %@", lang: lang, active.templateName ?? free)
        }
        if let first = totals.workoutsToday.first {
            return totals.workoutsToday.count == 1
                ? L10n.string("today.status.gymDone %@", lang: lang, first.templateName ?? free)
                : L10n.string("today.status.gymDoneCount %lld", lang: lang, totals.workoutsToday.count)
        }
        if let next = workout.templates.first(where: { $0.id == workout.nextRoutineId }) {
            return L10n.string("today.status.gymPending %@", lang: lang, next.name)
        }
        return L10n.string("today.status.pending", lang: lang)
    }

    /// With a plan (`week` set) Treino counts planned days ("2 de 3", Extras
    /// in the detail, never in the count) and Corrida keeps km against its
    /// goal, with the planned runs in the detail.
    private func areaRows(totals: TodayStatus.Totals, kcalToday: Double, settings: MeSettings, week: [PlanStatus.Column]?, lang: Lang) -> [AreaRow] {
        let unit = me.distanceUnit
        return areas.map { area in
            switch area {
            case .run:
                let runGoal = L10n.string(
                    "today.areas.runGoal %lld %@", lang: lang,
                    UnitConversion.goalDisplay(km: settings.weeklyRunKmGoal, in: unit), UnitConversion.label(unit)
                )
                let progress = week.map { PlanStatus.progress(.run, week: $0) }
                return AreaRow(
                    area: area, name: L10n.string("today.status.run", lang: lang),
                    detail: progress.map { planDetail(
                        L10n.string("today.areas.runPlanned %lld %lld", lang: lang, $0.doneOnPlanned, $0.planned), $0, lang: lang
                    ) } ?? runGoal,
                    value: "\(RunFormat.distance(totals.runKmWeek, unit: unit, lang: lang)) \(UnitConversion.label(unit))",
                    percent: TodayStatus.percent(totals.runKmWeek, of: settings.weeklyRunKmGoal), over: false,
                    page: .runActivities
                )
            case .gym:
                if let week {
                    let progress = PlanStatus.progress(.gym, week: week)
                    return AreaRow(
                        area: area, name: L10n.string("today.status.gym", lang: lang),
                        detail: progress.planned == 0
                            ? planDetail(L10n.string("today.areas.noGymPlanned", lang: lang), progress, lang: lang)
                            : planDetail(L10n.string("today.areas.gymPlanned", lang: lang), progress, lang: lang),
                        value: progress.planned == 0
                            ? "—"
                            : L10n.string("today.areas.ofPlanned %lld %lld", lang: lang, progress.doneOnPlanned, progress.planned),
                        percent: TodayStatus.percent(Double(progress.doneOnPlanned), of: progress.planned), over: false,
                        page: .gymOverview
                    )
                }
                let goal = settings.weeklyWorkoutsGoal
                return AreaRow(
                    area: area, name: L10n.string("today.status.gym", lang: lang),
                    detail: L10n.string("today.areas.gymGoal %lld", lang: lang, goal),
                    value: "\(totals.workoutsWeek) / \(goal)",
                    percent: TodayStatus.percent(Double(totals.workoutsWeek), of: goal), over: false,
                    page: .gymOverview
                )
            case .diet:
                let goal = settings.dailyKcalGoal
                return AreaRow(
                    area: area, name: L10n.string("today.status.diet", lang: lang),
                    detail: L10n.string("today.areas.dietGoal %@", lang: lang, DietFormat.integer(goal, lang: lang)),
                    value: DietFormat.integer(Int(kcalToday.rounded()), lang: lang),
                    percent: TodayStatus.percent(kcalToday, of: goal),
                    // strict value > goal, the Dieta bar's rule
                    over: kcalToday > Double(goal),
                    page: .dietOverview
                )
            }
        }
    }

    /// "planejados esta semana · +1 extra"
    private func planDetail(_ text: String, _ progress: PlanStatus.Progress, lang: Lang) -> String {
        progress.extra > 0 ? "\(text) · \(L10n.string("today.areas.extra %lld", lang: lang, progress.extra))" : text
    }

    private func feedRow(_ item: TodayStatus.FeedItem, lang: Lang) -> FeedRow {
        let when: String = switch TodayStatus.calendarDaysAgo(item.at, now: now, calendar: calendar) {
        case 0: L10n.string("today.feed.today", lang: lang)
        case 1: L10n.string("today.feed.yesterday", lang: lang)
        case let n: L10n.string("today.feed.daysAgo %lld", lang: lang, n)
        }
        let minutes = { (sec: Int) in L10n.string("today.feed.minutes %lld", lang: lang, Int((Double(sec) / 60).rounded())) }
        switch item {
        case .run(_, _, let name, let durationSec, let distanceKm):
            return FeedRow(
                id: item.id, name: name,
                detail: "\(L10n.string("today.status.run", lang: lang)) · \(when) · \(minutes(durationSec))",
                value: "\(RunFormat.distance(distanceKm, unit: me.distanceUnit, lang: lang)) \(UnitConversion.label(me.distanceUnit))",
                page: .runActivities
            )
        case .gym(_, _, let name, let exerciseCount, let durationSec):
            return FeedRow(
                id: item.id, name: name ?? L10n.string("gym.freeWorkout", lang: lang),
                detail: "\(L10n.string("today.status.gym", lang: lang)) · \(when) · \(L10n.string("today.feed.exercises %lld", lang: lang, exerciseCount))",
                value: minutes(durationSec),
                page: .gymOverview
            )
        case .diet(_, _, let mealType, let itemCount, let kcal):
            return FeedRow(
                id: item.id, name: mealLabel(mealType, lang: lang),
                detail: "\(L10n.string("today.status.diet", lang: lang)) · \(when) · \(L10n.string("today.feed.items %lld", lang: lang, itemCount))",
                value: "\(DietFormat.integer(kcal, lang: lang)) kcal",
                page: .dietOverview
            )
        }
    }

    // MARK: Sections

    struct StatusCell: Identifiable {
        let area: Area
        let label: String
        let done: Bool
        /// done without being planned
        let extra: Bool
        let sub: String
        let page: AppPage
        var id: Area { area }
    }

    /// One column per area between two hairlines, split by vertical ones:
    /// a filled mustard check when done, an empty ring otherwise.
    private struct StatusGrid: View {
        let cells: [StatusCell]
        let open: (AppPage) -> Void
        @Environment(AppLanguageStore.self) private var language

        var body: some View {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(cells.enumerated()), id: \.element.id) { index, cell in
                    if index > 0 { Hairline(axis: .vertical) }
                    Button { open(cell.page) } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            mark(cell.done)
                            Text(verbatim: cell.label)
                                .font(Font.geist(13.5, relativeTo: .subheadline).weight(.medium))
                                .foregroundStyle(Color.fg)
                                .padding(.top, 10)
                            Text(verbatim: cell.extra ? L10n.string("today.status.extra %@", lang: language.lang, cell.sub) : cell.sub)
                                .font(DSFont.caption)
                                .foregroundStyle(Color.mutedFg)
                                .lineLimit(1)
                                .padding(.top, 2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 16)
                        .padding(.leading, index > 0 ? 14 : 0)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: "\(cell.label), \(cell.sub)"))
                    .accessibilityValue(Text(cell.done ? "today.status.done" : "today.status.pending", bundle: .l10n))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .overlay(alignment: .top) { Hairline() }
            .overlay(alignment: .bottom) { Hairline() }
        }

        @ViewBuilder private func mark(_ done: Bool) -> some View {
            if done {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Color.accFg)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.acc))
            } else {
                Circle()
                    .strokeBorder(Color.mutedFg, lineWidth: 1.5)
                    .frame(width: 22, height: 22)
            }
        }
    }

    /// A Dia livre with a plan: nothing planned for Corrida or Treino today.
    /// One line with the next planned day, in place of the grid when no cell
    /// is left, or under it (the Dieta cell, an Extra) otherwise.
    private struct RestDay: View {
        let next: PlanStatus.NextPlanned?
        /// no grid above: draws its own top hairline
        let standalone: Bool
        @Environment(AppLanguageStore.self) private var language

        var body: some View {
            let lang = language.lang
            VStack(alignment: .leading, spacing: 2) {
                Text("today.rest.title", bundle: .l10n)
                    .font(Font.geist(13.5, relativeTo: .subheadline).weight(.medium))
                    .foregroundStyle(Color.fg)
                if let next {
                    Text(verbatim: L10n.string("today.rest.next %@ %@", lang: lang, PlanDate.weekdayShort(next.date, lang: lang), what(next, lang)))
                        .font(DSFont.caption)
                        .foregroundStyle(Color.mutedFg)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, standalone ? 16 : 13)
            .overlay(alignment: .top) { if standalone { Hairline() } }
            .overlay(alignment: .bottom) { Hairline() }
            .accessibilityElement(children: .combine)
        }

        /// "Treino · Peito" | "Corrida e Treino"
        private func what(_ next: PlanStatus.NextPlanned, _ lang: Lang) -> String {
            let names = next.areas.map { L10n.string($0 == .run ? "today.status.run" : "today.status.gym", lang: lang) }
            let joined = names.joined(separator: lang == .pt ? " e " : " and ")
            return next.templateName.map { "\(joined) · \($0)" } ?? joined
        }
    }

    /// "Planeje sua semana ›" — no plan yet, Corrida or Treino enabled.
    private struct PlanInvite: View {
        let open: () -> Void

        var body: some View {
            Button(action: open) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("today.invite.title", bundle: .l10n)
                            .font(DSFont.row)
                            .foregroundStyle(Color.fg)
                        Text("today.invite.subtitle", bundle: .l10n)
                            .font(DSFont.caption)
                            .foregroundStyle(Color.mutedFg)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.mutedFg)
                }
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .overlay(alignment: .bottom) { Hairline() }
        }
    }

    /// "Esta semana", Monday to Sunday: a 20 pt segment per area that counts
    /// that day, stacked from the bottom. Done is filled (today's in mustard),
    /// planned but not done is the empty bar, planned ahead is only its
    /// outline, an Extra is filled with a mustard dot on top, and a day with
    /// only Folga or Dia livre gets a short neutral dash.
    private struct WeekStrip: View {
        let columns: [PlanStatus.Column]
        let canEditPlan: Bool
        /// a column with an active plan opens its day sheet
        let onOpenDay: (String) -> Void
        let onEditPlan: () -> Void
        @Environment(AppLanguageStore.self) private var language

        var body: some View {
            let lang = language.lang
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    SectionTitle(L10n.string("today.week.title", lang: lang))
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text("today.week.legend", bundle: .l10n)
                        .font(DSFont.caption)
                        .foregroundStyle(Color.mutedFg)
                    if canEditPlan {
                        Button(action: onEditPlan) {
                            Image(systemName: "calendar")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.mutedFg)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, -12)
                        .padding(.vertical, -12)
                        .accessibilityLabel(Text("today.week.editPlan", bundle: .l10n))
                    }
                }

                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(columns, id: \.date) { column in
                        let tappable = canEditPlan && column.active
                        VStack(spacing: 8) {
                            bars(column)
                                .frame(height: 72, alignment: .bottom)
                            Text(verbatim: String(PlanDate.weekdayShort(column.date, lang: lang).prefix(1)))
                                .font(Font.geistMono(10.5, relativeTo: .caption2).weight(column.isToday ? .semibold : .regular))
                                .foregroundStyle(column.isToday ? Color.fg : Color.mutedFg)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { if tappable { onOpenDay(column.date) } }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(verbatim: a11y(column, lang)))
                        .accessibilityHint(tappable ? Text("plan.day.open", bundle: .l10n) : Text(verbatim: ""))
                        .accessibilityAddTraits(tappable ? .isButton : [])
                    }
                }
                .padding(.top, 14)
            }
        }

        @ViewBuilder private func bars(_ column: PlanStatus.Column) -> some View {
            if column.isRest {
                Capsule()
                    .fill(Color.border)
                    .frame(width: 14, height: 3)
            } else {
                VStack(spacing: 3) {
                    if column.segments.contains(where: { $0.state == .extra }) {
                        Circle().fill(Color.acc).frame(width: 5, height: 5)
                    }
                    ForEach(column.segments.reversed(), id: \.area) { segment in
                        segmentShape(segment.state, isToday: column.isToday)
                            .frame(height: 20)
                    }
                }
            }
        }

        @ViewBuilder private func segmentShape(_ state: PlanAreaState, isToday: Bool) -> some View {
            let shape = RoundedRectangle(cornerRadius: 3, style: .continuous)
            switch state {
            case .done, .extra:
                shape.fill(isToday ? Color.acc : Color.fg)
            case .upcoming:
                shape.strokeBorder(Color.border, lineWidth: 1.5)
            default:
                shape.fill(Color.border)
            }
        }

        /// "Quarta: Treino feito, Corrida planejada"
        private func a11y(_ column: PlanStatus.Column, _ lang: Lang) -> String {
            let parts = column.states.map { "\(areaName($0.area, lang)) \(stateWord($0.state, lang))" }
            return "\(PlanDate.weekdayLong(column.date, lang: lang)): \(parts.joined(separator: ", "))"
        }

        private func areaName(_ area: Area, _ lang: Lang) -> String {
            switch area {
            case .run: L10n.string("today.status.run", lang: lang)
            case .gym: L10n.string("today.status.gym", lang: lang)
            case .diet: L10n.string("today.status.diet", lang: lang)
            }
        }

        private func stateWord(_ state: PlanAreaState, _ lang: Lang) -> String {
            switch state {
            case .done: L10n.string("today.plan.done", lang: lang)
            case .pending: L10n.string("today.plan.pending", lang: lang)
            case .missed: L10n.string("today.plan.missed", lang: lang)
            case .upcoming: L10n.string("today.plan.upcoming", lang: lang)
            case .skipped: L10n.string("today.plan.skipped", lang: lang)
            case .extra: L10n.string("today.plan.extra", lang: lang)
            case .free: L10n.string("today.plan.free", lang: lang)
            }
        }
    }

    struct AreaRow: Identifiable {
        let area: Area
        let name: String
        let detail: String
        let value: String
        let percent: Int
        let over: Bool
        let page: AppPage
        var id: Area { area }
    }

    /// "Por área" with the pencil, then one hairline row per area: the goal
    /// on the left, the figure and a 64 pt progress line on the right.
    private struct ByArea: View {
        let rows: [AreaRow]
        let canEdit: Bool
        let open: (AppPage) -> Void
        let onEdit: () -> Void
        @Environment(AppLanguageStore.self) private var language

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    SectionTitle(L10n.string("today.areas.title", lang: language.lang))
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.mutedFg)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, -12)
                    .disabled(!canEdit)
                    .opacity(canEdit ? 1 : 0.4)
                    .accessibilityLabel(Text("today.areas.editGoals", bundle: .l10n))
                }

                VStack(spacing: 0) {
                    ForEach(rows) { row in
                        Button { open(row.page) } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: row.name)
                                        .font(DSFont.row)
                                        .foregroundStyle(Color.fg)
                                    Text(verbatim: row.detail)
                                        .font(DSFont.caption)
                                        .foregroundStyle(Color.mutedFg)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 8)
                                VStack(alignment: .trailing, spacing: 5) {
                                    Text(verbatim: row.value)
                                        .font(Font.geistMono(14.5, relativeTo: .subheadline).weight(.medium))
                                        .foregroundStyle(Color.fg)
                                        .lineLimit(1)
                                    // past the goal only Dieta turns red; the others stop full
                                    ProgressLine(row.over ? 1.01 : Double(row.percent) / 100)
                                        .frame(width: 64)
                                }
                            }
                            .padding(.vertical, 13)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .bottom) { Hairline() }
                    }
                }
                .overlay(alignment: .top) { Hairline() }
            }
        }
    }

    struct FeedRow: Identifiable {
        let id: String
        let name: String
        let detail: String
        let value: String
        let page: AppPage
    }

    /// "Atividade recente": the 5 newest entries across the enabled areas.
    private struct Feed: View {
        let rows: [FeedRow]
        let open: (AppPage) -> Void
        @Environment(AppLanguageStore.self) private var language

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                SectionTitle(L10n.string("today.feed.title", lang: language.lang))
                    .accessibilityAddTraits(.isHeader)
                    .padding(.bottom, 6)

                ForEach(rows) { row in
                    Button { open(row.page) } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: row.name)
                                    .font(DSFont.row)
                                    .foregroundStyle(Color.fg)
                                    .lineLimit(1)
                                Text(verbatim: row.detail)
                                    .font(DSFont.caption)
                                    .foregroundStyle(Color.mutedFg)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            Text(verbatim: row.value)
                                .font(Font.geistMono(14.5, relativeTo: .subheadline).weight(.medium))
                                .foregroundStyle(Color.fg)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 13)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .bottom) { Hairline() }
                }

                if rows.isEmpty {
                    Text("today.feed.empty", bundle: .l10n)
                        .font(DSFont.meta)
                        .foregroundStyle(Color.mutedFg)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .overlay(alignment: .bottom) { Hairline() }
                }
            }
        }
    }
}
