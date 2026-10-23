import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// The web's `QuantitySheet`, every way into a meal goes through it: the
/// food, [1 unidade] [Gramas] when it has a household measure, − field +
/// (0,5 unidade / 10 g), "= N g" in servings, presets, the kcal/P/C/G line,
/// then Cancelar / Adicionar (or Atualizar). Confirms grams + the hint.
struct QuantitySheetView: View {
    let confirmLabel: LocalizedStringKey
    let onConfirm: (Portion) -> Void
    @State private var input: QuantityInput
    /// hugs its content, like the meal-name picker
    @State private var contentHeight: CGFloat = 460
    @Environment(\.dismiss) private var dismiss
    @Environment(AppLanguageStore.self) private var language

    init(food: FoodListItem, initial: Portion, lang: Lang, confirmLabel: LocalizedStringKey, onConfirm: @escaping (Portion) -> Void) {
        self.confirmLabel = confirmLabel
        self.onConfirm = onConfirm
        // the PT keypad types ",", so the prefilled value uses it too
        _input = State(initialValue: QuantityInput(food: food, initial: initial, separator: lang == .pt ? "," : "."))
    }

    var body: some View {
        let lang = language.lang
        let food = input.food
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: food.name)
                .font(Font.geist(15, relativeTo: .headline).weight(.semibold))
                .foregroundStyle(Color.fg)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let brand = food.brand {
                Text(verbatim: brand)
                    .font(Font.geist(11.5, relativeTo: .caption))
                    .foregroundStyle(Color.mutedFg)
                    .lineLimit(1)
                    .padding(.top, 2)
            }

            if input.servingAvailable, let slug = food.servingLabel {
                HStack(spacing: 8) {
                    modeButton(.serving, label: "\(Quantity.number(1, lang: lang)) \(unit(slug, count: 1, lang: lang))")
                    modeButton(.grams, label: L10n.string("diet.quantity.grams", lang: lang))
                }
                .padding(.top, 16)
            }

            HStack(spacing: 16) {
                stepButton("minus", label: "diet.quantity.decrease") { input.nudge(up: false) }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField(text: $input.raw) { Text("diet.quantity.title", bundle: .l10n) }
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(Font.geist(18, relativeTo: .title3).weight(.semibold))
                        .foregroundStyle(Color.fg)
                        .frame(width: 96, height: 44)
                        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Color.border, lineWidth: 1) }
                    Text(verbatim: input.mode == .serving
                        ? food.servingLabel.map { unit($0, count: input.labelCount, lang: lang) } ?? ""
                        : L10n.string("diet.quantity.gramsShort", lang: lang))
                        .font(Font.geist(13, relativeTo: .footnote))
                        .foregroundStyle(Color.mutedFg)
                }
                stepButton("plus", label: "diet.quantity.increase") { input.nudge(up: true) }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16)

            if input.mode == .serving {
                Text("diet.quantity.equals \(Quantity.number(input.grams, lang: lang))", bundle: .l10n)
                    .font(Font.geist(12, relativeTo: .caption))
                    .foregroundStyle(Color.mutedFg)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }

            FlowLayout(spacing: 8) {
                ForEach(input.presets, id: \.self) { preset in
                    Button { input.pick(preset) } label: {
                        Chip(input.mode == .grams
                            ? "\(Quantity.number(preset, lang: lang)) \(L10n.string("diet.quantity.gramsShort", lang: lang))"
                            : Quantity.number(preset, lang: lang))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16)

            preview(lang: lang)
                .padding(.top, 16)

            HStack(spacing: 8) {
                Button { dismiss() } label: {
                    Text("common.cancel", bundle: .l10n)
                        .font(DSFont.button.weight(.medium))
                        .foregroundStyle(Color.mutedFg)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .overlay { RoundedRectangle(cornerRadius: 11).strokeBorder(Color.border, lineWidth: 1) }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button {
                    if let portion = input.portion { onConfirm(portion) }
                } label: {
                    Text(confirmLabel, bundle: .l10n).frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
                .disabled(input.portion == nil)
            }
            .padding(.top, 16)
        }
        .monospacedDigit()
        .padding(20)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.card)
        .presentationDetents([.height(contentHeight)])
        .presentationDragIndicator(.visible)
    }

    private func unit(_ slug: String, count: Double, lang: Lang) -> String {
        Quantity.unitLabel(slug, count: count, lang: lang) { L10n.string($0, lang: lang) }
    }

    private func modeButton(_ mode: QuantityInput.Mode, label: String) -> some View {
        let active = input.mode == mode
        return Button { input.switchMode(mode) } label: {
            Text(verbatim: label)
                .font(Font.geist(13, relativeTo: .footnote).weight(.medium))
                .foregroundStyle(active ? Color.accTx : Color.mutedFg)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(active ? Color.accBg : Color.chip, in: RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(active ? Color.acc : Color.border, lineWidth: 1) }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private func stepButton(_ symbol: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.fg)
                .frame(width: 36, height: 36)
                .background(Color.chip, in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label, bundle: .l10n))
    }

    /// "146 kcal · P 13g · C 1g · G 10g" (the web keeps "G" in English too)
    private func preview(lang: Lang) -> some View {
        let macros = input.preview
        return (Text(verbatim: "\(macros.kcal)").fontWeight(.semibold).foregroundStyle(Color.fg)
            + Text(verbatim: " \(L10n.string("diet.overview.kcal", lang: lang)) · P \(macros.protein)g · C \(macros.carbs)g · G \(macros.fat)g"))
            .font(Font.geist(12.5, relativeTo: .footnote))
            .foregroundStyle(Color.mutedFg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color.chip, in: RoundedRectangle(cornerRadius: 10))
    }
}
