import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// The Padrão editor (spec .plans/plano-semanal-spec.md §6.6): a grid of the
/// enabled areas (Corrida, Treino) × Monday…Sunday. A tap turns a day on or
/// off; a long press on a Treino picks its routine, whose letters then show
/// in the dot (`RoutineAbbreviation`). The draft lives in memory
/// (`PatternDraft`, which keeps the slots of disabled areas) and goes out in
/// one `PUT /plan/pattern`, which starts today: past days keep the Padrão
/// they had, and the Ajustes of this week and the next stay. Leaving with
/// changes asks first; saving an empty grid turns the plan off and says so.
struct WeekPlanEditorView: View {
    let areas: [Area]
    let plan: PlanStore
    let workout: WorkoutStore
    /// reloaded after a save: the server rewrites the Meta of Treinos
    let profile: ProfileStore
    @State private var draft: PatternDraft?
    @State private var loadFailed = false
    @State private var saving = false
    @State private var saveFailed = false
    @State private var confirmingDiscard = false
    @State private var confirmingEmpty = false
    /// the weekday whose routine is being picked
    @State private var pickingRoutine: Int?
    /// 0 = this week, 1 = the next: whose days open the day sheet
    @State private var week = 0
    @State private var openDay: PlanDayItem?
    @Environment(\.dismiss) private var dismiss
    @Environment(AppLanguageStore.self) private var language

    /// the rows: Dieta is never planned
    private var rows: [Area] { [Area.run, .gym].filter(areas.contains) }

