import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// Corrida › Atividades, the web's mobile `Dashboard` (Redesign 17b
/// "Monolito"): this week against the last, the weekly bars and the runs
/// grouped by week. A custom period drives the bars and the list; the hero
/// always stays on the current week. Tapping a run opens nothing yet (the
/// detail is the next ticket).
struct RunActivitiesView: View {
    let store: RunStore
    @Environment(SessionStore.self) private var session
    @Environment(AppLanguageStore.self) private var language
    @State private var range: DateRange?
    @State private var pages = 1
    @State private var selectedBar: Int?
    @State private var pickingRange = false

    private let calendar = Calendar.current

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.pageBg)
            .task { await store.load() }
            .sheet(isPresented: $pickingRange) {
                RangePickerSheet(range: range, earliest: store.activities.map(\.startDate).min()) { picked in
                    range = picked
                    pages = 1
                    selectedBar = nil
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch store.loadState {
        case .idle:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loading where store.activities.isEmpty:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView {
                Label { Text("gym.routines.loadFailed", bundle: .l10n) } icon: { Image(systemName: "wifi.exclamationmark") }
            } description: {
                Text(message)
            } actions: {
                Button { Task { await store.load() } } label: { Text("common.retry", bundle: .l10n) }
                    .buttonStyle(.pill)
            }
        default:
            page
        }
    }

    private var page: some View {
        let lang = language.lang
        let unit = session.distanceUnit
        let unitLabel = UnitConversion.label(unit)
        let hero = RunBins.lastWeeks(store.activities, count: 2, calendar: calendar)
        let (lastWeek, thisWeek) = (hero[0], hero[1])
        let weeks = range.map { RunBins.weeks(in: $0, store.activities, calendar: calendar) }
            ?? RunBins.lastWeeks(store.activities, count: 12, calendar: calendar)
        let list = RunBins.listGroups(weeks, pages: pages)
        let pct = RunBins.percentOfLastWeek(thisKm: thisWeek.km, lastKm: lastWeek.km)

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("dashboard.hero.thisWeek \(RunFormat.weekRange(thisWeek.start, calendar: calendar))", bundle: .l10n)
                    .font(DSFont.meta)
                    .foregroundStyle(Color.mutedFg)
                    .padding(.top, 12)

                BigNumber(RunFormat.distance(thisWeek.km, unit: unit, lang: lang), unit: unitLabel)
                    .padding(.top, 22)

                HStack {
                    if lastWeek.km > 0 {
                        Text("dashboard.hero.lastWeek \(RunFormat.distance(lastWeek.km, unit: unit, lang: lang)) \(unitLabel)", bundle: .l10n)
                    } else {
                        Text("dashboard.hero.noLastWeek", bundle: .l10n)
                    }
                    Spacer()
                    if let pct {
                        Text(verbatim: "\(pct)%").fontWeight(.medium).foregroundStyle(Color.fg)
                    }
                }
                .font(Font.geist(12.5, relativeTo: .caption))
                .foregroundStyle(Color.mutedFg)
                .padding(.top, 12)
                if let pct {
                    // against last week, never past full: there's no goal to overshoot here
                    ProgressLine(min(1, Double(pct) / 100))
                        .padding(.top, 7)
                }

                KPIStrip([
                    KPI(L10n.string("dashboard.kpis.activities", lang: lang), "\(thisWeek.count)"),
                    // the label already says pace; the unit would crowd the column
                    KPI(L10n.string("dashboard.kpis.avgPace", lang: lang),
                        RunFormat.paceValue(thisWeek.km > 0 ? Double(thisWeek.sec) / thisWeek.km : nil, unit: unit)),
                    KPI(L10n.string("dashboard.kpis.time", lang: lang), WorkoutFormat.durationShort(thisWeek.sec)),
                ])
                .padding(.top, 22)

                HStack(alignment: .center) {
                    SectionTitle(L10n.string("dashboard.chart.weeklyVolume", lang: lang))
                    Spacer()
                    Button { pickingRange = true } label: {
                        Label {
                            Text(range.map { RunFormat.rangeLabel($0, lang: lang, calendar: calendar) }
                                ?? L10n.string("dashboard.dateRange.custom", lang: lang))
                        } icon: {
                            Image(systemName: "calendar")
                        }
                    }
                    .buttonStyle(.chip)
                }
                .padding(.top, 24)

                WeeklyBars(weeks: weeks, selected: $selectedBar, unit: unit, calendar: calendar)
                    .padding(.top, 4)

                SectionTitle(L10n.string("dashboard.hero.recent", lang: lang))
                    .padding(.top, 24)
                    .padding(.bottom, 6)

                if let range {
                    RangeChip(range: range, weeks: weeks, unit: unit, calendar: calendar) {
                        self.range = nil
                        pages = 1
                        selectedBar = nil
                    }
                    .padding(.bottom, 20)
                }

                if list.shown.isEmpty {
                    Text("dashboard.list.empty", bundle: .l10n)
                        .font(DSFont.meta)
                        .foregroundStyle(Color.mutedFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    ForEach(list.shown, id: \.start) { week in
                        WeekGroup(week: week, unit: unit, calendar: calendar)
                            .padding(.bottom, 26)
                    }
                }
                if list.olderWeeks > 0 {
                    Button { pages += 1 } label: {
                        Text("dashboard.list.olderWeeks \(list.olderWeeks)", bundle: .l10n)
                            .font(Font.geist(13, relativeTo: .footnote).weight(.medium))
                            .foregroundStyle(Color.mutedFg)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .overlay(alignment: .bottom) { Hairline() }
                }

                PoweredByStrava()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
                    .padding(.bottom, 44)
            }
            .padding(.horizontal, pageGutter)
        }
        .refreshable { await store.load() }
    }
}

