import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// The day sheet (spec .plans/plano-semanal-spec.md §6.5): the Ajustes of one
/// day, opened from a column of Hoje's week strip or a day of the editor's
/// "Esta semana / Próxima". One block per enabled area (Corrida, Treino) with
/// only what the server would accept (`PlanDaySheet`): change the routine,
/// move, Folga ("Pular"), undo, add. Every tap shows at once and goes through
/// the `PlanStore` queue; the server's window then replaces the guess.
struct PlanDaySheetView: View {
    let date: String
    let areas: [Area]
    let plan: PlanStore
    let workout: WorkoutStore
    /// "Editar padrão semanal ›"; nil inside the editor itself
    let onEditPattern: (() -> Void)?
    /// the area whose move targets are open
    @State private var moving: Area?
    @State private var pickingRoutine = false
    @Environment(\.dismiss) private var dismiss
    @Environment(AppLanguageStore.self) private var language

    private var today: String { PlanStore.today() }
    private var sheet: PlanDaySheet? { PlanDaySheet.make(date: date, window: plan.days, areas: areas, today: today) }
    private var templateNames: [String: String] {
        Dictionary(workout.templates.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
    }

    var body: some View {
        let lang = language.lang
        NavigationStack {
            ScrollView {
                if let sheet {
                    content(sheet, lang: lang)
                } else {
                    // the plan was turned off meanwhile (or the day left the window)
                    Text("plan.day.unavailable", bundle: .l10n)
                        .font(DSFont.meta)
                        .foregroundStyle(Color.mutedFg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, pageGutter)
                        .padding(.top, 12)
                }
            }
            .background(Color.pageBg)
            .navigationTitle(Text(verbatim: title(lang)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text("common.ok", bundle: .l10n) }
                }
            }
        }
        .sheet(isPresented: $pickingRoutine) {
            RoutinePicker(
                title: title(lang),
                templates: workout.templates,
                selected: plan.days.first { $0.date == date }?.entry(.gym)?.templateId
            ) { id in
                pickingRoutine = false
                apply(.routine(id, on: date))
            }
            .presentationDetents([.medium, .large])
            .monolitoTheme()
        }
        .presentationDetents([.medium, .large])
        .task { if workout.templates.isEmpty { await workout.load() } }
    }

    /// "Quarta, 29 de outubro"
    private func title(_ lang: Lang) -> String {
        DietFormat.dayHeader(PlanDate.localMidnight(date, calendar: .current), lang: lang, calendar: .current)
    }

    private func content(_ sheet: PlanDaySheet, lang: Lang) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if sheet.isPast {
                Text("plan.day.pastNote", bundle: .l10n)
                    .font(DSFont.caption)
                    .foregroundStyle(Color.mutedFg)
                    .padding(.bottom, 14)
            }

            ForEach(sheet.rows, id: \.area) { row in
                block(row, lang: lang)
                    .padding(.vertical, 14)
                Divider().overlay(Color.border)
            }

            if sheet.canSkipAll {
                Button {
                    apply(.skipAll(sheet.rows.filter { $0.actions.contains(.skip) }.map(\.area), on: date))
                } label: {
                    Text("plan.day.skipAll", bundle: .l10n)
                }
                .buttonStyle(.chip)
                .padding(.top, 16)
            }

            if let error = plan.actionError {
                Text(verbatim: error)
                    .font(DSFont.caption)
                    .foregroundStyle(Color.neg)
                    .padding(.top, 12)
            }

