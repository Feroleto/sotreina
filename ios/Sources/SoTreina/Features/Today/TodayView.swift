import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// Hoje with 2–3 areas, the web's `TodayPage` (Redesign 18a/21): the day's
/// status per area, the last 7 days of completed areas, each area against its
/// goal (the pencil pushes Perfil's weekly goals) and a mixed feed. Only the
/// enabled areas show. Every number derives from the stores the area tabs
/// already hold (`TodayStatus`), so Hoje never reads a figure the area's own
/// tab wouldn't. A tap opens the area's page in its tab, never a detail.
struct TodayView: View {
    let me: Me
    let workout: WorkoutStore
    let run: RunStore
    let gymHistory: GymHistoryStore
    let diet: DietStore
    let dietHistory: DietHistoryStore
    let profile: ProfileStore
    let onNavigate: (AppPage) -> Void
    /// refreshed on every load: a tab left open past midnight moves to the new day
    @State private var now = Date.now
    @State private var editingGoals = false
    @Environment(AppLanguageStore.self) private var language
    @Environment(\.scenePhase) private var scenePhase

    private let calendar = Calendar.current

    private var areas: [Area] { me.enabledAreas }
    /// a run feed needs Strava; without it Corrida stays empty
    private var readsRuns: Bool { areas.contains(.run) && me.hasStravaAccount }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.pageBg)
            .onPopToRoot { editingGoals = false }
            .navigationDestination(isPresented: $editingGoals) {
                if let settings = profile.settings {
                    WeeklyGoalsView(settings: settings, areas: areas, unit: me.distanceUnit, store: profile)
                        .hidesFloatingTabBar()
                }
            }
            // every time the page shows: a run, workout or Registro from
            // another tab (or the web) must count
            .task { await load() }
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

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: DietFormat.dayHeader(now, lang: lang, calendar: calendar))
                    .font(DSFont.meta)
                    .foregroundStyle(Color.mutedFg)
                    .padding(.top, 12)

                StatusGrid(cells: statusCells(totals: totals, kcalToday: kcalToday, goal: settings.dailyKcalGoal, lang: lang), open: onNavigate)
                    .padding(.top, 22)

                LastDays(
                    days: TodayStatus.buildDays(
                        activities: activities, workouts: workouts, dietPoints: points,
                        kcalGoal: settings.dailyKcalGoal, now: now, calendar: calendar
                    ),
                    dates: TodayStatus.lastNDays(now, 7, calendar: calendar),
                    areas: areas
                )
                .padding(.top, 24)

                ByArea(
                    rows: areaRows(totals: totals, kcalToday: kcalToday, settings: settings, lang: lang),
                    canEdit: profile.settings != nil && (areas.contains(.run) || areas.contains(.gym)),
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

    private func statusCells(totals: TodayStatus.Totals, kcalToday: Double, goal: Int, lang: Lang) -> [StatusCell] {
        let unit = UnitConversion.label(me.distanceUnit)
        return areas.map { area in
            switch area {
            case .run:
                let done = totals.runKmToday > 0
                return StatusCell(
                    area: area, label: L10n.string("today.status.run", lang: lang), done: done,
                    sub: done
                        ? L10n.string("today.status.runDone %@ %@", lang: lang, RunFormat.distance(totals.runKmToday, unit: me.distanceUnit, lang: lang), unit)
                        : L10n.string("today.status.pending", lang: lang),
                    page: .runActivities
                )
            case .gym:
                return StatusCell(
                    area: area, label: L10n.string("today.status.gym", lang: lang),
                    done: !totals.workoutsToday.isEmpty, sub: gymSub(totals, lang: lang), page: .gymOverview
                )
            case .diet:
                return StatusCell(
                    area: area, label: L10n.string("today.status.diet", lang: lang),
                    done: TodayStatus.isDietDone(kcal: kcalToday, goal: goal),
                    sub: "\(DietFormat.integer(Int(kcalToday.rounded()), lang: lang)) / \(DietFormat.integer(goal, lang: lang))",
                    page: .dietOverview
                )
            }
        }
    }

    /// An open workout first, then what's done today, then the next routine.
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
        if let next = RoutineFormat.nextRoutine(workout.templates) {
            return L10n.string("today.status.gymPending %@", lang: lang, next.name)
        }
        return L10n.string("today.status.pending", lang: lang)
    }

    private func areaRows(totals: TodayStatus.Totals, kcalToday: Double, settings: MeSettings, lang: Lang) -> [AreaRow] {
        let unit = me.distanceUnit
        return areas.map { area in
            switch area {
            case .run:
                return AreaRow(
                    area: area, name: L10n.string("today.status.run", lang: lang),
                    detail: L10n.string(
                        "today.areas.runGoal %lld %@", lang: lang,
                        UnitConversion.goalDisplay(km: settings.weeklyRunKmGoal, in: unit), UnitConversion.label(unit)
                    ),
                    value: "\(RunFormat.distance(totals.runKmWeek, unit: unit, lang: lang)) \(UnitConversion.label(unit))",
                    percent: TodayStatus.percent(totals.runKmWeek, of: settings.weeklyRunKmGoal), over: false,
                    page: .runActivities
                )
            case .gym:
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
        let sub: String
        let page: AppPage
        var id: Area { area }
    }

    /// One column per area between two hairlines, split by vertical ones:
    /// a filled mustard check when done, an empty ring otherwise.
    private struct StatusGrid: View {
        let cells: [StatusCell]
        let open: (AppPage) -> Void

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
                            Text(verbatim: cell.sub)
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

    /// "Últimos 7 dias": one column per day, a 20 pt segment per enabled
    /// area, the completed ones stacked from the bottom (today's in mustard).
    private struct LastDays: View {
        let days: [TodayStatus.Day]
        /// the same days as local midnights, for the initials
        let dates: [Date]
        let areas: [Area]
        @Environment(AppLanguageStore.self) private var language

        var body: some View {
            let lang = language.lang
            let initials = RunCalendar.weekdayInitials(lang)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    SectionTitle(L10n.string("today.days.title", lang: lang))
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text("today.days.legend", bundle: .l10n)
                        .font(DSFont.caption)
                        .foregroundStyle(Color.mutedFg)
                }

                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(Array(days.enumerated()), id: \.element.date) { index, day in
                        let count = TodayStatus.countDone(day, areas: areas)
                        let isToday = index == days.count - 1
                        let initial = initials[(Calendar.current.component(.weekday, from: dates[index]) + 5) % 7]
                        VStack(spacing: 8) {
                            VStack(spacing: 3) {
                                ForEach((0..<areas.count).reversed(), id: \.self) { k in
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(k < count ? (isToday ? Color.acc : Color.fg) : Color.border)
                                        .frame(height: 20)
                                }
                            }
                            .frame(height: 72, alignment: .bottom)
                            Text(verbatim: initial)
                                .font(Font.geistMono(10.5, relativeTo: .caption2))
                                .foregroundStyle(Color.mutedFg)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("today.days.a11y \(initial) \(count) \(areas.count)", bundle: .l10n))
                    }
                }
                .padding(.top, 14)
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
