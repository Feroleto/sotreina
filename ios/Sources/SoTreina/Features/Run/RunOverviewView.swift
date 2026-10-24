import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// Corrida › Visão geral, the web's mobile `RunOverviewPage` (Redesign 17b
/// "Monolito"): all-time totals in a hairline grid, the month calendar, the
/// headline records (all 12 in a sheet), the shoes carousel and "Powered by
/// Strava". A top 1 that changed since this device last looked gets the
/// "Novo" badge and a spring pop on its chip.
struct RunOverviewView: View {
    let store: RunStore
    @Environment(SessionStore.self) private var session
    @Environment(AppLanguageStore.self) private var language
    @State private var showingAllRecords = false

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.pageBg)
            .task {
                async let activities: Void = store.load()
                async let overview: Void = store.loadOverview()
                _ = await (activities, overview)
            }
            .sheet(isPresented: $showingAllRecords) {
                AllRecordsSheet(store: store, unit: session.distanceUnit)
                    .monolitoTheme()
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
                Label { Text("overview.loadFailed", bundle: .l10n) } icon: { Image(systemName: "wifi.exclamationmark") }
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
        let unit = session.distanceUnit
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TotalsGrid(totals: RunTotals.compute(store.activities), unit: unit)
                    .padding(.top, 20)

                MonthCalendar(runs: store.activities, unit: unit)
                    .padding(.top, 26)

                RecordsSection(store: store, unit: unit) { showingAllRecords = true }
                    .padding(.top, 26)

                if let gear = store.gear {
                    ShoesSection(gear: gear, unit: unit)
                        .padding(.top, 26)
                }

                PoweredByStrava()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
                    .padding(.bottom, 44)
            }
            .padding(.horizontal, pageGutter)
        }
        .refreshable {
            async let activities: Void = store.load()
            async let overview: Void = store.loadOverview()
            _ = await (activities, overview)
        }
        .floatingTabBarScroll()
    }
}

// MARK: - Totals

/// The mobile 2×2 hairline grid: no cards, numbers in Geist Mono.
private struct TotalsGrid: View {
    let totals: RunTotals?
    let unit: DistanceUnit
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let lang = language.lang
        let label = UnitConversion.label(unit)
        let calendar = Calendar.current
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                cell(
                    L10n.string("overview.tiles.distance", lang: lang),
                    "\(RunFormat.distance(totals?.totalKm ?? 0, unit: unit, lang: lang)) \(label)",
                    totals.map { L10n.string("overview.tiles.kmPerWeek %@ %@", lang: lang, RunFormat.distance($0.kmPerWeek, unit: unit, lang: lang), label) },
                    leading: false
                )
                cell(
                    L10n.string("overview.tiles.activities", lang: lang),
                    "\(totals?.count ?? 0)",
                    totals.map { L10n.string("overview.tiles.since %@", lang: lang, RunFormat.monthShortYear($0.earliest, lang: lang, calendar: calendar)) },
                    leading: true
                )
            }
            .fixedSize(horizontal: false, vertical: true)
            Hairline()
            HStack(spacing: 0) {
                cell(L10n.string("overview.tiles.avgPaceLabel", lang: lang), RunFormat.pace(totals?.avgPaceSecKm, unit: unit), nil, leading: false)
                cell(L10n.string("overview.tiles.totalTime", lang: lang), RunFormat.durationLong(totals?.totalSec ?? 0), nil, leading: true)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .overlay(alignment: .top) { Hairline() }
        .overlay(alignment: .bottom) { Hairline() }
    }

    /// the right column draws the vertical divider
    private func cell(_ label: String, _ value: String, _ sub: String?, leading divider: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(DSFont.caption)
                .foregroundStyle(Color.mutedFg)
            Text(verbatim: value)
                .font(DSFont.kpiValue)
                .foregroundStyle(Color.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 4)
            if let sub {
                Text(verbatim: sub)
                    .font(Font.geist(11.5, relativeTo: .caption))
                    .foregroundStyle(Color.mutedFg)
                    .lineLimit(1)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.vertical, 14)
        .padding(.leading, divider ? 14 : 0)
        .overlay(alignment: .leading) { if divider { Hairline(axis: .vertical) } }
    }
}