            if let onEditPattern {
                Button(action: onEditPattern) {
                    HStack(spacing: 4) {
                        Text("plan.day.editPattern", bundle: .l10n)
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                    }
                    .font(DSFont.meta)
                    .foregroundStyle(Color.mutedFg)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 20)
            }
        }
        .padding(.horizontal, pageGutter)
        .padding(.top, 4)
        .padding(.bottom, 24)
    }

    // MARK: One area

    private func block(_ row: PlanDaySheet.Row, lang: Lang) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: heading(row, lang))
                    .font(DSFont.row)
                    .foregroundStyle(Color.fg)
                if let detail = detail(row, lang) {
                    Text(verbatim: detail)
                        .font(DSFont.caption)
                        .foregroundStyle(Color.mutedFg)
                }
            }
            if !row.actions.isEmpty {
                HStack(spacing: 8) {
                    ForEach(row.actions, id: \.self) { action in
                        Button { tap(action, row.area) } label: { Text(verbatim: actionLabel(action, row.area, lang)) }
                            .buttonStyle(.chip)
                    }
                }
            }
            if moving == row.area {
                targets(row.area, lang: lang)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeOut(duration: 0.2), value: moving)
    }

    /// Today through the Sunday after next; the ones the server would refuse
    /// are disabled and say why.
    private func targets(_ area: Area, lang: Lang) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PlanStatus.moveTargets(area, from: date, window: plan.days, today: today), id: \.date) { target in
                    Button {
                        moving = nil
                        apply(.move(area, from: date, to: target.date))
                    } label: {
                        VStack(spacing: 1) {
                            Text(verbatim: dayLabel(target.date, lang))
                            if let refusal = target.refusal {
                                Text(verbatim: refusalLabel(refusal, area, lang))
                                    .font(Font.geist(10.5, relativeTo: .caption2))
                                    .foregroundStyle(Color.mutedFg)
                            }
                        }
                        .padding(.vertical, target.refusal == nil ? 0 : 4)
                    }
                    .buttonStyle(.chip)
                    .disabled(target.refusal != nil)
                }
            }
            .padding(.horizontal, pageGutter)
        }
        .padding(.horizontal, -pageGutter)
        .accessibilityLabel(Text("plan.move.title", bundle: .l10n))
    }

    private func tap(_ action: PlanDaySheet.Action, _ area: Area) {
        switch action {
        case .changeRoutine: pickingRoutine = true
        case .move: moving = moving == area ? nil : area
        case .skip: apply(.skip(area, on: date))
        case .undo: apply(.undo(area, on: date))
        case .add: apply(.add(area, on: date))
        }
    }

    private func apply(_ change: PlanChange) {
        moving = nil
        Task { await plan.apply(change, templateNames: templateNames) }
    }

    // MARK: Labels

    /// "Dom 1"
    private func dayLabel(_ date: String, _ lang: Lang) -> String {
        "\(PlanDate.weekdayShort(date, lang: lang)) \(Int(date.suffix(2)) ?? 0)"
    }

    private func areaName(_ area: Area, _ lang: Lang) -> String {
        L10n.string(area == .run ? "today.status.run" : "today.status.gym", lang: lang)
    }

    /// "Treino · Peito"
    private func heading(_ row: PlanDaySheet.Row, _ lang: Lang) -> String {
        let name = areaName(row.area, lang)
        switch row.kind {
        case .planned(let routine?, _), .movedFrom(_, let routine?): return "\(name) · \(routine)"
        default: return name
        }
    }

    private func detail(_ row: PlanDaySheet.Row, _ lang: Lang) -> String? {
        switch row.kind {
        case .planned(_, let adjusted): adjusted ? L10n.string("plan.day.adjusted", lang: lang) : nil
        case .skipped: L10n.string("plan.day.skipped", lang: lang)
        case .movedTo(let to): L10n.string("plan.day.movedTo %@", lang: lang, dayLabel(to, lang))
        case .movedFrom(let from, _): L10n.string("plan.day.movedFrom %@", lang: lang, dayLabel(from, lang))
        case .free: L10n.string("plan.day.free", lang: lang)
        }
    }

    private func actionLabel(_ action: PlanDaySheet.Action, _ area: Area, _ lang: Lang) -> String {
        switch action {
        case .changeRoutine: L10n.string("plan.action.changeRoutine", lang: lang)
        case .move: L10n.string("plan.action.move", lang: lang)
        case .skip: L10n.string("plan.action.skip", lang: lang)
        case .undo: L10n.string("plan.action.undo", lang: lang)
        case .add: L10n.string(area == .run ? "plan.action.addRun" : "plan.action.addGym", lang: lang)
        }
    }

    private func refusalLabel(_ refusal: PlanStatus.MoveRefusal, _ area: Area, _ lang: Lang) -> String {
        switch refusal {
        case .sameDay: L10n.string("plan.move.sameDay", lang: lang)
        case .noPlan: L10n.string("plan.move.noPlan", lang: lang)
        case .alreadyPlanned: L10n.string(area == .run ? "plan.move.hasRun" : "plan.move.hasGym", lang: lang)
        case .partOfMove: L10n.string("plan.move.partOfMove", lang: lang)
        }
    }
}

/// `.sheet(item:)` needs an identity: the day's date.
struct PlanDayItem: Identifiable, Equatable {
    let date: String
    var id: String { date }
}
