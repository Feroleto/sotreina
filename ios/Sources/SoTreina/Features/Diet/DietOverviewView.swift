import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// Dieta › Visão geral, the web's `DietOverviewPage` (Redesign 18c
/// "Monolito"): today's kcal in Geist Mono against the daily goal, the macro
/// strip, then the meals in the server's order with their sums. The pencil
/// turns the list into its edit mode (reorder, rename, delete, add); the
/// gear opens Perfil's daily goal. Tapping a meal opens its "Adicionar".
struct DietOverviewView: View {
    let store: DietStore
    let profile: ProfileStore
    @State private var editingGoal = false

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.pageBg)
            .onPopToRoot { editingGoal = false }
            .navigationDestination(isPresented: $editingGoal) {
                if let settings = profile.settings {
                    DietGoalView(settings: settings, store: profile)
                }
            }
            // every time the page shows: Registros may have come from the web
            .taskOnTabActivation {
                async let day: Void = store.load()
                async let goal: Void = profile.load()
                _ = await (day, goal)
            }
            .alert(
                Text("app.error.title", bundle: .l10n),
                isPresented: Binding(get: { store.actionError != nil }, set: { if !$0 { store.actionError = nil } }),
                presenting: store.actionError
            ) { _ in
                Button(role: .cancel) {} label: { Text("common.ok", bundle: .l10n) }
            } message: { message in
                Text(message)
            }
    }

    @ViewBuilder private var content: some View {
        switch store.loadState {
        case .idle:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loading where store.meals.isEmpty:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView {
                Label { Text("diet.overview.loadFailed", bundle: .l10n) } icon: { Image(systemName: "wifi.exclamationmark") }
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
        let day = DietDay(logs: store.logs, summary: store.summary, goal: profile.settings)
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DayHeader(goalReady: profile.settings != nil) { editingGoal = true }

                KcalHero(day: day)

                MacroStrip(macros: day.macros)
                    .padding(.top, 22)

                MealsSection(store: store, day: day)
                    .padding(.top, 24)

                Text("diet.attribution", bundle: .l10n)
                    .font(Font.geist(10.5, relativeTo: .caption2))
                    .foregroundStyle(Color.mutedFg)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
                    .padding(.bottom, 44)
            }
            .padding(.horizontal, pageGutter)
            .monospacedDigit()
        }
        .refreshable {
            async let day: Void = store.load()
            async let goal: Void = profile.load()
            _ = await (day, goal)
        }
        .floatingTabBarScroll()
    }
}

/// "Quinta-feira, 23 de outubro" and the gear to the daily goal.
private struct DayHeader: View {
    let goalReady: Bool
    let onGoal: () -> Void
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        HStack(spacing: 12) {
            Text(verbatim: DietFormat.dayHeader(.now, lang: language.lang, calendar: .current))
                .font(DSFont.meta)
                .foregroundStyle(Color.mutedFg)
            Spacer()
            Button(action: onGoal) {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Color.mutedFg)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!goalReady)
            .padding(.trailing, -10)
            .accessibilityLabel(Text("diet.overview.editGoal", bundle: .l10n))
        }
    }
}

/// The day's kcal in Geist Mono 64, "meta 2.000 · faltam 766" (in `--neg`
/// past the goal) with the share, and the progress line.
private struct KcalHero: View {
    let day: DietDay
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let lang = language.lang
        let goal = DietFormat.integer(day.kcalGoal, lang: lang)
        VStack(alignment: .leading, spacing: 0) {
            BigNumber(DietFormat.integer(Int(day.totalKcal.rounded()), lang: lang), unit: L10n.string("diet.overview.kcal", lang: lang))
                .padding(.top, 12)

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Group {
                    if day.overGoal {
                        Text("diet.overview.goalLine \(goal)", bundle: .l10n) + Text(verbatim: " · ")
                            + Text("diet.overview.overGoal \(DietFormat.integer(day.overByKcal, lang: lang))", bundle: .l10n)
                    } else {
                        Text("diet.overview.goalLine \(goal)", bundle: .l10n) + Text(verbatim: " · ")
                            + Text("diet.overview.remaining \(DietFormat.integer(day.remainingKcal, lang: lang))", bundle: .l10n)
                    }
                }
                .foregroundStyle(day.overGoal ? Color.neg : Color.mutedFg)
                Spacer()
                Text(verbatim: "\(day.percent)%")
                    .fontWeight(.medium)
                    .foregroundStyle(Color.fg)
            }
            .font(Font.geist(12.5, relativeTo: .caption))
            .padding(.top, 12)

            ProgressLine(day.fraction)
                .padding(.top, 7)
        }
    }
}