// MARK: - Calendar

/// `RunCalendar`, mobile: a month with the training days in mustard, today
/// ringed, the future faded. Tapping a training day reads it in the footer;
/// otherwise the footer sums the month.
private struct MonthCalendar: View {
    let runs: [ActivityListItem]
    let unit: DistanceUnit
    @State private var visibleMonth = RunCalendar.monthStart(.now, calendar: .current)
    @State private var selectedDay: Date?
    @Environment(AppLanguageStore.self) private var language

    private let calendar = Calendar.current

    var body: some View {
        let lang = language.lang
        let month = RunCalendarMonth.make(visibleMonth, runs: runs, calendar: calendar)
        let earliest = runs.map(\.startDate).min()
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

            // plain rows, not a LazyVGrid: a lazy grid's height estimates
            // inside the ScrollView shifted the page's initial scroll offset
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
                            dayCell(day, hasRuns: month.runsByDay[day] != nil, today: today)
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: 40)
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
        .padding(.vertical, 18)
        .overlay(alignment: .top) { Hairline() }
    }

    private func dayCell(_ day: Date, hasRuns: Bool, today: Date) -> some View {
        let number = calendar.component(.day, from: day)
        let isToday = day == today
        let isFuture = day > today
        return Button {
            guard hasRuns else { return }
            selectedDay = selectedDay == day ? nil : day
        } label: {
            Text(verbatim: "\(number)")
                .font(Font.geist(13, relativeTo: .footnote).weight(hasRuns ? .semibold : .regular))
                .foregroundStyle(hasRuns ? Color.accFg : isFuture ? Color.mutedFg.opacity(0.4) : Color.fg)
                .frame(width: 32, height: 32)
                .background { if hasRuns { Circle().fill(Color.acc) } }
                .overlay { if isToday && !hasRuns { Circle().strokeBorder(Color.acc, lineWidth: 1.5) } }
                .frame(maxWidth: .infinity, minHeight: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // not .disabled: that would fade the plain days, which read in the text color
        .allowsHitTesting(hasRuns)
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

    private func footer(_ month: RunCalendarMonth, lang: Lang) -> String {
        let label = UnitConversion.label(unit)
        if let selectedDay, let list = month.runsByDay[selectedDay] {
            let km = list.reduce(0) { $0 + ($1.distanceKm ?? 0) }
            if list.count > 1 {
                return L10n.string("overview.calendar.dayMultiRuns %lld %@ %@", lang: lang, list.count, RunFormat.distance(km, unit: unit, lang: lang), label)
            }
            let run = list[0]
            return L10n.string(
                "overview.calendar.daySingleRun %@ %@ %@ %@ %@", lang: lang,
                RunFormat.monthDay(run.startDate, lang: lang, calendar: calendar), run.name,
                RunFormat.distance(km, unit: unit, lang: lang), label, RunFormat.pace(run.paceRawSecKm, unit: unit)
            )
        }
        return L10n.string(
            "overview.calendar.monthSummary %lld %@ %@ %@", lang: lang,
            month.count, RunFormat.distance(month.km, unit: unit, lang: lang), label,
            RunFormat.monthName(month.start, lang: lang, calendar: calendar)
        )
    }
}

// MARK: - Records

/// "Recordes pessoais  [Ver todos]", the 1k/5k/10k rows and the longest run.
private struct RecordsSection: View {
    let store: RunStore
    let unit: DistanceUnit
    let showAll: () -> Void
    @Environment(AppLanguageStore.self) private var language
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let lang = language.lang
        let byKey = PersonalRecords.byDistance(store.records)
        let names = Dictionary(store.activities.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("overview.records.title", bundle: .l10n)
                    .font(Font.geist(13.5, relativeTo: .subheadline).weight(.semibold))
                    .foregroundStyle(Color.fg)
                Spacer()
                Button(action: showAll) {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet").font(.system(size: 11, weight: .medium))
                        Text("overview.records.viewAll", bundle: .l10n)
                    }
                    .font(Font.geist(11.5, relativeTo: .caption).weight(.medium))
                    .foregroundStyle(Color.fg)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 28)
                    .background(Color.chip, in: Capsule())
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 4)

            ForEach(PersonalRecords.distances.filter { PersonalRecords.headlineKeys.contains($0.key) }, id: \.key) { def in
                RecordRow(
                    distance: def, best: byKey[def.key]?.first, activityName: byKey[def.key]?.first.flatMap { names[$0.activityId] },
                    isNew: store.newRecordKeys.contains(def.key), unit: unit
                )
                .overlay(alignment: .bottom) { Hairline() }
            }

            if let longest = PersonalRecords.longestRun(store.activities) {
                HStack(spacing: 12) {
                    RecordChip(text: L10n.string("overview.records.max", lang: lang), filled: true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("overview.records.longestRun", bundle: .l10n)
                            .font(Font.geist(13.5, relativeTo: .subheadline).weight(.semibold))
                            .foregroundStyle(Color.fg)
                        let date = RunFormat.monthDayYear(longest.startDate, lang: lang, calendar: .current)
                        Group {
                            if typeSize >= .xxLarge {
                                Text(longest.name).lineLimit(1)
                                Text(verbatim: date).fixedSize()
                            } else {
                                Text(verbatim: "\(longest.name) · \(date)").lineLimit(1)
                            }
                        }
                        .font(Font.geist(11.5, relativeTo: .caption))
                        .foregroundStyle(Color.mutedFg)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(verbatim: "\(RunFormat.distance(longest.distanceKm ?? 0, unit: unit, lang: lang)) \(UnitConversion.label(unit))")
                            .font(Font.geist(15, relativeTo: .subheadline).weight(.bold))
                            .foregroundStyle(Color.fg)
                        Text(verbatim: WorkoutFormat.durationShort(longest.movingTimeSec))
                            .font(Font.geist(11, relativeTo: .caption2))
                            .foregroundStyle(Color.mutedFg)
                    }
                }
                .padding(.top, 12)
            }
        }
        .padding(.top, 18)
        .overlay(alignment: .top) { Hairline() }
    }
}