/// The 12 weekly bars (or the custom period's weeks): the current week in
/// mustard, a tapped one in the foreground color with its reading above,
/// month names under the first bar of each month.
private struct WeeklyBars: View {
    let weeks: [WeekBin]
    @Binding var selected: Int?
    let unit: DistanceUnit
    let calendar: Calendar
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let lang = language.lang
        let unitLabel = UnitConversion.label(unit)
        let maxKm = max(1, weeks.map(\.km).max() ?? 0)
        let sel = selected.flatMap { weeks.indices.contains($0) ? $0 : nil }

        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let sel {
                    Text("dashboard.chart.barReading \(RunFormat.weekRange(weeks[sel].start, calendar: calendar)) \(RunFormat.distance(weeks[sel].km, unit: unit, lang: lang)) \(unitLabel)", bundle: .l10n)
                        .foregroundStyle(Color.fg)
                } else {
                    Text("dashboard.chart.barHint \(RunFormat.distance(weeks.reduce(0) { $0 + $1.km }, unit: unit, lang: lang)) \(unitLabel) \(weeks.count)", bundle: .l10n)
                        .foregroundStyle(Color.mutedFg)
                }
            }
            .font(DSFont.caption)

            HStack(alignment: .bottom, spacing: 7) {
                ForEach(Array(weeks.enumerated()), id: \.element.start) { index, week in
                    Button {
                        selected = selected == index ? nil : index
                    } label: {
                        GeometryReader { geo in
                            VStack {
                                Spacer(minLength: 0)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(sel == index ? Color.fg : index == weeks.count - 1 ? Color.acc : Color.bar)
                                    // a zero week still shows a sliver, so the weeks read as continuous
                                    .frame(height: max(2, geo.size.height * week.km / maxKm))
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: "\(RunFormat.dayMonth(week.start, calendar: calendar)) · \(RunFormat.distance(week.km, unit: unit, lang: lang)) \(unitLabel)"))
                    .accessibilityAddTraits(sel == index ? .isSelected : [])
                }
            }
            .frame(height: 110)
            .padding(.top, 14)

            HStack(alignment: .top, spacing: 7) {
                ForEach(Array(weeks.enumerated()), id: \.element.start) { index, week in
                    let newMonth = index == 0
                        || calendar.component(.month, from: week.start) != calendar.component(.month, from: weeks[index - 1].start)
                    Text(verbatim: newMonth ? RunFormat.monthShort(week.start, lang: lang, calendar: calendar) : " ")
                        .font(Font.geistMono(10.5, relativeTo: .caption2))
                        .foregroundStyle(Color.mutedFg)
                        .fixedSize()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 8)
        }
    }
}

