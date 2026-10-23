import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// Treino › Visão geral, the web's `GymOverviewPage` (Redesign 18b
/// "Monolito"): the week in one number against last week, "Próximo treino"
/// (or the open one) with a single primary action, the routines as hairline
/// rows, then the month calendar and the personal-record search.
/// A routine row pushes its detail right here (the web jumps to Rotinas);
/// "+ Nova" opens the editor.
struct GymOverviewView: View {
    let store: WorkoutStore
    let history: GymHistoryStore
    @State private var viewingId: String?
    @State private var creating = false

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.pageBg)
            .navigationDestination(item: $viewingId) { id in
                if let template = store.templates.first(where: { $0.id == id }) {
                    RoutineDetailView(template: template, store: store)
                }
            }
            .fullScreenCover(isPresented: $creating) {
                RoutineEditView(template: nil, store: store)
                    .monolitoTheme()
            }
            // every time the page shows: a workout finished since then must count
            .task { await history.load() }
    }

    @ViewBuilder private var content: some View {
        switch history.loadState {
        case .idle:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loading where history.items.isEmpty:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView {
                Label { Text("gym.overview.loadFailed", bundle: .l10n) } icon: { Image(systemName: "wifi.exclamationmark") }
            } description: {
                Text(message)
            } actions: {
                Button { Task { await history.load() } } label: { Text("common.retry", bundle: .l10n) }
                    .buttonStyle(.pill)
            }
        default:
            page
        }
    }

    private var page: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                WeekHero(week: GymWeek.make(history.items), unit: history.weightUnit)

                NextWorkout(store: store)

                RoutinesSection(store: store, onOpen: { viewingId = $0 }, onNew: { creating = true })
                    .padding(.top, 24)

                GymMonthCalendar(items: history.items, unit: history.weightUnit)
                    .padding(.top, 32)

                PersonalRecordSection(history: history)
                    .padding(.top, 24)
                    .padding(.bottom, 44)
            }
            .padding(.horizontal, pageGutter)
        }
        .refreshable {
            async let workouts: Void = history.load()
            async let routines: Void = store.load()
            _ = await (workouts, routines)
        }
    }
}

// MARK: - Week

/// "Esta semana · 19/10 – 25/10", the count in Geist Mono 64, last week with
/// the share and its progress line, then Volume / Exercícios / Tempo.
private struct WeekHero: View {
    let week: GymWeek
    let unit: WeightUnit
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let lang = language.lang
        VStack(alignment: .leading, spacing: 0) {
            Text("gym.overview.thisWeek \(RunFormat.weekRange(week.start, calendar: .current))", bundle: .l10n)
                .font(DSFont.meta)
                .foregroundStyle(Color.mutedFg)
                .padding(.top, 12)

            BigNumber("\(week.count)", unit: L10n.string("gym.overview.workouts %lld", lang: lang, week.count))
                .padding(.top, 22)

            HStack {
                if week.lastWeekCount > 0 {
                    Text("gym.overview.lastWeek \(week.lastWeekCount)", bundle: .l10n)
                } else {
                    Text("gym.overview.noLastWeek", bundle: .l10n)
                }
                Spacer()
                if let pct = week.percentOfLastWeek {
                    Text(verbatim: "\(pct)%").fontWeight(.medium).foregroundStyle(Color.fg)
                }
            }
            .font(Font.geist(12.5, relativeTo: .caption))
            .foregroundStyle(Color.mutedFg)
            .padding(.top, 12)
            if let pct = week.percentOfLastWeek {
                // against last week, never past full: there's no goal to overshoot
                ProgressLine(min(1, Double(pct) / 100))
                    .padding(.top, 7)
            }

            KPIStrip([
                KPI(L10n.string("gym.history.kpiVolume", lang: lang), WorkoutFormat.volume(week.volumeKg, unit: unit, lang: lang)),
                KPI(L10n.string("gym.overview.exercises", lang: lang), "\(week.exercises)"),
                KPI(L10n.string("gym.history.kpiTime", lang: lang), WorkoutFormat.durationShort(week.durationSec)),
            ])
            .padding(.top, 22)
        }
    }
}

