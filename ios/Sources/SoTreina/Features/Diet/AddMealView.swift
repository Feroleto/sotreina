import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// One meal's "Adicionar" (the web's `AddMealPage`): the meal and today's
/// date on top, the search, the scanner and Refeições salvas, "Nesta
/// refeição" with the saved Registros and the cart, the results, the manual
/// cadastro link, and the bottom bar with the totals and "Salvar refeição".
/// Every food goes through the QuantitySheet, whichever way it came in;
/// tapping a row in the meal reopens it.
struct AddMealView: View {
    @State private var store: AddMealStore
    @State private var query = ""
    @State private var sheet: SheetTarget?
    @State private var scanning = false
    /// what the scan found, acted on once the scanner is gone: a product
    /// opens the sheet, a 404 code the manual cadastro linked to it
    @State private var scanned: ScanOutcome?
    @State private var manual: ManualTarget?
    @State private var savedMeals: SavedMealsStore
    @State private var showingSavedMeals = false
    /// "Salvar como refeição salva": the editor seeded with the cart
    @State private var savingCart: SavedMealEditTarget?
    /// set by the editor's save; the list opens once the cover is gone
    @State private var cartSaved = false
    @Environment(\.dismiss) private var dismiss
    @Environment(AppLanguageStore.self) private var language

    init(meal: Meal, diet: DietStore) {
        _store = State(initialValue: AddMealStore(meal: meal, diet: diet))
        _savedMeals = State(initialValue: SavedMealsStore(session: diet.session))
    }

    /// What the sheet edits: a new food, a cart item, or a saved Registro.
    enum SheetTarget: Identifiable {
        case new(FoodListItem)
        case cart(MealCart.Item)
        case saved(FoodLogItem)

        var id: String {
            switch self {
            case .new(let food): "new-\(food.id)"
            case .cart(let item): item.clientId.uuidString
            case .saved(let entry): entry.id
            }
        }

        var food: FoodListItem {
            switch self {
            case .new(let food): food
            case .cart(let item): item.food
            case .saved(let entry): entry.food
            }
        }

        var initial: Portion {
            switch self {
            case .new(let food): Quantity.defaultPortion(food)
            case .cart(let item): item.portion
            case .saved(let entry): Portion(quantity: entry.quantity, enteredAsServing: entry.enteredAsServing)
            }
        }
    }

    enum ScanOutcome {
        case found(FoodListItem)
        case notFound(String)
    }

    /// The manual cadastro, linked to the scanned code after a 404.
    struct ManualTarget: Identifiable, Hashable {
        let externalId: String?
        var id: String { externalId ?? "" }
    }