/// One week of the list: "13/07 – 19/07" and its totals over a hairline,
/// then a row per run.
private struct WeekGroup: View {
    let week: WeekBin
    let unit: DistanceUnit
    let calendar: Calendar
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let lang = language.lang
        let unitLabel = UnitConversion.label(unit)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: RunFormat.weekRange(week.start, calendar: calendar))
                    .font(Font.geistMono(11.5, relativeTo: .caption))
                Spacer()
                Text(verbatim: "\(L10n.string("dashboard.list.runsCount %lld", lang: lang, week.count)) · \(RunFormat.distance(week.km, unit: unit, lang: lang)) \(unitLabel)")
                    .font(Font.geist(12.5, relativeTo: .caption))
            }
            .foregroundStyle(Color.mutedFg)
            .padding(.bottom, 9)
            .overlay(alignment: .bottom) { Hairline() }

            // newest first inside the week too, like the list's order
            ForEach(week.runs.sorted { $0.startDate > $1.startDate }) { run in
                ActivityRow(run: run, unit: unit, calendar: calendar)
                    .overlay(alignment: .bottom) { Hairline() }
            }
        }
    }
}

private struct ActivityRow: View {
    let run: ActivityListItem
    let unit: DistanceUnit
    let calendar: Calendar
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let lang = language.lang
        HStack(spacing: 13) {
            VStack(alignment: .leading, spacing: 2) {
                Text(run.name)
                    .font(DSFont.row)
                    .foregroundStyle(Color.fg)
                    .lineLimit(1)
                Text(verbatim: "\(RunFormat.dayMonth(run.startDate, calendar: calendar)) · \(WorkoutFormat.durationShort(run.movingTimeSec))")
                    .font(DSFont.caption)
                    .foregroundStyle(Color.mutedFg)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(verbatim: run.distanceKm.map { "\(RunFormat.distance($0, unit: unit, lang: lang)) \(UnitConversion.label(unit))" } ?? "—")
                    .font(Font.geistMono(14.5, relativeTo: .subheadline).weight(.medium))
                    .foregroundStyle(Color.fg)
                Text(verbatim: RunFormat.pace(run.paceRawSecKm, unit: unit))
                    .font(Font.geistMono(12, relativeTo: .caption))
                    .foregroundStyle(Color.mutedFg)
            }
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 2)
    }
}

/// "Outubro de 2026  3 corridas · 24,1 km · 31 dias  ×" (the web's RangeChip).
private struct RangeChip: View {
    let range: DateRange
    let weeks: [WeekBin]
    let unit: DistanceUnit
    let calendar: Calendar
    let onClear: () -> Void
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let lang = language.lang
        let count = weeks.reduce(0) { $0 + $1.count }
        let km = weeks.reduce(0) { $0 + $1.km }
        HStack(spacing: 10) {
            Text(verbatim: RunFormat.rangeLabel(range, lang: lang, calendar: calendar))
                .font(Font.geist(12.5, relativeTo: .caption).weight(.semibold))
                .foregroundStyle(Color.accTx)
            Text(verbatim: "\(L10n.string("dashboard.list.runsCount %lld", lang: lang, count)) · \(RunFormat.distance(km, unit: unit, lang: lang)) \(UnitConversion.label(unit)) · \(L10n.string("dashboard.rangeChip.daysCount %lld", lang: lang, RunBins.days(in: range, calendar: calendar)))")
                .font(DSFont.caption)
                .foregroundStyle(Color.mutedFg)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Button(action: onClear) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.mutedFg)
                    .frame(width: 24, height: 24)
            }
            .accessibilityLabel(Text("dashboard.rangeChip.clearAriaLabel", bundle: .l10n))
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .padding(.vertical, 4)
        .background(Color.accBg, in: Capsule())
    }
}

