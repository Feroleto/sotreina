import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// Treino › Histórico (web GymHistoryPage): KPIs of the last 12 weeks, the
/// weekly volume bars (tap one to read it) and "Recentes" grouped by week;
/// a row pushes the workout's detail.
struct GymHistoryView: View {
    let store: GymHistoryStore
    @State private var selectedWeek: Int?
    /// the workout whose detail is pushed
    @State private var viewingId: String?
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.pageBg)
            .onPopToRoot { viewingId = nil }
            .navigationDestination(item: $viewingId) { id in
                if let item = store.items.first(where: { $0.id == id }) {
                    WorkoutHistoryDetailView(item: item, store: store)
                }
            }
            .taskOnTabActivation { await store.load() }
    }

    @ViewBuilder private var content: some View {
        switch store.loadState {
        case .idle:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loading where store.items.isEmpty:
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
            if store.items.isEmpty {
                ContentUnavailableView {
                    Label { Text("gym.history.empty", bundle: .l10n) } icon: { Image(systemName: "clock") }
                }
                .refreshable { await store.load() }
            } else {
                list
            }
        }
    }

    private var list: some View {
        let lang = language.lang
        let unit = store.weightUnit
        let weeks = HistoryBins.weeklyVolume(store.items, weeks: HistoryBins.chartWeeks)
        let summary = HistoryBins.summary(store.items, weeks: HistoryBins.chartWeeks)
        let groups = HistoryBins.groupByWeek(store.items)
        let dots = HistoryBins.routineDots(store.items)
        let weeksText = L10n.string("gym.history.weeksCount %lld", lang: lang, weeks.count)

        return List {
            Group {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        KpiCard(label: Text("gym.history.kpiWorkouts", bundle: .l10n), value: "\(summary.count)", sub: weeksText)
                        KpiCard(label: Text("gym.history.kpiVolume", bundle: .l10n), value: WorkoutFormat.volume(summary.volumeKg, unit: unit, lang: lang), sub: weeksText)
                        KpiCard(label: Text("gym.history.kpiTime", bundle: .l10n), value: WorkoutFormat.totalDuration(summary.durationSec), sub: L10n.string("gym.history.inTraining", lang: lang))
                        KpiCard(label: Text("gym.history.kpiFrequency", bundle: .l10n), value: decimal(summary.perWeek, lang), sub: L10n.string("gym.history.perWeek", lang: lang))
                    }
                    .padding(.horizontal, pageGutter)
                }
                .padding(.horizontal, -pageGutter)
                .padding(.top, 16)
                .listRowSeparator(.hidden)

                WeeklyBars(weeks: weeks, total: summary.volumeKg, selected: $selectedWeek, unit: unit)
                    .padding(.top, 12)
                    .listRowSeparator(.hidden)

                ForEach(Array(groups.prefix(HistoryBins.recentWeekGroups).enumerated()), id: \.element.start) { _, group in
                    HStack(alignment: .firstTextBaseline) {
                        CapsTitle(Text("gym.history.weekOf \(WorkoutFormat.dayMonth(group.start))", bundle: .l10n))
                        Spacer()
                        Text(verbatim: WorkoutFormat.volume(group.volumeKg, unit: unit, lang: lang))
                            .font(DSFont.caption)
                            .foregroundStyle(Color.mutedFg)
                    }
                    .padding(.top, 22)
                    .padding(.bottom, 9)
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }

                    ForEach(group.workouts) { item in
                        Button { viewingId = item.id } label: {
                            HistoryRow(item: item, dot: item.templateId.flatMap { dots[$0] }, unit: unit)
                        }
                        .buttonStyle(.plain)
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    }
                }

                let older = max(0, groups.count - HistoryBins.recentWeekGroups)
                if older > 0 {
                    Text("gym.history.olderWeeks \(older)", bundle: .l10n)
                        .font(DSFont.meta)
                        .foregroundStyle(Color.mutedFg)
                        .padding(.vertical, 12)
                        .listRowSeparator(.hidden)
                }
            }
            .listRowInsets(EdgeInsets(top: 0, leading: pageGutter, bottom: 0, trailing: pageGutter))
            .listRowBackground(Color.pageBg)
        }
        .monolitoList()
        .refreshable { await store.load() }
        .floatingTabBarScroll()
    }

    private func decimal(_ value: Double, _ lang: Lang) -> String {
        let text = String(format: "%.1f", value)
        return lang == .pt ? text.replacingOccurrences(of: ".", with: ",") : text
    }
}