    var body: some View {
        let lang = language.lang
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    SearchField(text: $query)
                    scanButton
                    savedMealsButton
                }
                .padding(.top, 16)
                if store.cart.totalItems(saved: store.saved) > 0 {
                    inThisMeal(lang: lang)
                        .padding(.top, 20)
                }
                results(lang: lang)
                    .padding(.top, 20)
                Button { manual = ManualTarget(externalId: nil) } label: {
                    Text("diet.addMeal.manualLink", bundle: .l10n)
                        .font(Font.geist(12.5, relativeTo: .footnote).weight(.medium))
                        .foregroundStyle(Color.acc)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                if let error = store.error {
                    Text(verbatim: error)
                        .font(DSFont.caption)
                        .foregroundStyle(Color.neg)
                        .padding(.top, 12)
                }
            }
            // an empty list must not shrink the scroll view to its padding
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, pageGutter)
            .padding(.bottom, 24)
            .monospacedDigit()
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Color.pageBg)
        .task(id: query) { await store.search.run(query) }
        // hidden behind the principal item; it's what the next screen's back button says
        .navigationTitle(Text(verbatim: mealLabel(store.meal.type, lang: lang)))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(verbatim: mealLabel(store.meal.type, lang: lang))
                        .font(Font.geist(15, relativeTo: .headline).weight(.semibold))
                        .foregroundStyle(Color.fg)
                    Text(verbatim: DietFormat.dayShort(.now, lang: lang, calendar: .current))
                        .font(Font.geist(11.5, relativeTo: .caption))
                        .foregroundStyle(Color.mutedFg)
                }
            }
        }
        // a full screen with its own bottom bar, like the web hides the pill
        .hidesFloatingTabBar()
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar(lang: lang) }
        .navigationDestination(isPresented: $showingSavedMeals) {
            SavedMealsListView(store: savedMeals, addMeal: store)
        }
        .fullScreenCover(item: $savingCart, onDismiss: {
            // like the web: the list, where the new one now shows. A push
            // can't start while the cover is still on screen
            if cartSaved { showingSavedMeals = true }
            cartSaved = false
        }) { target in
            SavedMealEditView(target: target, store: savedMeals) { cartSaved = true }
                .monolitoTheme()
        }
        .navigationDestination(item: $manual) { target in
            ManualFoodView(externalId: target.externalId) { food in
                manual = nil
                sheet = .new(food)
            }
        }
        .fullScreenCover(isPresented: $scanning, onDismiss: {
            // a sheet or a push can't start while the cover is still on screen
            switch scanned {
            case .found(let food): sheet = .new(food)
            case .notFound(let code): manual = ManualTarget(externalId: code)
            case nil: break
            }
            scanned = nil
        }) {
            BarcodeScannerView { food in
                scanned = .found(food)
                scanning = false
            } onNotFound: { code in
                scanned = .notFound(code)
                scanning = false
            }
        }
        .sheet(item: $sheet) { target in
            QuantitySheetView(
                food: target.food, initial: target.initial, lang: lang,
                confirmLabel: { if case .new = target { "diet.quantity.add" } else { "diet.quantity.update" } }()
            ) { portion in
                sheet = nil
                switch target {
                case .new(let food): store.add(food, portion)
                case .cart(let item): store.update(item, portion)
                case .saved(let entry): Task { await store.update(entry, portion) }
                }
            }
            .monolitoTheme()
        }
    }

    /// The web's square buttons beside the search (`h-[42px] rounded-[10px] bg-chip`).
    private var scanButton: some View {
        squareButton("barcode.viewfinder", label: "diet.addMeal.scanBarcode") { scanning = true }
    }

    private var savedMealsButton: some View {
        squareButton("bookmark", label: "diet.savedMeals.listTitle") { showingSavedMeals = true }
    }

    private func squareButton(_ icon: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.mutedFg)
                .frame(width: 42, height: 42)
                .background(Color.chip, in: RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Color.border, lineWidth: 1) }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label, bundle: .l10n))
    }

    // MARK: Nesta refeição

    private func inThisMeal(lang: Lang) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            CapsTitle(Text("diet.addMeal.inThisMeal", bundle: .l10n))
                .padding(.bottom, 4)
            ForEach(store.saved) { entry in
                FoodRow(
                    name: entry.food.name,
                    subtitle: subtitleText(entry.food, quantity: entry.quantity, enteredAsServing: entry.enteredAsServing, lang: lang),
                    onTap: { sheet = .saved(entry) }
                ) {
                    removeButton { Task { await store.remove(entry) } }
                }
            }
            ForEach(store.cart.items) { item in
                cartRow(item, lang: lang)
            }
            let staged = store.cartAsSavedMealItems
            if !staged.isEmpty {
                Button { savingCart = SavedMealEditTarget(seed: staged) } label: {
                    Text("diet.savedMeals.saveCurrentAsMeal", bundle: .l10n)
                        .font(Font.geist(12.5, relativeTo: .footnote).weight(.medium))
                        .foregroundStyle(Color.acc)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
    }

    @ViewBuilder private func cartRow(_ item: MealCart.Item, lang: Lang) -> some View {
        let text: String = subtitle(item.food, quantity: item.quantity, enteredAsServing: item.enteredAsServing, lang: lang)
        switch item.status {
        case .staged:
            FoodRow(name: item.food.name, subtitle: Text(verbatim: text), onTap: { sheet = .cart(item) }) {
                removeButton { store.remove(item) }
            }
        case .sending:
            FoodRow(name: item.food.name, subtitle: Text(verbatim: text), onTap: nil) {
                ProgressView().frame(width: 28, height: 28)
            }
        case .failed:
            // locked: it may already be on the server, a resend answers with what's stored
            FoodRow(
                name: item.food.name,
                subtitle: Text(Image(systemName: "exclamationmark.triangle.fill")).foregroundStyle(Color.neg)
                    + Text(verbatim: " ") + Text("diet.addMeal.notSent", bundle: .l10n).foregroundStyle(Color.neg)
                    + Text(verbatim: " · \(text)"),
                onTap: nil
            ) {
                removeButton { store.remove(item) }
            }
        }
    }

    // MARK: Results

    @ViewBuilder private func results(lang: Lang) -> some View {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                CapsTitle(Text("diet.addMeal.searchResults", bundle: .l10n))
                    .padding(.bottom, 4)
                if store.search.searching {
                    Text("diet.addMeal.loading", bundle: .l10n)
                        .font(DSFont.meta)
                        .foregroundStyle(Color.mutedFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                } else if store.search.results.isEmpty {
                    Text("diet.addMeal.noResults \(trimmed)", bundle: .l10n)
                        .font(DSFont.meta)
                        .foregroundStyle(Color.mutedFg)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                } else {
                    ForEach(store.search.results) { food in
                        resultRow(food, lang: lang)
                    }
                }
            }
        }
    }

    private func resultRow(_ food: FoodListItem, lang: Lang) -> some View {
        let inCart = store.cart.contains(foodId: food.id)
        // previews the portion the sheet opens on
        let preview = Quantity.defaultPortion(food)
        return FoodRow(
            name: food.name,
            subtitle: subtitleText(food, quantity: preview.quantity, enteredAsServing: preview.enteredAsServing, lang: lang),
            onTap: { sheet = .new(food) }
        ) {
            // already staged: one tap clears it; otherwise the shortcut into the sheet
            Button {
                if inCart { store.removeFromCart(foodId: food.id) } else { sheet = .new(food) }
            } label: {
                Image(systemName: inCart ? "checkmark" : "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(inCart ? Color.accTx : Color.acc)
                    .frame(width: 32, height: 32)
                    .background(inCart ? Color.accBg : Color.chip, in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(verbatim: food.name))
        }
    }

    // MARK: Bottom bar

    private func bottomBar(lang: Lang) -> some View {
        let count = store.cart.totalItems(saved: store.saved)
        let kcal = Int(store.cart.totalKcal(saved: store.saved).rounded())
        return HStack(spacing: 12) {
            (Text("diet.overview.items \(count)", bundle: .l10n)
                + Text(verbatim: " · \(DietFormat.integer(kcal, lang: lang)) \(L10n.string("diet.overview.kcal", lang: lang))"))
                .font(Font.geist(12.5, relativeTo: .footnote))
                .foregroundStyle(Color.mutedFg)
                .monospacedDigit()
            Spacer(minLength: 8)
            Button {
                Task { if await store.save() { dismiss() } }
            } label: {
                Text(store.saving ? "diet.addMeal.saving" : "diet.addMeal.save", bundle: .l10n)
            }
            .buttonStyle(.primary)
            .fixedSize()
            .disabled(store.saving)
        }
        .padding(.horizontal, pageGutter)
        .padding(.vertical, 12)
        .background(Color.card)
        .overlay(alignment: .top) { Hairline() }
    }

    // MARK: Helpers

    private func subtitle(_ food: FoodListItem, quantity: Double, enteredAsServing: Bool, lang: Lang) -> String {
        foodSubtitle(food, quantity: quantity, enteredAsServing: enteredAsServing, lang: lang)
    }

    private func subtitleText(_ food: FoodListItem, quantity: Double, enteredAsServing: Bool, lang: Lang) -> Text {
        Text(verbatim: subtitle(food, quantity: quantity, enteredAsServing: enteredAsServing, lang: lang))
    }

    private func removeButton(action: @escaping () -> Void) -> some View {
        FoodRemoveButton(action: action)
    }
}

/// "2 unidades (100 g) · 146 kcal"
func foodSubtitle(_ food: FoodListItem, quantity: Double, enteredAsServing: Bool, lang: Lang) -> String {
    let portion = Quantity.format(food, quantity: quantity, enteredAsServing: enteredAsServing, lang: lang) {
        L10n.string($0, lang: lang)
    }
    let kcal = Int(Quantity.kcal(food, quantity: quantity).rounded())
    return "\(portion) · \(kcal) \(L10n.string("diet.overview.kcal", lang: lang))"
}

/// The × at the end of a food row.
struct FoodRemoveButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.mutedFg)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("diet.addMeal.remove", bundle: .l10n))
    }
}