    var body: some View {
        Group {
            if let draft {
                editor(draft)
            } else if loadFailed {
                ContentUnavailableView {
                    Label { Text("plan.editor.loadFailed", bundle: .l10n) } icon: { Image(systemName: "wifi.exclamationmark") }
                } actions: {
                    Button { Task { await load() } } label: { Text("common.retry", bundle: .l10n) }
                        .buttonStyle(.pill)
                }
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.pageBg)
        .navigationTitle(Text("plan.editor.title", bundle: .l10n))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(draft?.isDirty == true)
        .toolbar {
            if draft?.isDirty == true {
                ToolbarItem(placement: .cancellationAction) {
                    Button { confirmingDiscard = true } label: { Text("common.cancel", bundle: .l10n) }
                        .disabled(saving)
                }
            }
        }
        .confirmationDialog(Text("gym.editor.discardConfirm", bundle: .l10n), isPresented: $confirmingDiscard, titleVisibility: .visible) {
            Button(role: .destructive) { dismiss() } label: { Text("gym.editor.discard", bundle: .l10n) }
            Button(role: .cancel) {} label: { Text("gym.editor.keepEditing", bundle: .l10n) }
        }
        .confirmationDialog(Text("plan.editor.emptyConfirm", bundle: .l10n), isPresented: $confirmingEmpty, titleVisibility: .visible) {
            Button(role: .destructive) { Task { await save() } } label: { Text("plan.editor.turnOff", bundle: .l10n) }
            Button(role: .cancel) {} label: { Text("common.cancel", bundle: .l10n) }
        }
        .sheet(item: Binding(get: { pickingRoutine.map(PickedDay.init) }, set: { pickingRoutine = $0?.weekday })) { day in
            RoutinePicker(
                title: PlanDate.weekdayLong(sampleDate(day.weekday), lang: language.lang),
                templates: workout.templates,
                selected: draft?.templateId(day.weekday)
            ) { id in
                draft?.setTemplate(day.weekday, id)
                pickingRoutine = nil
            }
            .presentationDetents([.medium, .large])
            .monolitoTheme()
        }
        .sheet(item: $openDay) { day in
            PlanDaySheetView(date: day.date, areas: areas, plan: plan, workout: workout, onEditPattern: nil)
                .monolitoTheme()
        }
        .hidesFloatingTabBar()
        .task { await load() }
    }

    /// "Esta semana / Próxima" and that week's days: a tap opens the day
    /// sheet, the only way to a day of next week (Hoje shows this one).
    private func days(_ lang: Lang) -> some View {
        let today = PlanStore.today()
        let dates = PlanDate.week(of: PlanDate.add(7 * week, to: today))
        return VStack(alignment: .leading, spacing: 12) {
            Picker(selection: $week) {
                Text("plan.editor.thisWeek", bundle: .l10n).tag(0)
                Text("plan.editor.nextWeek", bundle: .l10n).tag(1)
            } label: {
                Text("plan.editor.title", bundle: .l10n)
            }
            .pickerStyle(.segmented)
            .fixedSize()
            HStack(spacing: 6) {
                ForEach(dates, id: \.self) { date in
                    let active = plan.days.first { $0.date == date }?.active == true
                    Button { openDay = PlanDayItem(date: date) } label: {
                        VStack(spacing: 2) {
                            Text(verbatim: String(PlanDate.weekdayShort(date, lang: lang).prefix(1)))
                                .font(Font.geistMono(10.5, relativeTo: .caption2))
                                .foregroundStyle(Color.mutedFg)
                            Text(verbatim: "\(Int(date.suffix(2)) ?? 0)")
                                .font(Font.geistMono(14, relativeTo: .subheadline).weight(date == today ? .semibold : .regular))
                                .foregroundStyle(Color.fg)
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.chip, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .opacity(active ? 1 : 0.4)
                    }
                    .buttonStyle(.plain)
                    .disabled(!active)
                    .accessibilityLabel(Text(verbatim: DietFormat.dayHeader(PlanDate.localMidnight(date, calendar: .current), lang: lang, calendar: .current)))
                }
            }
            Text("plan.editor.daysHint", bundle: .l10n)
                .font(DSFont.caption)
                .foregroundStyle(Color.mutedFg)
        }
    }

    private func load() async {
        loadFailed = false
        await plan.loadPattern()
        if workout.templates.isEmpty { await workout.load() }
        guard draft == nil else { return }
        if let pattern = plan.pattern {
            draft = PatternDraft(pattern)
        } else {
            loadFailed = true
        }
    }

    private func save() async {
        guard let draft else { return }
        saving = true
        saveFailed = false
        do {
            try await plan.savePattern(draft.request)
            await profile.load()
            dismiss()
        } catch {
            saveFailed = true
        }
        saving = false
    }

    // MARK: Editor

    private func editor(_ draft: PatternDraft) -> some View {
        let lang = language.lang
        let names = abbreviations(draft)
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Grid(alignment: .center, horizontalSpacing: 2, verticalSpacing: 14) {
                    GridRow {
                        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                        ForEach(1...7, id: \.self) { weekday in
                            Text(verbatim: String(weekdayShort(weekday, lang).prefix(1)))
                                .font(Font.geistMono(11, relativeTo: .caption2))
                                .foregroundStyle(Color.mutedFg)
                        }
                    }
                    ForEach(rows, id: \.self) { area in
                        GridRow {
                            Text(verbatim: areaName(area, lang))
                                .font(DSFont.row)
                                .foregroundStyle(Color.fg)
                                .gridColumnAlignment(.leading)
                                .lineLimit(1)
                                .fixedSize()
                            ForEach(1...7, id: \.self) { weekday in
                                dot(area, weekday, draft: draft, names: names, lang: lang)
                            }
                        }
                    }
                }
                .padding(.top, 20)

                if rows.contains(.gym) {
                    let routines = (1...7).compactMap { weekday -> String? in
                        guard draft.isOn(weekday, .gym), let name = routineName(draft.templateId(weekday)) else { return nil }
                        return "\(weekdayShort(weekday, lang)) · \(name)"
                    }
                    if !routines.isEmpty {
                        Text(verbatim: routines.joined(separator: "   "))
                            .font(DSFont.meta)
                            .foregroundStyle(Color.fg)
                            .padding(.top, 22)
                    }
                    Text("plan.editor.hint", bundle: .l10n)
                        .font(DSFont.caption)
                        .foregroundStyle(Color.mutedFg)
                        .padding(.top, routines.isEmpty ? 22 : 6)
                    Text(verbatim: "\(draft.gymDays) \(L10n.string("today.goals.workoutsUnit", lang: lang))")
                        .font(DSFont.caption)
                        .foregroundStyle(Color.mutedFg)
                        .padding(.top, 2)
                }

                // a day's Ajustes, only with a saved plan (the draft isn't one)
                if plan.pattern?.isActive == true {
                    days(lang)
                        .padding(.top, 28)
                }

                Text("plan.editor.note", bundle: .l10n)
                    .font(DSFont.caption)
                    .foregroundStyle(Color.mutedFg)
                    .padding(.top, 28)
            }
            .padding(.horizontal, pageGutter)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if saveFailed {
                    Text("nav.profile.saveError", bundle: .l10n)
                        .font(DSFont.caption)
                        .foregroundStyle(Color.neg)
                }
                Button {
                    if draft.isEmpty && plan.pattern?.isActive == true { confirmingEmpty = true } else { Task { await save() } }
                } label: {
                    Text(saving ? "plan.editor.saving" : "plan.editor.save", bundle: .l10n).frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
                .disabled(!draft.isDirty || saving)
            }
            .padding(.horizontal, pageGutter)
            .padding(.bottom, 8)
            .background(Color.pageBg)
        }
    }