/// The period picker as a native sheet: the web's presets (those that fit
/// in 3 months, like its mobile picker), then a start/end pair for a custom
/// range capped at 3 months — the web's two-tap calendar has no native
/// counterpart.
private struct RangePickerSheet: View {
    let range: DateRange?
    let earliest: Date?
    let onPick: (DateRange?) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(AppLanguageStore.self) private var language
    @State private var start: Date
    @State private var end: Date

    private static let maxMonths = 3
    private let calendar = Calendar.current

    init(range: DateRange?, earliest: Date?, onPick: @escaping (DateRange?) -> Void) {
        self.range = range
        self.earliest = earliest
        self.onPick = onPick
        let today = Calendar.current.startOfDay(for: .now)
        _start = State(initialValue: range?.start ?? Calendar.current.date(byAdding: .month, value: -1, to: today)!)
        _end = State(initialValue: range?.end ?? today)
    }

    var body: some View {
        let lang = language.lang
        let today = calendar.startOfDay(for: .now)
        let minDate = earliest.map { calendar.startOfDay(for: $0) } ?? .distantPast
        NavigationStack {
            Form {
                Section {
                    ForEach(RunBins.presets(calendar: calendar, maxMonths: Self.maxMonths), id: \.0) { preset, presetRange in
                        Button {
                            pick(presetRange)
                        } label: {
                            HStack {
                                Text(L10n.string("dashboard.dateRange.\(preset.rawValue)", lang: lang)).foregroundStyle(Color.fg)
                                Spacer()
                                if presetRange == range {
                                    Image(systemName: "checkmark").foregroundStyle(Color.accTx)
                                }
                            }
                        }
                    }
                }
                Section {
                    DatePicker(selection: $start, in: minDate...today, displayedComponents: .date) {
                        Text("dashboard.dateRange.start", bundle: .l10n)
                    }
                    DatePicker(selection: $end, in: start...min(today, RunBins.cappedEnd(start: start, end: today, maxMonths: Self.maxMonths, calendar: calendar)), displayedComponents: .date) {
                        Text("dashboard.dateRange.end", bundle: .l10n)
                    }
                    Button {
                        pick(DateRange(
                            start: calendar.startOfDay(for: start),
                            end: RunBins.cappedEnd(start: calendar.startOfDay(for: start), end: calendar.startOfDay(for: end), maxMonths: Self.maxMonths, calendar: calendar)
                        ))
                    } label: {
                        Text("dashboard.dateRange.apply", bundle: .l10n)
                    }
                    .disabled(end < start)
                } header: {
                    Text("dashboard.dateRange.custom", bundle: .l10n)
                        .font(DSFont.sectionTitle)
                        .foregroundStyle(Color.fg)
                        .textCase(nil)
                }
                if range != nil {
                    Section {
                        Button(role: .destructive) { pick(nil) } label: {
                            Text("dashboard.dateRange.clean", bundle: .l10n)
                        }
                    }
                }
            }
            .monolitoForm()
            .environment(\.locale, Locale(identifier: lang.localeIdentifier))
            .navigationTitle(Text("dashboard.chart.weeklyVolume", bundle: .l10n))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("dashboard.dateRange.close", bundle: .l10n) }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func pick(_ picked: DateRange?) {
        onPick(picked)
        dismiss()
    }
}
