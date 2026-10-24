import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// What the editor opens on: a new saved meal (empty, or seeded from the
/// cart by "Salvar como refeição salva") or an existing one by id.
struct SavedMealEditTarget: Identifiable {
    let id = UUID()
    let mealId: String?
    let seed: [SavedMealDraft.Item]

    init(seed: [SavedMealDraft.Item]) {
        mealId = nil
        self.seed = seed
    }

    init(editing mealId: String) {
        self.mealId = mealId
        seed = []
    }
}

/// "Nova refeição salva" / "Editar refeição salva" (the web's
/// `SavedMealEditPage`): the name, the foods with their grams (tap opens the
/// QuantitySheet, × removes) and a search whose "+" adds one household
/// measure. Everything stays in a `SavedMealDraft` until Salvar, one call;
/// Cancelar with changes asks first. Full screen, with its own stack, like
/// the routine editor.
struct SavedMealEditView: View {
    let target: SavedMealEditTarget
    let store: SavedMealsStore
    var onSaved: () -> Void = {}
    @State private var draft: SavedMealDraft
    /// editing: the meal hasn't arrived yet
    @State private var loading: Bool
    @State private var loadError: String?
    @State private var saving = false
    @State private var saveError: String?
    @State private var confirmingDiscard = false
    @State private var query = ""
    @State private var search: FoodSearch
    /// the item whose grams the sheet edits
    @State private var editingItem: SavedMealDraft.Item?
    @Environment(\.dismiss) private var dismiss
    @Environment(AppLanguageStore.self) private var language

    init(target: SavedMealEditTarget, store: SavedMealsStore, onSaved: @escaping () -> Void = {}) {
        self.target = target
        self.store = store
        self.onSaved = onSaved
        _draft = State(initialValue: SavedMealDraft(items: target.seed))
        _loading = State(initialValue: target.mealId != nil)
        _search = State(initialValue: FoodSearch(session: store.session))
    }

    var body: some View {
        let lang = language.lang
        NavigationStack {
            Group {
                if loading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let loadError {
                    VStack(spacing: 12) {
                        Text(verbatim: loadError)
                            .font(DSFont.meta)
                            .foregroundStyle(Color.mutedFg)
                            .multilineTextAlignment(.center)
                        Button { Task { await load() } } label: { Text("common.retry", bundle: .l10n) }
                            .buttonStyle(.chip)
                    }
                    .padding(.horizontal, pageGutter)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    form(lang: lang)
                }
            }
            .background(Color.pageBg)
            .navigationTitle(Text(target.mealId == nil ? "diet.savedMeals.newTitle" : "diet.savedMeals.editTitle", bundle: .l10n))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if draft.isDirty { confirmingDiscard = true } else { dismiss() }
                    } label: {
                        Text("common.cancel", bundle: .l10n)
                    }
                    .disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saving {
                        ProgressView()
                    } else {
                        Button { Task { await save() } } label: {
                            Text("diet.savedMeals.save", bundle: .l10n).bold()
                        }
                        .disabled(loading || loadError != nil || !draft.canSave)
                    }
                }
            }
            .confirmationDialog(Text("diet.savedMeals.discardConfirm", bundle: .l10n), isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button(role: .destructive) { dismiss() } label: { Text("diet.savedMeals.discard", bundle: .l10n) }
                Button(role: .cancel) {} label: { Text("gym.editor.keepEditing", bundle: .l10n) }
            }
            .sheet(item: $editingItem) { item in
                // grams only: a saved meal has no unit column, the sheet is just the input
                QuantitySheetView(
                    food: item.food, initial: Portion(quantity: item.quantity, enteredAsServing: false),
                    lang: lang, confirmLabel: "diet.quantity.update"
                ) { portion in
                    editingItem = nil
                    draft.update(item.id, quantity: portion.quantity)
                }
                .monolitoTheme()
            }
        }
        .interactiveDismissDisabled(draft.isDirty)
        .task { if target.mealId != nil, loading { await load() } }
    }

    private func form(lang: Lang) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                CapsTitle(Text("diet.savedMeals.nameLabel", bundle: .l10n))
                    .padding(.bottom, 8)
                TextField(text: $draft.name) { Text("diet.savedMeals.namePlaceholder", bundle: .l10n) }
                    .font(Font.geist(16, relativeTo: .body))
                    .foregroundStyle(Color.fg)
                    .submitLabel(.done)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.card, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Color.border, lineWidth: 1) }

                CapsTitle(Text("diet.savedMeals.itemsTitle", bundle: .l10n))
                    .padding(.top, 20)
                    .padding(.bottom, 4)
                if draft.items.isEmpty {
                    Text("diet.savedMeals.noItems", bundle: .l10n)
                        .font(DSFont.meta)
                        .foregroundStyle(Color.mutedFg)
                        .padding(.vertical, 16)
                } else {
                    ForEach(draft.items) { item in
                        FoodRow(
                            name: item.food.name,
                            subtitle: Text(verbatim: foodSubtitle(item.food, quantity: item.quantity, enteredAsServing: false, lang: lang)),
                            onTap: { editingItem = item }
                        ) {
                            FoodRemoveButton { draft.remove(item.id) }
                        }
                    }
                    Text(verbatim: "\(DietFormat.integer(Int(draft.totalKcal.rounded()), lang: lang)) \(L10n.string("diet.overview.kcal", lang: lang))")
                        .font(Font.geist(12, relativeTo: .caption).weight(.medium))
                        .foregroundStyle(Color.mutedFg)
                        .padding(.top, 8)
                }

                SearchField(text: $query)
                    .padding(.top, 20)
                results(lang: lang)

                if let saveError {
                    Text(verbatim: saveError)
                        .font(DSFont.caption)
                        .foregroundStyle(Color.neg)
                        .padding(.top, 12)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, pageGutter)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .monospacedDigit()
        }
        .scrollDismissesKeyboard(.immediately)
        .task(id: query) { await search.run(query) }
    }

    @ViewBuilder private func results(lang: Lang) -> some View {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            if search.searching {
                Text("diet.addMeal.loading", bundle: .l10n)
                    .font(DSFont.meta)
                    .foregroundStyle(Color.mutedFg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if search.results.isEmpty {
                Text("diet.addMeal.noResults \(trimmed)", bundle: .l10n)
                    .font(DSFont.meta)
                    .foregroundStyle(Color.mutedFg)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                ForEach(search.results) { food in
                    let preview = Quantity.defaultPortion(food)
                    FoodRow(
                        name: food.name,
                        subtitle: Text(verbatim: foodSubtitle(food, quantity: preview.quantity, enteredAsServing: preview.enteredAsServing, lang: lang)),
                        onTap: { add(food) }
                    ) {
                        Button { add(food) } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.acc)
                                .frame(width: 32, height: 32)
                                .background(Color.chip, in: Circle())
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: food.name))
                    }
                }
            }
        }
    }

    /// Like the web: adds one measure and clears the search.
    private func add(_ food: FoodListItem) {
        draft.add(food)
        query = ""
    }

    private func load() async {
        guard let id = target.mealId else { return }
        loading = true
        loadError = nil
        switch await store.detail(id) {
        case .success(let meal):
            draft = SavedMealDraft(meal: meal)
        case .failure(let error):
            if let message = error.message { loadError = message } else { dismiss() }
        }
        loading = false
    }

    private func save() async {
        saving = true
        saveError = nil
        switch await store.save(draft, id: target.mealId) {
        case .success:
            onSaved()
            dismiss()
        case .failure(let error):
            // nil = session expired, the app is going back to login
            saveError = error.message
        }
        saving = false
    }
}