/// "última vez hoje" | "ainda não realizada" (`routines.lastPerformed`)
private func lastDone(_ template: TemplateSummary, _ lang: Lang) -> String {
    guard template.lastPerformedAt != nil else { return RoutineFormat.lastPerformed(nil, lang: lang) }
    return L10n.string("gym.routineDetail.lastPerformed %@", lang: lang, RoutineFormat.lastPerformed(template.lastPerformedAt, lang: lang))
}

// MARK: - Next workout

/// "Próximo treino" = the routine done longest ago, with "Iniciar"; an open
/// workout takes the slot as "Treino em andamento" with "Continuar".
private struct NextWorkout: View {
    let store: WorkoutStore
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let lang = language.lang
        let next = store.templates.first { $0.id == store.nextRoutineId }
        if let active = store.active {
            slot(
                title: "gym.overview.inProgress",
                name: active.templateName ?? L10n.string("gym.freeWorkout", lang: lang),
                meta: nil,
                button: "gym.overview.resume",
                busy: false
            ) { store.sessionMinimized = false }
        } else if let next {
            slot(
                title: "gym.overview.next",
                name: next.name,
                meta: "\(L10n.string("gym.routines.exerciseCount %lld", lang: lang, next.exerciseCount)) · \(lastDone(next, lang))",
                button: "gym.overview.start",
                busy: store.startingTemplateId == next.id
            ) { Task { await store.start(templateId: next.id) } }
        }
    }

    private func slot(title: LocalizedStringKey, name: String, meta: String?, button: LocalizedStringKey, busy: Bool, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title, bundle: .l10n)
                .font(DSFont.sectionTitle)
                .foregroundStyle(Color.fg)
                .padding(.top, 24)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(DSFont.rowTitle)
                        .tracking(-0.17)
                        .foregroundStyle(Color.fg)
                        .lineLimit(1)
                    if let meta {
                        Text(verbatim: meta)
                            .font(DSFont.caption)
                            .foregroundStyle(Color.mutedFg)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Button(action: action) {
                    if busy {
                        ProgressView().tint(Color.accFg).frame(minWidth: 52)
                    } else {
                        Text(button, bundle: .l10n).frame(minWidth: 52)
                    }
                }
                .buttonStyle(.pill)
                .disabled(store.startingTemplateId != nil)
            }
            .padding(.vertical, 16)
            .overlay(alignment: .bottom) { Hairline() }
            .padding(.top, 10)
        }
    }
}

// MARK: - Routines

