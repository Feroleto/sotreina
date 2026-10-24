import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// Dieta › Histórico, the web's `DietHistoryPage`: kcal per day over 7 or 14
/// days against the daily goal (dashed line), and the same days as a list,
/// newest first. A bar and its row share the selection; the selected day's
/// totals read above the bars. The page title is the area header's tab, so
/// the web's repeated "Histórico" heading is left out.
struct DietHistoryView: View {
    let store: DietHistoryStore
    let profile: ProfileStore
    @State private var selected: String?
    @Environment(AppLanguageStore.self) private var language

    private var kcalGoal: Double { Double(profile.settings?.dailyKcalGoal ?? 2000) }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.pageBg)
            .task {
                async let history: Void = store.load()
                async let goal: Void = profile.load()
                _ = await (history, goal)
            }
            .onChange(of: store.points, initial: true) { _, points in
                selected = DietHistory.keepSelection(selected, in: points)
            }
    }

    @ViewBuilder private var content: some View {
        switch store.loadState {
        case .idle:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loading where store.points.isEmpty:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView {
                Label { Text("diet.history.loadFailed", bundle: .l10n) } icon: { Image(systemName: "wifi.exclamationmark") }
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

    private var subtitle: some View {
        Text("diet.history.subtitle", bundle: .l10n)
            .font(DSFont.meta)
            .foregroundStyle(Color.mutedFg)
    }

    private var rangePicker: some View {
        Picker(selection: Binding(get: { store.range }, set: { days in Task { await store.select(range: days) } })) {
            Text("diet.history.range7", bundle: .l10n).tag(7)
            Text("diet.history.range14", bundle: .l10n).tag(14)
        } label: {
            Text("diet.history.subtitle", bundle: .l10n)
        }
        .pickerStyle(.segmented)
        .fixedSize()
    }

    private var page: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // side by side; stacked when large type doesn't fit both
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        subtitle
                        Spacer(minLength: 0)
                        rangePicker
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        subtitle
                        rangePicker
                    }
                }
                .padding(.top, 16)

                ChartCard(points: store.points, selected: $selected, kcalGoal: kcalGoal)
                    .padding(.top, 16)

                SectionTitle(L10n.string("diet.history.daysTitle", lang: language.lang))
                    .padding(.horizontal, 4)
                    .padding(.top, 24)
                    .padding(.bottom, 8)

                DaysList(points: store.points, selected: $selected, kcalGoal: kcalGoal)
                    .padding(.bottom, 44)
            }
            .padding(.horizontal, pageGutter)
            .monospacedDigit()
        }
        .refreshable {
            async let history: Void = store.load()
            async let goal: Void = profile.load()
            _ = await (history, goal)
        }
    }
}

/// `rounded-[16px] border bg-card p-[20px]`: the selected day's reading,
/// then the bars over the dashed goal line and the dates under them.
private struct ChartCard: View {
    let points: [DailyHistoryPoint]
    @Binding var selected: String?
    let kcalGoal: Double
    @Environment(AppLanguageStore.self) private var language

    private static let chartHeight: CGFloat = 140

    var body: some View {
        let lang = language.lang
        let scale = DietHistory.scaleMax(points, kcalGoal: kcalGoal)
        let goalY = Self.chartHeight * DietHistory.goalFraction(kcalGoal: kcalGoal, scaleMax: scale)
        // the labels follow what's drawn, not the range a pending fetch asked for
        let range = points.count

        VStack(alignment: .leading, spacing: 0) {
            if let point = points.first(where: { $0.date == selected }) ?? points.last {
                Text(verbatim: "\(DietHistory.longDate(point.date, lang: lang, calendar: .current)) · \(DietHistory.rounded(point.totalKcal)) \(L10n.string("diet.overview.kcal", lang: lang)) · \(DietHistory.macros(point))")
                    .font(DSFont.meta.weight(.medium))
                    .foregroundStyle(Color.fg)
            }

            ZStack(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(points) { point in
                        Button { selected = point.date } label: {
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4, style: .continuous)
                                    .fill(color(DietHistory.tone(point, selected: selected, kcalGoal: kcalGoal)))
                                    .frame(height: Self.chartHeight * DietHistory.barFraction(point.totalKcal, scaleMax: scale))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: "\(DietHistory.longDate(point.date, lang: lang, calendar: .current)) · \(DietHistory.rounded(point.totalKcal)) kcal"))
                        .accessibilityAddTraits(point.date == selected ? .isSelected : [])
                    }
                }

                DashedLine()
                    .stroke(Color.mutedFg, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .frame(height: 1)
                    .offset(y: -goalY)
                    .allowsHitTesting(false)
            }
            .frame(height: Self.chartHeight)
            .padding(.top, 16)

            HStack(spacing: 6) {
                ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                    Text(verbatim: DietHistory.label(at: index, of: point, range: range) ?? "")
                        .font(Font.geist(10.5, relativeTo: .caption2))
                        .foregroundStyle(Color.mutedFg)
                        // shrinks inside its bar's width: at large type seven
                        // fixed-size dates outgrew the screen and dragged the page
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 6)
        }
        .padding(20)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.border, lineWidth: 1)
        }
    }

    /// `--acc` / `--neg` 55% / `--acc` 35%
    private func color(_ tone: DietHistory.Tone) -> Color {
        switch tone {
        case .selected: Color.acc
        case .over: Color.neg.opacity(0.55)
        case .within: Color.acc.opacity(0.35)
        }
    }
}

private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}

/// `rounded-[14px] border bg-card`: one row per day, newest first, the
/// selected one on `--chip`; kcal in `--neg` past the goal.
private struct DaysList: View {
    let points: [DailyHistoryPoint]
    @Binding var selected: String?
    let kcalGoal: Double
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let lang = language.lang
        VStack(spacing: 0) {
            ForEach(Array(points.reversed().enumerated()), id: \.element.id) { index, point in
                if index > 0 { Hairline() }
                Button { selected = point.date } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: DietHistory.longDate(point.date, lang: lang, calendar: .current))
                                .font(DSFont.meta.weight(.medium))
                                .foregroundStyle(Color.fg)
                            Text(verbatim: DietHistory.macros(point))
                                .font(Font.geist(11, relativeTo: .caption2))
                                .foregroundStyle(Color.mutedFg)
                        }
                        Spacer(minLength: 0)
                        Text(verbatim: "\(DietHistory.rounded(point.totalKcal)) \(L10n.string("diet.overview.kcal", lang: lang))")
                            .font(DSFont.meta.weight(.semibold))
                            .foregroundStyle(DietHistory.isOver(point, kcalGoal: kcalGoal) ? Color.neg : Color.fg)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(point.date == selected ? Color.chip : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(point.date == selected ? .isSelected : [])
            }
        }
        .background(Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.border, lineWidth: 1)
        }
    }
}