/// One distance: chip, title (+ "Novo"), the effort's run and date, time and pace.
private struct RecordRow: View {
    let distance: RecordDistance
    let best: PersonalBestRecord?
    let activityName: String?
    let isNew: Bool
    let unit: DistanceUnit
    /// the sheet's rows expand to the runners-up
    var expandable = false
    var expanded = false
    /// the sheet's layout: run name and date on separate lines
    var stacked = false
    @Environment(AppLanguageStore.self) private var language
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let lang = language.lang
        HStack(spacing: 12) {
            RecordChip(text: distance.chip, filled: best != nil, celebrate: isNew)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(L10n.string(distance.titleKey, lang: lang))
                        .font(Font.geist(13.5, relativeTo: .subheadline).weight(.semibold))
                        .foregroundStyle(Color.fg)
                    if isNew { NewBadge() }
                }
                Group {
                    if let best {
                        let date = RunFormat.monthDayYear(best.startDate, lang: lang, calendar: .current)
                        // large text stacks too: inline, the date would be what truncates
                        if stacked || typeSize >= .xxLarge {
                            // the sheet's RecordCell: name and date on their own
                            // lines, so the date is never the part that truncates
                            if let activityName { Text(activityName).lineLimit(1) }
                            Text(verbatim: date).fixedSize()
                        } else {
                            Text(verbatim: [activityName, date].compactMap { $0 }.joined(separator: " · ")).lineLimit(1)
                        }
                    } else {
                        Text("overview.records.noRecordYet", bundle: .l10n)
                    }
                }
                .font(Font.geist(11.5, relativeTo: .caption))
                .foregroundStyle(Color.mutedFg)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text(verbatim: best.map { RunFormat.hms($0.movingTime) } ?? "—")
                    .font(Font.geist(15, relativeTo: .subheadline).weight(.bold))
                    .foregroundStyle(Color.fg)
                if let best {
                    Text(verbatim: RunFormat.pace(best.paceSecKm, unit: unit))
                        .font(Font.geist(11.5, relativeTo: .caption))
                        .foregroundStyle(Color.mutedFg)
                }
            }
            if expandable {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.mutedFg)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
            }
        }
        .padding(.vertical, 11)
    }
}