/// `w-[150px] rounded-[14px] border bg-card`: caps label, big value, sub line.
private struct KpiCard: View {
    let label: Text
    let value: String
    let sub: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            CapsTitle(label)
            Text(verbatim: value)
                .font(Font.geist(20, relativeTo: .title3).weight(.bold))
                .foregroundStyle(Color.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(verbatim: sub)
                .font(DSFont.caption)
                .foregroundStyle(Color.mutedFg)
                .lineLimit(1)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        // 150 including the padding, like the web's w-[150px]
        .frame(width: 150, alignment: .leading)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.border, lineWidth: 1)
        }
    }
}

/// The 12 weekly bars in a card; tapping one reads its week, tapping it
/// again goes back to the total. A date under every third bar.
private struct WeeklyBars: View {
    let weeks: [HistoryBins.WeekVolume]
    let total: Double
    @Binding var selected: Int?
    let unit: WeightUnit
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let lang = language.lang
        let maxVolume = max(1, weeks.map(\.volumeKg).max() ?? 1)
        let selection = selected.flatMap { weeks.indices.contains($0) ? $0 : nil }

        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let index = selection {
                    let week = weeks[index]
                    let end = Calendar.current.date(byAdding: .day, value: 6, to: week.start) ?? week.start
                    Text(verbatim: L10n.string(
                        "gym.history.barReading %@ %@", lang: lang,
                        "\(WorkoutFormat.dayMonth(week.start)) – \(WorkoutFormat.dayMonth(end))",
                        WorkoutFormat.volume(week.volumeKg, unit: unit, lang: lang)
                    ))
                    .foregroundStyle(Color.fg)
                } else {
                    Text(verbatim: L10n.string("gym.history.barHint %@ %lld", lang: lang, WorkoutFormat.volume(total, unit: unit, lang: lang), weeks.count))
                        .foregroundStyle(Color.mutedFg)
                }
            }
            .font(DSFont.meta)

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(weeks.enumerated()), id: \.element.start) { index, week in
                    Button {
                        selected = selected == index ? nil : index
                    } label: {
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4, style: .continuous)
                                .fill(Color.acc)
                                .overlay {
                                    if selection == index {
                                        UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4, style: .continuous)
                                            .fill(Color.white.opacity(0.3))
                                    }
                                }
                                .frame(height: 120 * week.volumeKg / maxVolume)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: "\(WorkoutFormat.dayMonth(week.start)) · \(WorkoutFormat.volume(week.volumeKg, unit: unit, lang: lang))"))
                    .accessibilityAddTraits(selection == index ? .isSelected : [])
                }
            }
            .frame(height: 120)
            .padding(.top, 12)

            Hairline()
            HStack(spacing: 4) {
                ForEach(Array(weeks.enumerated()), id: \.element.start) { index, week in
                    Text(verbatim: index % 3 == 0 ? WorkoutFormat.dayMonth(week.start) : "")
                        .font(Font.geist(9.5, relativeTo: .caption2))
                        .foregroundStyle(Color.mutedFg)
                        .lineLimit(1)
                        .fixedSize()
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.border, lineWidth: 1)
        }
    }
}

/// dot · routine / date · min · exercises · volume ›
private struct HistoryRow: View {
    let item: WorkoutHistoryItem
    /// index into `Color.routineDots`; nil = free workout
    let dot: Int?
    let unit: WeightUnit
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let lang = language.lang
        HStack(spacing: 12) {
            Circle()
                .fill(dot.map { Color.routineDots[$0] } ?? Color.dotEasy)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 3) {
                Group {
                    if let name = item.templateName {
                        Text(verbatim: name)
                    } else {
                        Text("gym.freeWorkout", bundle: .l10n)
                    }
                }
                .font(DSFont.row.weight(.semibold))
                .foregroundStyle(Color.fg)
                .lineLimit(1)
                Text(verbatim: "\(WorkoutFormat.dayMonth(item.startedAt)) · \(Int((Double(item.durationSec) / 60).rounded())) min · \(L10n.string("gym.routines.exerciseCount %lld", lang: lang, item.exerciseCount))")
                    .font(DSFont.caption)
                    .foregroundStyle(Color.mutedFg)
            }
            Spacer(minLength: 8)
            Text(verbatim: WorkoutFormat.volume(item.volumeKg, unit: unit, lang: lang))
                .font(DSFont.row.weight(.semibold))
                .foregroundStyle(Color.fg)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.mutedFg)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