/// "Rotinas  + Nova", then one hairline row per routine with a chevron.
private struct RoutinesSection: View {
    let store: WorkoutStore
    let onOpen: (String) -> Void
    let onNew: () -> Void
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let lang = language.lang
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionTitle(L10n.string("gym.overview.routines", lang: lang))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: onNew) {
                    Text(verbatim: "+ \(L10n.string("gym.overview.newRoutine", lang: lang))")
                        .font(Font.geist(12.5, relativeTo: .caption).weight(.medium))
                        .foregroundStyle(Color.mutedFg)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, -8)
            }

            ForEach(store.templates) { template in
                Button { onOpen(template.id) } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.name)
                                .font(DSFont.row)
                                .foregroundStyle(Color.fg)
                                .lineLimit(1)
                            Text(verbatim: "\(L10n.string("gym.routines.exerciseCount %lld", lang: lang, template.exerciseCount)) · \(lastDone(template, lang))")
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

            if store.loadState == .loaded, store.templates.isEmpty {
                Text("gym.overview.routinesEmpty", bundle: .l10n)
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

// MARK: - Calendar

/// `GymCalendar`, mobile: training days in mustard, today ringed, the
/// future faded; tapping a training day reads it in the footer, otherwise
/// the footer sums the month. 34 pt cells and a 28 pt circle (Corrida's are
/// 40/32), as on the web.
private struct GymMonthCalendar: View {
    let items: [WorkoutHistoryItem]
    let unit: WeightUnit
    @State private var visibleMonth = RunCalendar.monthStart(.now, calendar: .current)
    @State private var selectedDay: Date?
    @Environment(AppLanguageStore.self) private var language

    private let calendar = Calendar.current

    var body: some View {
        let lang = language.lang
        let month = GymCalendarMonth.make(visibleMonth, items: items, calendar: calendar)
        let earliest = items.map(\.startedAt).min()
        let today = calendar.startOfDay(for: .now)

        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(verbatim: RunFormat.calendarTitle(visibleMonth, lang: lang, calendar: calendar))
                    .font(Font.geist(13.5, relativeTo: .subheadline).weight(.semibold))
                    .foregroundStyle(Color.fg)
                Spacer()
                HStack(spacing: 4) {
                    navButton("chevron.left", label: "overview.calendar.previousMonth",
                              enabled: RunCalendar.canGoBack(from: visibleMonth, earliest: earliest, calendar: calendar)) { step(-1) }
                    navButton("chevron.right", label: "overview.calendar.nextMonth",
                              enabled: RunCalendar.canGoForward(from: visibleMonth, calendar: calendar)) { step(1) }
                }
            }

            // plain rows, not a LazyVGrid (same reason as Corrida's calendar)
            HStack(spacing: 0) {
                ForEach(Array(RunCalendar.weekdayInitials(lang).enumerated()), id: \.offset) { _, initial in
                    Text(verbatim: initial)
                        .font(Font.geist(10, relativeTo: .caption2).weight(.semibold))
                        .foregroundStyle(Color.mutedFg)
                        .frame(maxWidth: .infinity, minHeight: 20)
                }
            }
            .padding(.top, 12)

            ForEach(Array(stride(from: 0, to: month.cells.count, by: 7)), id: \.self) { start in
                HStack(spacing: 0) {
                    ForEach(start..<start + 7, id: \.self) { index in
                        if index < month.cells.count, let day = month.cells[index] {
                            dayCell(day, hasWorkouts: month.workoutsByDay[day] != nil, today: today)
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: 34)
                        }
                    }
                }
            }

            Text(verbatim: footer(month, lang: lang))
                .font(DSFont.caption)
                .foregroundStyle(Color.mutedFg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
                .overlay(alignment: .top) { Hairline() }
                .padding(.top, 12)
        }
        .padding(.vertical, 16)
        .overlay(alignment: .top) { Hairline() }
    }

    private func dayCell(_ day: Date, hasWorkouts: Bool, today: Date) -> some View {
        let number = calendar.component(.day, from: day)
        let isToday = day == today
        let isFuture = day > today
        return Button {
            guard hasWorkouts else { return }
            selectedDay = selectedDay == day ? nil : day
        } label: {
            Text(verbatim: "\(number)")
                .font(Font.geist(12.5, relativeTo: .footnote).weight(hasWorkouts ? .semibold : .regular))
                .foregroundStyle(hasWorkouts ? Color.accFg : isFuture ? Color.mutedFg.opacity(0.4) : Color.fg)
                .frame(width: 28, height: 28)
                .background { if hasWorkouts { Circle().fill(Color.acc) } }
                .overlay { if isToday && !hasWorkouts { Circle().strokeBorder(Color.acc, lineWidth: 1.5) } }
                .frame(maxWidth: .infinity, minHeight: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // not .disabled: that would fade the plain days, which read in the text color
        .allowsHitTesting(hasWorkouts)
        .accessibilityAddTraits(selectedDay == day ? .isSelected : [])
    }

    private func navButton(_ icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.mutedFg)
                .frame(width: 32, height: 32)
                .background(Color.chip, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(Text(LocalizedStringKey(label), bundle: .l10n))
    }

    private func step(_ months: Int) {
        selectedDay = nil
        visibleMonth = calendar.date(byAdding: .month, value: months, to: visibleMonth)!
    }

    private func footer(_ month: GymCalendarMonth, lang: Lang) -> String {
        switch month.footer(selectedDay: selectedDay) {
        case .day(let item):
            return L10n.string(
                "gym.calendar.daySingle %@ %@ %@", lang: lang,
                RunFormat.monthDay(item.startedAt, lang: lang, calendar: calendar),
                item.templateName ?? L10n.string("gym.freeWorkout", lang: lang),
                WorkoutFormat.volume(item.volumeKg, unit: unit, lang: lang)
            )
        case .days(let count, let volumeKg):
            return L10n.string("gym.calendar.dayMulti %lld %@", lang: lang, count, WorkoutFormat.volume(volumeKg, unit: unit, lang: lang))
        case .month(let count, let volumeKg):
            return L10n.string(
                "gym.calendar.monthSummary %lld %@ %@", lang: lang,
                count, WorkoutFormat.volume(volumeKg, unit: unit, lang: lang),
                RunFormat.monthName(month.start, lang: lang, calendar: calendar)
            )
        }
    }
}

// MARK: - Personal record

/// `GymPersonalRecordCard`: pick any exercise (the session's picker) and read
/// the heaviest set ever logged for it, and in which workout. Not kept
/// between visits, like the web.
private struct PersonalRecordSection: View {
    let history: GymHistoryStore
    @State private var picking = false
    @State private var exercise: ExerciseListItem?
    @State private var state: RecordState = .loading
    @Environment(AppLanguageStore.self) private var language

    private enum RecordState: Equatable {
        case loading
        case loaded(ExercisePersonalRecord?)
        case failed(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("gym.records.title", bundle: .l10n)
                    .font(Font.geist(13.5, relativeTo: .subheadline).weight(.semibold))
                    .foregroundStyle(Color.fg)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button { picking = true } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.mutedFg)
                        .frame(width: 32, height: 32)
                        .background(Color.chip, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("gym.records.searchLabel", bundle: .l10n))
            }

            if let exercise {
                Button { picking = true } label: { recordRow(exercise) }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
            } else {
                Button { picking = true } label: {
                    Text("gym.records.emptyPrompt", bundle: .l10n)
                        .font(Font.geist(12.5, relativeTo: .footnote).weight(.medium))
                        .foregroundStyle(Color.mutedFg)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 12)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
            }
        }
        .padding(.top, 16)
        .overlay(alignment: .top) { Hairline() }
        .sheet(isPresented: $picking) {
            ExercisePickerView(title: "gym.records.searchLabel") { picked in
                exercise = picked
            }
            .monolitoTheme()
        }
        .task(id: exercise?.id) { await load() }
    }

    private func load() async {
        guard let exercise else { return }
        state = .loading
        switch await history.personalRecord(exerciseId: exercise.id) {
        case .success(let record): state = .loaded(record)
        // nil message: the session expired, the app is going back to login
        case .failure(let error): state = .failed(error.message ?? "")
        }
    }

    @ViewBuilder
    private func recordRow(_ exercise: ExerciseListItem) -> some View {
        let lang = language.lang
        let unit = history.weightUnit
        HStack(spacing: 12) {
            let found: ExercisePersonalRecord? = if case .loaded(let record) = state { record } else { nil }
            Image(systemName: "dumbbell")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(found != nil ? Color.acc : Color.mutedFg)
                .frame(width: 36, height: 36)
                .background(found != nil ? Color.acc.opacity(0.1) : Color.chip, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(Font.geist(13.5, relativeTo: .subheadline).weight(.semibold))
                    .foregroundStyle(Color.fg)
                    .lineLimit(1)
                Group {
                    switch state {
                    case .loading:
                        Text("gym.records.loading", bundle: .l10n)
                    case .failed(let message):
                        Text(verbatim: message)
                    case .loaded(let record?):
                        Text("gym.records.meta \(RunFormat.monthDay(record.startedAt, lang: lang, calendar: .current)) \(record.templateName ?? L10n.string("gym.freeWorkout", lang: lang))", bundle: .l10n)
                    case .loaded(nil):
                        Text("gym.records.noRecordYet", bundle: .l10n)
                    }
                }
                .font(Font.geist(11.5, relativeTo: .caption))
                .foregroundStyle(Color.mutedFg)
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let found {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(verbatim: "\(WorkoutFormat.weight(found.weightKg, unit: unit, lang: lang)) \(UnitConversion.label(unit))")
                        .font(Font.geist(15, relativeTo: .subheadline).weight(.bold))
                        .foregroundStyle(Color.fg)
                    Group {
                        if let reps = found.reps {
                            Text("gym.records.reps \(reps)", bundle: .l10n)
                        } else {
                            Text(verbatim: "—")
                        }
                    }
                    .font(Font.geist(11, relativeTo: .caption2))
                    .foregroundStyle(Color.mutedFg)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