/// Name over "2 unidades (100 g) · 146 kcal", a trailing control, a hairline.
struct FoodRow<Trailing: View>: View {
    let name: String
    let subtitle: Text
    let onTap: (() -> Void)?
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 8) {
            if let onTap {
                Button(action: onTap) { label }
                    .buttonStyle(.plain)
            } else {
                label
            }
            trailing()
                .padding(.trailing, -8)
        }
        .frame(minHeight: 56)
        .overlay(alignment: .bottom) { Hairline() }
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: name)
                .font(Font.geist(14, relativeTo: .subheadline).weight(.medium))
                .foregroundStyle(Color.fg)
                .lineLimit(1)
            subtitle
                .font(Font.geist(11.5, relativeTo: .caption))
                .foregroundStyle(Color.mutedFg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// The web's search box (`rounded-[10px] border bg-chip`, 16 pt so it reads
/// like the input), with a clear button. A plain field rather than
/// `.searchable`: the scanner and Refeições salvas buttons go beside it.
struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(Color.mutedFg)
            TextField(text: $text) { Text("diet.addMeal.searchPlaceholder", bundle: .l10n) }
                .font(Font.geist(16, relativeTo: .body))
                .foregroundStyle(Color.fg)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.mutedFg)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("common.cancel", bundle: .l10n))
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .frame(minHeight: 42)
        .background(Color.chip, in: RoundedRectangle(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Color.border, lineWidth: 1) }
    }
}