/// Proteína / Carboidrato / Gordura between hairlines: "17 / 150g" and a
/// bar in the one accent, told apart by opacity.
private struct MacroStrip: View {
    let macros: [DietDay.MacroProgress]
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(macros.enumerated()), id: \.element.macro) { index, macro in
                if index > 0 { Hairline(axis: .vertical) }
                VStack(alignment: .leading, spacing: 0) {
                    // "Carboidrato" breaks mid-word in a third of the width at large sizes
                    Text(label(macro.macro))
                        .font(DSFont.caption)
                        .foregroundStyle(Color.mutedFg)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    (Text(verbatim: "\(Int(macro.grams.rounded()))")
                        .font(DSFont.kpiValue)
                        .foregroundStyle(Color.fg)
                        + Text(verbatim: " / \(macro.goal)g")
                        .font(Font.geistMono(12, relativeTo: .caption))
                        .foregroundStyle(Color.mutedFg))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.top, 4)
                    MacroBar(fraction: macro.fraction, opacity: macro.macro.opacity)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 14)
                .padding(.leading, index > 0 ? 12 : 0)
                .padding(.trailing, index < macros.count - 1 ? 12 : 0)
                .accessibilityElement(children: .combine)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .overlay(alignment: .top) { Hairline() }
        .overlay(alignment: .bottom) { Hairline() }
    }

    private func label(_ macro: DietDay.Macro) -> String {
        let lang = language.lang
        switch macro {
        case .protein: return L10n.string("diet.macro.protein", lang: lang)
        case .carbs: return L10n.string("diet.macro.carbs", lang: lang)
        case .fat: return L10n.string("diet.macro.fat", lang: lang)
        }
    }
}

private struct MacroBar: View {
    let fraction: Double
    let opacity: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.border)
                Capsule().fill(Color.acc.opacity(opacity)).frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 3)
    }
}

// MARK: - Meals

/// "Refeições de hoje" with the pencil; each meal's item count and kcal, or
/// in edit mode ↑ ↓ rename delete, and "Adicionar refeição" at the end.
private struct MealsSection: View {
    let store: DietStore
    let day: DietDay
    @State private var editing = false
    @State private var picker: PickerMode?
    @State private var deleting: Meal?
    @State private var adding: Meal?
    @Environment(AppLanguageStore.self) private var language

    enum PickerMode: Identifiable {
        case add
        case rename(Meal)

        var id: String {
            switch self {
            case .add: "add"
            case .rename(let meal): meal.id
            }
        }
    }

    var body: some View {
        let lang = language.lang
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionTitle(L10n.string("diet.overview.mealsTitle", lang: lang))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button {
                    editing.toggle()
                } label: {
                    Image(systemName: editing ? "checkmark" : "pencil")
                        .font(.system(size: 16, weight: editing ? .semibold : .regular))
                        .foregroundStyle(editing ? Color.accTx : Color.mutedFg)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, -10)
                .accessibilityLabel(Text(editing ? "diet.meals.done" : "diet.meals.editMeals", bundle: .l10n))
            }

            ForEach(Array(store.meals.enumerated()), id: \.element.id) { index, meal in
                Group {
                    if editing {
                        editRow(meal, index: index)
                    } else {
                        Button { adding = meal } label: { row(meal) }
                            .buttonStyle(.plain)
                    }
                }
                .overlay(alignment: .bottom) { Hairline() }
            }