    private func dot(_ area: Area, _ weekday: Int, draft: PatternDraft, names: [String: String], lang: Lang) -> some View {
        let on = draft.isOn(weekday, area)
        let routine = area == .gym ? routineName(draft.templateId(weekday)) : nil
        return ZStack {
            if on {
                Circle().fill(Color.fg)
                if let routine, let letters = names[routine] {
                    Text(verbatim: letters)
                        .font(Font.geist(11, relativeTo: .caption).weight(.semibold))
                        .foregroundStyle(Color.pageBg)
                        .minimumScaleFactor(0.7)
                }
            } else {
                Circle().strokeBorder(Color.border, lineWidth: 1.5)
            }
        }
        // 7 dots + the area name must fit a 375 pt screen inside the gutters
        .frame(width: 30, height: 30)
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(Rectangle())
        .onTapGesture { self.draft?.toggle(weekday, area) }
        .onLongPressGesture {
            guard area == .gym else { return }
            if !on { self.draft?.toggle(weekday, .gym) }
            pickingRoutine = weekday
        }
        .sensoryFeedback(.selection, trigger: on)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(areaName(area, lang)), \(PlanDate.weekdayLong(sampleDate(weekday), lang: lang))"))
        .accessibilityValue(Text(verbatim: [
            L10n.string(on ? "plan.editor.on" : "plan.editor.off", lang: lang), routine,
        ].compactMap { $0 }.joined(separator: ", ")))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { self.draft?.toggle(weekday, area) }
        .accessibilityActions {
            if area == .gym && on {
                Button { pickingRoutine = weekday } label: { Text("plan.editor.chooseRoutine", bundle: .l10n) }
            }
        }
    }

    // MARK: Helpers

    /// a day of a fixed week (2026-10-26 is a Monday): weekday → its names
    private func sampleDate(_ weekday: Int) -> String { PlanDate.add(weekday - 1, to: "2026-10-26") }

    private func weekdayShort(_ weekday: Int, _ lang: Lang) -> String { PlanDate.weekdayShort(sampleDate(weekday), lang: lang) }

    private func areaName(_ area: Area, _ lang: Lang) -> String {
        L10n.string(area == .run ? "today.status.run" : "today.status.gym", lang: lang)
    }

    /// nil for "any routine", or a routine that no longer exists
    private func routineName(_ id: String?) -> String? {
        id.flatMap { id in workout.templates.first { $0.id == id }?.name }
    }

    private func abbreviations(_ draft: PatternDraft) -> [String: String] {
        RoutineAbbreviation.make((1...7).compactMap { draft.isOn($0, .gym) ? routineName(draft.templateId($0)) : nil })
    }
}

private struct PickedDay: Identifiable {
    let weekday: Int
    var id: Int { weekday }
}

/// "Qualquer rotina" first (the rotation picks), then the routines. Also the
/// day sheet's "Trocar rotina".
struct RoutinePicker: View {
    let title: String
    let templates: [TemplateSummary]
    let selected: String?
    let onPick: (String?) -> Void
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let lang = language.lang
        NavigationStack {
            List {
                row(L10n.string("plan.editor.anyRoutine", lang: lang), id: nil)
                ForEach(templates) { template in
                    row(template.name, id: template.id)
                }
            }
            .monolitoList()
            .navigationTitle(Text(verbatim: title))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func row(_ name: String, id: String?) -> some View {
        Button { onPick(id) } label: {
            HStack {
                Text(verbatim: name).font(DSFont.row).foregroundStyle(Color.fg)
                Spacer()
                if selected == id {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.acc)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.pageBg)
    }
}
