import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// "Refeições salvas" (the web's `SavedMealsListPage`), pushed from a
/// meal's Adicionar: a card per saved meal (name, the first foods, kcal,
/// edit and delete) with "Usar", which writes its foods into that meal and
/// goes back to Adicionar, where they show under "Nesta refeição".
struct SavedMealsListView: View {
    let store: SavedMealsStore
    let addMeal: AddMealStore
    @State private var editing: SavedMealEditTarget?
    @State private var deleting: SavedMealSummary?
    @Environment(\.dismiss) private var dismiss
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                content
                Button { editing = SavedMealEditTarget(seed: []) } label: {
                    Label { Text("diet.savedMeals.createNew", bundle: .l10n) } icon: { Image(systemName: "plus") }
                        .font(Font.geist(13.5, relativeTo: .subheadline).weight(.medium))
                        .foregroundStyle(Color.acc)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .overlay {
                            RoundedRectangle(cornerRadius: 11)
                                .strokeBorder(Color.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                if let error = addMeal.applyError ?? store.actionError {
                    Text(verbatim: error)
                        .font(DSFont.caption)
                        .foregroundStyle(Color.neg)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, pageGutter)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .monospacedDigit()
        }
        .background(Color.pageBg)
        .navigationTitle(Text("diet.savedMeals.listTitle", bundle: .l10n))
        .navigationBarTitleDisplayMode(.inline)
        // "Café da manhã" doesn't fit beside this title, and the system's
        // fallback is "Back" in the iPhone's language: the chevron alone
        .toolbarRole(.editor)
        .hidesFloatingTabBar()
        .task { await store.load() }
        .onDisappear { addMeal.applyError = nil }
        .fullScreenCover(item: $editing) { target in
            SavedMealEditView(target: target, store: store)
                .monolitoTheme()
        }
        .confirmationDialog(
            Text("diet.savedMeals.deleteConfirm", bundle: .l10n),
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible,
            presenting: deleting
        ) { meal in
            Button(role: .destructive) {
                Task { await store.remove(meal) }
            } label: {
                Text("diet.savedMeals.delete", bundle: .l10n)
            }
            Button(role: .cancel) {} label: { Text("common.cancel", bundle: .l10n) }
        }
    }

    @ViewBuilder private var content: some View {
        switch store.loadState {
        case .idle, .loading:
            if store.meals.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else {
                cards
            }
        case .failed(let message):
            VStack(spacing: 12) {
                Text(verbatim: message)
                    .font(DSFont.meta)
                    .foregroundStyle(Color.mutedFg)
                    .multilineTextAlignment(.center)
                Button { Task { await store.load() } } label: { Text("common.retry", bundle: .l10n) }
                    .buttonStyle(.chip)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        case .loaded:
            if store.meals.isEmpty {
                Text("diet.savedMeals.empty", bundle: .l10n)
                    .font(DSFont.meta)
                    .foregroundStyle(Color.mutedFg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                cards
            }
        }
    }

    private var cards: some View {
        ForEach(store.meals) { meal in
            card(meal)
        }
    }

    /// The web's card: name, preview and kcal beside ✎ and 🗑, "Usar" below.
    private func card(_ meal: SavedMealSummary) -> some View {
        let lang = language.lang
        let applyingThis = addMeal.applying == meal.id
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: meal.name)
                        .font(Font.geist(14, relativeTo: .subheadline).weight(.semibold))
                        .foregroundStyle(Color.fg)
                        .lineLimit(1)
                    Group {
                        if meal.itemCount > 0 {
                            Text(verbatim: meal.itemPreview.joined(separator: ", "))
                        } else {
                            Text("diet.savedMeals.noItems", bundle: .l10n)
                        }
                    }
                    .lineLimit(1)
                    Text(verbatim: "\(DietFormat.integer(Int(meal.totalKcal.rounded()), lang: lang)) \(L10n.string("diet.overview.kcal", lang: lang))")
                        .padding(.top, 1)
                }
                .font(Font.geist(11.5, relativeTo: .caption))
                .foregroundStyle(Color.mutedFg)
                .frame(maxWidth: .infinity, alignment: .leading)
                iconButton("pencil", label: "diet.savedMeals.edit") { editing = SavedMealEditTarget(editing: meal.id) }
                iconButton("trash", label: "diet.savedMeals.delete") { deleting = meal }
            }
            Button {
                Task { if await addMeal.apply(meal) { dismiss() } }
            } label: {
                if applyingThis {
                    ProgressView().tint(Color.accFg)
                } else {
                    Text("diet.savedMeals.use", bundle: .l10n)
                }
            }
            .buttonStyle(.primary)
            .disabled(addMeal.applying != nil || !meal.canApply)
        }
        .padding(14)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.border, lineWidth: 1) }
    }

    private func iconButton(_ icon: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.mutedFg)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label, bundle: .l10n))
    }
}