/// 38×38 rounded tile: mustard on a 10% mustard tint, or muted on the chip
/// color without a record. A new record pops in on a spring (no glow, unlike
/// the web), once per appearance; reduced motion skips it.
private struct RecordChip: View {
    let text: String
    let filled: Bool
    var celebrate = false
    @State private var popped = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(verbatim: text)
            .font(Font.geist(10.5, relativeTo: .caption2).weight(.bold))
            .foregroundStyle(filled ? Color.acc : Color.mutedFg)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            // a fixed 38-pt tile: its label stops growing before it overflows
            .dynamicTypeSize(...DynamicTypeSize.large)
            .frame(width: 38, height: 38)
            .background(filled ? Color.acc.opacity(0.1) : Color.chip, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .scaleEffect(celebrate && !reduceMotion && !popped ? 0.6 : 1)
            .onAppear {
                guard celebrate, !reduceMotion, !popped else { return }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.5).delay(0.15)) { popped = true }
            }
    }
}

private struct NewBadge: View {
    var body: some View {
        Text("overview.records.newBadge", bundle: .l10n)
            .font(Font.geist(9.5, relativeTo: .caption2).weight(.bold))
            .foregroundStyle(Color.accFg)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Color.acc, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .fixedSize()
    }
}

/// "Todos os recordes pessoais": the 12 distances; a row with runners-up
/// expands to the 2º and 3º, with "PR" where Strava called it one back then.
private struct AllRecordsSheet: View {
    let store: RunStore
    let unit: DistanceUnit
    @State private var expanded: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let lang = language.lang
        let byKey = PersonalRecords.byDistance(store.records)
        let names = Dictionary(store.activities.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(PersonalRecords.distances, id: \.key) { def in
                        let list = byKey[def.key] ?? []
                        let runnersUp = Array(list.dropFirst())
                        VStack(alignment: .leading, spacing: 0) {
                            Button {
                                guard !runnersUp.isEmpty else { return }
                                withAnimation(.easeOut(duration: 0.15)) { expanded = expanded == def.key ? nil : def.key }
                            } label: {
                                RecordRow(
                                    distance: def, best: list.first, activityName: list.first.flatMap { names[$0.activityId] },
                                    isNew: store.newRecordKeys.contains(def.key), unit: unit,
                                    expandable: !runnersUp.isEmpty, expanded: expanded == def.key, stacked: true
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if expanded == def.key {
                                ForEach(runnersUp, id: \.rank) { record in
                                    RunnerUpRow(record: record, activityName: names[record.activityId])
                                }
                                .padding(.bottom, 12)
                            }
                        }
                        .overlay(alignment: .bottom) { Hairline() }
                    }
                }
                .padding(.horizontal, pageGutter)
            }
            .background(Color.card)
            .environment(\.locale, Locale(identifier: lang.localeIdentifier))
            .navigationTitle(Text("overview.records.allRecordsTitle", bundle: .l10n))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("overview.records.close", bundle: .l10n) }
                }
            }
        }
        .presentationDetents([.large])
    }
}

/// "2º  21:58  Evening Run · nov 3, 2025  [PR]"
private struct RunnerUpRow: View {
    let record: PersonalBestRecord
    let activityName: String?
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let lang = language.lang
        HStack(spacing: 8) {
            Text(verbatim: "\(record.rank)º")
                .fontWeight(.semibold)
                .foregroundStyle(Color.mutedFg)
                .frame(width: 18, alignment: .leading)
            Text(verbatim: RunFormat.hms(record.movingTime))
                .fontWeight(.semibold)
                .foregroundStyle(Color.fg)
            // the run's name truncates, the date never does
            HStack(spacing: 0) {
                if let activityName {
                    Text(verbatim: "\(activityName) · ").lineLimit(1)
                }
                Text(verbatim: RunFormat.monthDayYear(record.startDate, lang: lang, calendar: .current))
                    .fixedSize()
            }
            .foregroundStyle(Color.mutedFg)
            Spacer(minLength: 0)
            if record.prRank == 1 {
                Text("overview.records.prBadge", bundle: .l10n)
                    .font(Font.geist(9.5, relativeTo: .caption2).weight(.bold))
                    .foregroundStyle(Color.acc)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.acc.opacity(0.1), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .font(Font.geist(11.5, relativeTo: .caption))
        .padding(.vertical, 3)
        .padding(.leading, 50)
    }
}

// MARK: - Shoes

/// "Tênis  2 ativos · 1 aposentados", then the cards in a horizontal
/// carousel that bleeds to the screen edges.
private struct ShoesSection: View {
    let gear: [Gear]
    let unit: DistanceUnit
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let lang = language.lang
        let counts = Shoes.counts(gear)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("overview.shoes.title", bundle: .l10n)
                    .font(Font.geist(13.5, relativeTo: .subheadline).weight(.semibold))
                    .foregroundStyle(Color.fg)
                Spacer()
                Text(verbatim: L10n.string("overview.shoes.activeRetired %lld %lld", lang: lang, counts.active, counts.retired))
                    .font(Font.geist(11.5, relativeTo: .caption))
                    .foregroundStyle(Color.mutedFg)
            }