            if store.loadState == .loaded, store.meals.isEmpty {
                Text("diet.meals.empty", bundle: .l10n)
                    .font(DSFont.meta)
                    .foregroundStyle(Color.mutedFg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .overlay(alignment: .bottom) { Hairline() }
            }

            if editing, MealList.canAdd(count: store.meals.count) {
                Button { picker = .add } label: {
                    Label { Text("diet.meals.add", bundle: .l10n) } icon: { Image(systemName: "plus") }
                        .font(Font.geist(13.5, relativeTo: .subheadline).weight(.medium))
                        .foregroundStyle(Color.accTx)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .overlay {
                            RoundedRectangle(cornerRadius: 11)
                                .strokeBorder(Color.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
            }
        }
        .onPopToRoot { adding = nil }
        .navigationDestination(item: $adding) { meal in
            AddMealView(meal: meal, diet: store)
        }
        .sheet(item: $picker) { mode in
            MealTypePicker(mode: mode) { type in
                picker = nil
                Task {
                    switch mode {
                    case .add: await store.add(type)
                    case .rename(let meal): await store.rename(meal.id, to: type)
                    }
                }
            }
            .monolitoTheme()
        }
        .confirmationDialog(
            deleting.map { deleteQuestion($0, lang: lang) } ?? "",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible,
            presenting: deleting
        ) { meal in
            Button(role: .destructive) {
                Task { await store.remove(meal.id) }
            } label: {
                Text("diet.meals.remove", bundle: .l10n)
            }
            Button(role: .cancel) {} label: { Text("common.cancel", bundle: .l10n) }
        }
    }

    /// "Café da manhã · 2 itens   451  (+)"
    private func row(_ meal: Meal) -> some View {
        let count = day.itemCount(meal.id)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: mealLabel(meal.type, lang: language.lang))
                    .font(DSFont.row)
                    .foregroundStyle(Color.fg)
                Group {
                    if count > 0 {
                        Text("diet.overview.items \(count)", bundle: .l10n)
                    } else {
                        Text("diet.overview.noItems", bundle: .l10n)
                    }
                }
                .font(DSFont.caption)
                .foregroundStyle(Color.mutedFg)
            }
            Spacer(minLength: 8)
            Text(verbatim: count > 0 ? DietFormat.integer(day.kcal(meal.id), lang: language.lang) : "—")
                .font(Font.geistMono(14.5, relativeTo: .subheadline).weight(.medium))
                .foregroundStyle(count > 0 ? Color.fg : Color.mutedFg)
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.accTx)
                .frame(width: 30, height: 30)
                .background(Color.chip, in: Circle())
                .accessibilityHidden(true)
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func editRow(_ meal: Meal, index: Int) -> some View {
        let count = store.meals.count
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: mealLabel(meal.type, lang: language.lang))
                    .font(DSFont.row)
                    .foregroundStyle(Color.fg)
                Text("diet.overview.items \(day.itemCount(meal.id))", bundle: .l10n)
                    .font(DSFont.caption)
                    .foregroundStyle(Color.mutedFg)
            }
            Spacer(minLength: 8)
            iconButton("chevron.up", label: "diet.meals.moveUp", enabled: index > 0) {
                Task { await store.move(at: index, by: -1) }
            }
            iconButton("chevron.down", label: "diet.meals.moveDown", enabled: index < count - 1) {
                Task { await store.move(at: index, by: 1) }
            }
            iconButton("pencil", label: "diet.meals.renameTitle", enabled: true) {
                picker = .rename(meal)
            }
            iconButton("trash", label: MealList.canDelete(count: count) ? "diet.meals.remove" : "diet.meals.lastMealHint",
                       enabled: MealList.canDelete(count: count)) {
                deleting = meal
            }
        }
        .padding(.vertical, 6)
    }

    private func iconButton(_ symbol: String, label: LocalizedStringKey, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color.mutedFg)
                .frame(width: 40, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(Text(label, bundle: .l10n))
    }

    private func deleteQuestion(_ meal: Meal, lang: Lang) -> String {
        meal.logCount > 0
            ? L10n.string("diet.meals.deleteConfirm %lld", lang: lang, meal.logCount)
            : L10n.string("diet.meals.deleteConfirmEmpty", lang: lang)
    }
}

/// `diet.meal.*`; a name this build doesn't know shows as sent.
func mealLabel(_ type: MealType, lang: Lang) -> String {
    let key = "diet.meal.\(type.rawValue)"
    let label = L10n.string(key, lang: lang)
    return label == key ? type.rawValue.capitalized : label
}

/// The web's `MealTypePicker` as a sheet: the closed list of names, one
/// selected, then Cancelar / the confirm. Serves add and rename.
private struct MealTypePicker: View {
    let mode: MealsSection.PickerMode
    let onConfirm: (MealType) -> Void
    @State private var selected: MealType
    /// the sheet hugs its content, like the web's; a large type size grows it
    @State private var contentHeight: CGFloat = 440
    @Environment(\.dismiss) private var dismiss
    @Environment(AppLanguageStore.self) private var language

    init(mode: MealsSection.PickerMode, onConfirm: @escaping (MealType) -> Void) {
        self.mode = mode
        self.onConfirm = onConfirm
        if case .rename(let meal) = mode {
            _selected = State(initialValue: meal.type)
        } else {
            _selected = State(initialValue: MealType.all[0])
        }
    }

    private var isAdd: Bool {
        if case .add = mode { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(isAdd ? "diet.meals.addTitle" : "diet.meals.renameTitle", bundle: .l10n)
                .font(Font.geist(15, relativeTo: .headline).weight(.semibold))
                .foregroundStyle(Color.fg)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 8) {
                ForEach(MealType.all, id: \.self) { type in
                    let active = type == selected
                    Button { selected = type } label: {
                        Text(verbatim: mealLabel(type, lang: language.lang))
                            .font(Font.geist(14, relativeTo: .subheadline).weight(.medium))
                            .foregroundStyle(active ? Color.accTx : Color.mutedFg)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(.horizontal, 12)
                            .background(active ? Color.accBg : Color.chip, in: RoundedRectangle(cornerRadius: 10))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(active ? Color.acc : Color.border, lineWidth: 1)
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(active ? .isSelected : [])
                }
            }
            .padding(.top, 16)

            HStack(spacing: 8) {
                // bordered, muted (`border border-border text-muted-foreground`)
                Button { dismiss() } label: {
                    Text("common.cancel", bundle: .l10n)
                        .font(DSFont.button.weight(.medium))
                        .foregroundStyle(Color.mutedFg)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .overlay { RoundedRectangle(cornerRadius: 11).strokeBorder(Color.border, lineWidth: 1) }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button { onConfirm(selected) } label: {
                    Text(isAdd ? "diet.meals.add" : "diet.meals.save", bundle: .l10n).frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
            }
            .padding(.top, 16)
        }
        .padding(20)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.card)
        .presentationDetents([.height(contentHeight)])
        .presentationDragIndicator(.visible)
    }
}
