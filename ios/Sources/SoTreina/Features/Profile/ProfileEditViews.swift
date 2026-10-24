import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// Perfil → Dados pessoais (web EditNamePage): the name is editable, the
/// email is read-only (it's the login).
struct EditNameView: View {
    let me: Me
    let store: ProfileStore
    @State private var name: String
    @State private var saving = false
    @State private var failed = false
    @Environment(\.dismiss) private var dismiss

    init(me: Me, store: ProfileStore) {
        self.me = me
        self.store = store
        _name = State(initialValue: me.firstName ?? "")
    }

    private var nameToSave: String? { ProfileRules.nameToSave(name, current: me.firstName) }

    var body: some View {
        Form {
            Section {
                TextField(text: $name) { Text("nav.profile.name", bundle: .l10n) }
                    .textContentType(.givenName)
                    .onChange(of: name) { _, typed in
                        if typed.count > ProfileRules.maxNameLength { name = String(typed.prefix(ProfileRules.maxNameLength)) }
                    }
            } header: {
                Text("nav.profile.name", bundle: .l10n)
            }

            Section {
                Group {
                    if let email = me.email { Text(verbatim: email) } else { Text("nav.profile.noEmail", bundle: .l10n) }
                }
                .foregroundStyle(Color.mutedFg)
            } header: {
                Text("nav.profile.email", bundle: .l10n)
            } footer: {
                Text("nav.profile.emailReadOnly", bundle: .l10n)
            }

            Section {
                if failed {
                    Text("nav.profile.saveError", bundle: .l10n).font(DSFont.caption).foregroundStyle(Color.neg)
                }
                Button {
                    Task { await save() }
                } label: {
                    Text(saving ? "nav.profile.saving" : "nav.profile.save", bundle: .l10n).frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
                .disabled(nameToSave == nil || saving)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .monolitoForm()
        .navigationTitle(Text("nav.profile.personalData", bundle: .l10n))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save() async {
        guard let firstName = nameToSave else { return }
        saving = true
        failed = false
        do {
            try await store.save(MeSettingsPatch(firstName: firstName))
            dismiss()
        } catch {
            failed = true
        }
        saving = false
    }
}

/// Perfil → Metas semanais (web WeeklyGoalsPage): steppers of the enabled
/// areas; both goals are still saved as-is.
struct WeeklyGoalsView: View {
    let settings: MeSettings
    let areas: [Area]
    let unit: DistanceUnit
    let store: ProfileStore
    @State private var run: Int
    @State private var workouts: Int
    @State private var saving = false
    @State private var failed = false
    @Environment(\.dismiss) private var dismiss

    init(settings: MeSettings, areas: [Area], unit: DistanceUnit, store: ProfileStore) {
        self.settings = settings
        self.areas = areas
        self.unit = unit
        self.store = store
        // the stepper works in whole display units (km or mi); the DB keeps whole km
        _run = State(initialValue: UnitConversion.goalDisplay(km: settings.weeklyRunKmGoal, in: unit))
        _workouts = State(initialValue: settings.weeklyWorkoutsGoal)
    }

    var body: some View {
        List {
            Section {
                if areas.contains(.run) {
                    goalRow(
                        label: Text("today.goals.runKm", bundle: .l10n),
                        unitText: Text("today.goals.runKmUnit \(UnitConversion.label(unit))", bundle: .l10n),
                        stepper: ValueStepper(value: $run, in: ProfileRules.runGoalRange(unit))
                    )
                }
                if areas.contains(.gym) {
                    goalRow(
                        label: Text("today.goals.workouts", bundle: .l10n),
                        unitText: Text("today.goals.workoutsUnit", bundle: .l10n),
                        stepper: ValueStepper(value: $workouts, in: ProfileRules.workoutsRange)
                    )
                }
            } header: {
                Text("today.goals.subtitle", bundle: .l10n)
                    .font(DSFont.meta)
                    .foregroundStyle(Color.mutedFg)
                    .textCase(nil)
            }
            .listRowBackground(Color.pageBg)

            SaveSection(failed: failed, saving: saving, saveKey: "today.goals.save", savingKey: "today.goals.saving") {
                Task { await save() }
            }
        }
        .monolitoList()
        .navigationTitle(Text("today.goals.title", bundle: .l10n))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func goalRow(label: Text, unitText: Text, stepper: ValueStepper) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                label.font(DSFont.row)
                unitText.font(DSFont.caption).foregroundStyle(Color.mutedFg)
            }
            Spacer(minLength: 8)
            stepper
        }
        .padding(.vertical, 6)
    }

    private func save() async {
        saving = true
        failed = false
        do {
            try await store.save(MeSettingsPatch(
                weeklyRunKmGoal: ProfileRules.runKmToSave(display: run, storedKm: settings.weeklyRunKmGoal, unit: unit),
                weeklyWorkoutsGoal: workouts
            ))
            dismiss()
        } catch {
            failed = true
        }
        saving = false
    }
}

/// Perfil → Meta diária (web diet/GoalPage): kcal and the three macros, with
/// the macros' kcal checked against the goal.
struct DietGoalView: View {
    let store: ProfileStore
    @State private var kcal: Int
    @State private var protein: Int
    @State private var carbs: Int
    @State private var fat: Int
    @State private var saving = false
    @State private var failed = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(settings: MeSettings, store: ProfileStore) {
        self.store = store
        _kcal = State(initialValue: settings.dailyKcalGoal)
        _protein = State(initialValue: settings.dailyProteinGoal)
        _carbs = State(initialValue: settings.dailyCarbsGoal)
        _fat = State(initialValue: settings.dailyFatGoal)
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    ValueStepper(value: $kcal, in: ProfileRules.kcalRange, step: ProfileRules.kcalStep) {
                        "\($0.formatted(.number.locale(locale))) kcal"
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
                // the row's separators run from the edge, not from the stepper
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            } header: {
                Text("diet.goal.calories", bundle: .l10n).font(DSFont.sectionTitle).foregroundStyle(Color.fg).textCase(nil)
            }
            .listRowBackground(Color.pageBg)

            Section {
                macroRow("diet.macro.protein", grams: $protein, kcalPerGram: 4)
                macroRow("diet.macro.carbs", grams: $carbs, kcalPerGram: 4)
                macroRow("diet.macro.fat", grams: $fat, kcalPerGram: 9)
                matchRow
            }
            .listRowBackground(Color.pageBg)

            SaveSection(failed: failed, saving: saving, saveKey: "diet.goal.save", savingKey: "diet.goal.saving") {
                Task { await save() }
            }
        }
        .monolitoList()
        .navigationTitle(Text("diet.goal.title", bundle: .l10n))
        .floatingTabBarSpace()
        .navigationBarTitleDisplayMode(.inline)
    }

    private func macroRow(_ key: LocalizedStringKey, grams: Binding<Int>, kcalPerGram: Int) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(key, bundle: .l10n).font(DSFont.row)
                Text("diet.goal.pctOfCalories \(ProfileRules.pctOfCalories(grams: grams.wrappedValue, kcalPerGram: kcalPerGram, kcalGoal: kcal))", bundle: .l10n)
                    .font(DSFont.caption)
                    .foregroundStyle(Color.mutedFg)
            }
            Spacer(minLength: 8)
            ValueStepper(value: grams, in: ProfileRules.macroRange, step: ProfileRules.macroStep) { "\($0)g" }
        }
        .padding(.vertical, 4)
    }

    private var matchRow: some View {
        let match = ProfileRules.macroMatch(kcalGoal: kcal, protein: protein, carbs: carbs, fat: fat)
        let calculated = ProfileRules.calculatedKcal(protein: protein, carbs: carbs, fat: fat)
        return HStack(spacing: 8) {
            Text("diet.goal.calculated \(calculated)", bundle: .l10n)
                .foregroundStyle(Color.mutedFg)
            Spacer(minLength: 8)
            Group {
                switch match {
                case .matches: Text("diet.goal.matches", bundle: .l10n)
                case .above(let pct): Text("diet.goal.aboveTarget \(pct)", bundle: .l10n)
                case .below(let pct): Text("diet.goal.belowTarget \(pct)", bundle: .l10n)
                }
            }
            .fontWeight(.medium)
            .foregroundStyle(match == .matches ? Color.pos : Color.neg)
            .multilineTextAlignment(.trailing)
        }
        .font(DSFont.caption)
        .listRowBackground(Color.chip)
    }

    private func save() async {
        saving = true
        failed = false
        do {
            try await store.save(MeSettingsPatch(
                dailyKcalGoal: kcal,
                dailyProteinGoal: protein,
                dailyCarbsGoal: carbs,
                dailyFatGoal: fat
            ))
            dismiss()
        } catch {
            failed = true
        }
        saving = false
    }
}

/// The error line and the full-width primary button under a goals page.
private struct SaveSection: View {
    let failed: Bool
    let saving: Bool
    let saveKey: LocalizedStringKey
    let savingKey: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Section {
            if failed {
                Text("nav.profile.saveError", bundle: .l10n)
                    .font(DSFont.caption)
                    .foregroundStyle(Color.neg)
                    .listRowSeparator(.hidden)
            }
            Button(action: action) {
                Text(saving ? savingKey : saveKey, bundle: .l10n).frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary)
            .disabled(saving)
            .listRowSeparator(.hidden)
            .padding(.top, 12)
        }
        .listRowBackground(Color.pageBg)
    }
}
