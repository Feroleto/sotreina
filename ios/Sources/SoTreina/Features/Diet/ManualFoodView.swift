import os
import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// The web's `AddManualFoodPage`: name, a free-text portion, an optional
/// household unit, and kcal/macros for that portion (normalized to 100 g in
/// `ManualFoodDraft.request`). Reached from "Adicionar manualmente" or from a
/// scanner 404, which links the food to the code. The created food goes
/// straight into the QuantitySheet, like the web.
struct ManualFoodView: View {
    let onCreated: (FoodListItem) -> Void
    @State private var draft: ManualFoodDraft
    @State private var submitting = false
    @State private var failed = false
    @FocusState private var focused: Field?
    @Environment(SessionStore.self) private var session
    @Environment(AppLanguageStore.self) private var language

    private static let log = Logger(subsystem: "com.feroleto.sotreina", category: "diet")

    enum Field: Hashable {
        case name, portion, kcal, protein, carbs, fat
    }

    init(externalId: String?, onCreated: @escaping (FoodListItem) -> Void) {
        self.onCreated = onCreated
        _draft = State(initialValue: ManualFoodDraft(externalId: externalId))
    }

    var body: some View {
        let lang = language.lang
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                field("diet.manual.name", text: $draft.name, focus: .name)
                    .textInputAutocapitalization(.sentences)
                field("diet.manual.portion", text: $draft.portion, focus: .portion, placeholder: "diet.manual.portionPlaceholder")
                unitPicker(lang: lang)
                field("diet.manual.kcal", text: $draft.kcal, focus: .kcal, numeric: true)
                HStack(alignment: .top, spacing: 12) {
                    field("diet.manual.protein", text: $draft.protein, focus: .protein, numeric: true)
                    field("diet.manual.carbs", text: $draft.carbs, focus: .carbs, numeric: true)
                    field("diet.manual.fat", text: $draft.fat, focus: .fat, numeric: true)
                }

                if failed {
                    Text("diet.manual.error", bundle: .l10n)
                        .font(DSFont.caption)
                        .foregroundStyle(Color.neg)
                }

                Button {
                    Task { await submit() }
                } label: {
                    Text(submitting ? "diet.manual.saving" : "diet.manual.save", bundle: .l10n)
                }
                .buttonStyle(.primary)
                .disabled(submitting || !draft.isValid)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, pageGutter)
            .padding(.top, 18)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.pageBg)
        .navigationTitle(Text("diet.manual.title", bundle: .l10n))
        .navigationBarTitleDisplayMode(.inline)
        .hidesFloatingTabBar()
        // the decimal pad has no return key, and the form is too short to drag
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button { focused = nil } label: { Text("common.ok", bundle: .l10n) }
            }
        }
    }

    // MARK: Fields

    /// Caption over a bordered 16 pt field (`rounded-[11px] border`), the
    /// web's `Field`. Numbers take the decimal pad, whose "," the Kit reads.
    private func field(
        _ label: LocalizedStringKey, text: Binding<String>, focus: Field,
        placeholder: LocalizedStringKey? = nil, numeric: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label, bundle: .l10n)
                .font(Font.geist(12.5, relativeTo: .caption).weight(.medium))
                .foregroundStyle(Color.mutedFg)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            TextField(text: text) {
                if let placeholder { Text(placeholder, bundle: .l10n) } else { Text(verbatim: "") }
            }
            .font(Font.geist(16, relativeTo: .body))
            .foregroundStyle(Color.fg)
            .keyboardType(numeric ? .decimalPad : .default)
            .autocorrectionDisabled(numeric)
            .focused($focused, equals: focus)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .overlay {
                RoundedRectangle(cornerRadius: 11)
                    .strokeBorder(focused == focus ? Color.acc : Color.border, lineWidth: 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The web's `<select>`, as a menu: "Nenhuma (só gramas)" or a unit.
    private func unitPicker(lang: Lang) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("diet.manual.unitLabel", bundle: .l10n)
                .font(Font.geist(12.5, relativeTo: .caption).weight(.medium))
                .foregroundStyle(Color.mutedFg)
            Menu {
                Picker(selection: $draft.unit) {
                    Text("diet.manual.unitNone", bundle: .l10n).tag(String?.none)
                    ForEach(Quantity.servingUnits, id: \.self) { slug in
                        Text(verbatim: unitName(slug, lang: lang)).tag(String?.some(slug))
                    }
                } label: {
                    EmptyView()
                }
            } label: {
                HStack {
                    Group {
                        if let unit = draft.unit {
                            Text(verbatim: unitName(unit, lang: lang))
                        } else {
                            Text("diet.manual.unitNone", bundle: .l10n)
                        }
                    }
                    .font(Font.geist(16, relativeTo: .body))
                    .foregroundStyle(Color.fg)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.mutedFg)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .overlay { RoundedRectangle(cornerRadius: 11).strokeBorder(Color.border, lineWidth: 1) }
            }
            Text("diet.manual.unitHelp", bundle: .l10n)
                .font(Font.geist(11.5, relativeTo: .caption))
                .foregroundStyle(Color.mutedFg)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// "1 unidade" reads as the unit's name, like the web's `unitLabel(slug, 1)`
    private func unitName(_ slug: String, lang: Lang) -> String {
        Quantity.unitLabel(slug, count: 1, lang: lang) { L10n.string($0, lang: lang) }
    }

    // MARK: Submit

    private func submit() async {
        guard let request = draft.request, !submitting else { return }
        submitting = true
        failed = false
        focused = nil
        do {
            guard let food: FoodListItem = try await session.api.post("foods/custom", body: request) else {
                throw APIError.invalidResponse
            }
            onCreated(food)
        } catch {
            if case APIError.unauthorized = error {
                session.expire()
            } else {
                Self.log.error("custom food failed: \(String(describing: error), privacy: .public)")
                failed = true
            }
        }
        submitting = false
    }
}