            if gear.isEmpty {
                Text("overview.shoes.empty", bundle: .l10n)
                    .font(Font.geist(12.5, relativeTo: .caption))
                    .foregroundStyle(Color.mutedFg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(gear) { ShoeCard(gear: $0, unit: unit) }
                    }
                    .padding(.horizontal, pageGutter)
                }
                .padding(.horizontal, -pageGutter)
                .padding(.top, 12)
            }
        }
    }
}

private struct ShoeCard: View {
    let gear: Gear
    let unit: DistanceUnit
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let lang = language.lang
        let label = UnitConversion.label(unit)
        let calendar = Calendar.current
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(verbatim: gear.brandName ?? "—")
                    .font(Font.geist(10, relativeTo: .caption2).weight(.semibold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.mutedFg)
                Spacer()
                if let badge = Shoes.badge(gear) {
                    Text(badge == .primary ? "overview.shoes.default" : "overview.shoes.retired", bundle: .l10n)
                        .font(Font.geist(9.5, relativeTo: .caption2).weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(badge == .primary ? Color.accTx : Color.mutedFg)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(badge == .primary ? Color.accBg : Color.chip, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
            }

            Text(gear.modelName ?? gear.name)
                .font(Font.geist(15, relativeTo: .subheadline).weight(.semibold))
                .foregroundStyle(Color.fg)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: "\(RunFormat.distance(gear.computedDistanceM / 1000, unit: unit, lang: lang)) \(label)")
                    .font(Font.geist(22, relativeTo: .title2).weight(.bold))
                    .foregroundStyle(Color.fg)
                Text(verbatim: L10n.string("overview.shoes.ofLifespan %lld %@", lang: lang,
                                           UnitConversion.goalDisplay(km: Int(Shoes.lifespanM / 1000), in: unit), label))
                    .font(Font.geist(11.5, relativeTo: .caption))
                    .foregroundStyle(Color.mutedFg)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            Capsule()
                .fill(Color.chip)
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(barColor)
                            .frame(width: geo.size.width * Shoes.wear(gear))
                    }
                }

            Text(verbatim: meta(lang: lang, calendar: calendar))
                .font(Font.geist(11.5, relativeTo: .caption))
                .foregroundStyle(Color.mutedFg)
                // the card is 230 wide: large text wraps the date instead of cutting it
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 230, alignment: .leading)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.border, lineWidth: 1) }
        .opacity(gear.retired ? 0.6 : 1)
    }

    private var barColor: Color {
        switch Shoes.bar(gear) {
        case .muted: .mutedFg
        case .worn: .neg
        case .normal: .acc
        }
    }

    private func meta(lang: Lang, calendar: Calendar) -> String {
        switch Shoes.meta(gear) {
        case .dateRange(let start, let end):
            L10n.string("overview.shoes.dateRange %@ %@", lang: lang,
                        RunFormat.monthShortYear(start, lang: lang, calendar: calendar), RunFormat.monthShortYear(end, lang: lang, calendar: calendar))
        case .runsSince(let count, let since):
            L10n.string("overview.shoes.runsSince %lld %@", lang: lang, count, RunFormat.monthShortYear(since, lang: lang, calendar: calendar))
        case .runsOnly(let count):
            L10n.string("overview.shoes.runsOnly %lld", lang: lang, count)
        }
    }
}
