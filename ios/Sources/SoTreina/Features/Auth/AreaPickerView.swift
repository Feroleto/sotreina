import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// "O que você quer acompanhar?" (web `AreaPickerPage`, Redesign 21a):
/// shown once, while `enabledAreas` is empty — a new account, from the app
/// or the web — before the tabs. Perfil edits the same list later.
struct AreaPickerView: View {
    @Environment(SessionStore.self) private var session
    @Environment(AppLanguageStore.self) private var language
    @State private var selected: Set<Area> = []
    @State private var saving = false
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LogoMark()
                .frame(width: 34, height: 34)
            Text("onboarding.areas.title", bundle: .l10n)
                .font(DSFont.pageTitle)
                .padding(.top, 28)
            Text("onboarding.areas.subtitle", bundle: .l10n)
                .font(Font.geist(14, relativeTo: .subheadline))
                .foregroundStyle(Color.mutedFg)
                .padding(.top, 10)

            VStack(spacing: 0) {
                ForEach(Area.allCases, id: \.self) { area in
                    row(area)
                }
            }
            .overlay(alignment: .top) { Hairline() }
            .padding(.top, 28)

            Spacer(minLength: 32)

            VStack(spacing: 14) {
                status
                    .font(Font.geist(12.5, relativeTo: .caption))
                    .foregroundStyle(failed ? Color.neg : Color.mutedFg)
                Button {
                    Task { await confirm() }
                } label: {
                    if saving {
                        ProgressView().tint(Color.accFg)
                    } else {
                        Text("onboarding.areas.continue", bundle: .l10n)
                    }
                }
                .buttonStyle(.primary)
                .disabled(selected.isEmpty || saving)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)
        }
        .padding(.horizontal, pageGutter)
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.pageBg)
    }

    private var status: Text {
        if failed { return Text("onboarding.areas.error", bundle: .l10n) }
        if selected.isEmpty { return Text("onboarding.areas.countNone", bundle: .l10n) }
        return Text("onboarding.areas.count \(selected.count)", bundle: .l10n)
    }

    private func row(_ area: Area) -> some View {
        let on = selected.contains(area)
        return Button {
            if on { selected.remove(area) } else { selected.insert(area) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: area.tab.symbol)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.fg)
                    .frame(width: 42, height: 42)
                    .background(Color.chip, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(area.tab.label(language.lang))
                        .font(Font.geist(15.5, relativeTo: .body).weight(.medium))
                        .foregroundStyle(Color.fg)
                    Text(area.descriptionKey, bundle: .l10n)
                        .font(Font.geist(12.5, relativeTo: .caption))
                        .foregroundStyle(Color.mutedFg)
                }
                Spacer()
                if on {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.accFg)
                        .frame(width: 24, height: 24)
                        .background(Color.acc, in: Circle())
                } else {
                    Circle()
                        .strokeBorder(Color.mutedFg, lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(.vertical, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { Hairline() }
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func confirm() async {
        guard !selected.isEmpty, !saving else { return }
        saving = true
        failed = false
        do {
            // on success the session's Me gets the areas and RootView moves on
            try await session.saveAreas(EntryForm.canonicalAreas(selected))
        } catch {
            failed = true
        }
        saving = false
    }
}

private extension Area {
    var tab: AppTab {
        switch self {
        case .run: .run
        case .gym: .gym
        case .diet: .diet
        }
    }

    var descriptionKey: LocalizedStringKey {
        switch self {
        case .run: "onboarding.areas.runDesc"
        case .gym: "onboarding.areas.gymDesc"
        case .diet: "onboarding.areas.dietDesc"
        }
    }
}
