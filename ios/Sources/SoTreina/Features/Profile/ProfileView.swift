import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// Perfil (spec §2/§3, web Redesign 21d): the user row → name, the area
/// switches, the goals of the enabled areas, app preferences (theme,
/// language, units of the enabled areas) and the account. Strava and
/// "adicionar senha" stay on the web, behind a link.
struct ProfileView: View {
    let me: Me
    @State private var store: ProfileStore
    @Environment(SessionStore.self) private var session
    @Environment(AppLanguageStore.self) private var language

    init(session: SessionStore, me: Me) {
        self.me = me
        _store = State(initialValue: ProfileStore(session: session))
    }

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    EditNameView(me: me, store: store)
                } label: {
                    userRow
                }
                .listRowBackground(Color.pageBg)

                areasSection
                goalsSection
                appSection
                accountSection
                links
            }
            .monolitoList()
            .navigationTitle(Text("nav.profile.title", bundle: .l10n))
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await store.load() }
        }
        .task { await store.load() }
    }

    // MARK: User

    private var userRow: some View {
        HStack(spacing: 14) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                Group {
                    if let name = me.firstName, !name.isEmpty {
                        Text(verbatim: name)
                    } else {
                        Text("nav.runnerFallback", bundle: .l10n)
                    }
                }
                .font(Font.geist(15.5, relativeTo: .headline).weight(.medium))
                .foregroundStyle(Color.fg)
                Group {
                    if let email = me.email {
                        Text(verbatim: email)
                    } else {
                        Text("nav.profile.noEmail", bundle: .l10n)
                    }
                }
                .font(Font.geist(12.5, relativeTo: .caption))
                .foregroundStyle(Color.mutedFg)
            }
            .lineLimit(1)
        }
        .padding(.vertical, 6)
    }

    /// The Strava photo when there is one, the initials otherwise (and while
    /// it loads or if it fails).
    private var avatar: some View {
        let initials = Text(ProfileRules.initials(me.firstName))
            .font(Font.geist(15, relativeTo: .subheadline).weight(.semibold))
            .foregroundStyle(Color.fg)
            .frame(width: 48, height: 48)
            .background(Color.chip, in: Circle())
        return AsyncImage(url: me.profileImgUrl.flatMap(URL.init(string:))) { image in
            image.resizable().scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.fg.opacity(0.1), lineWidth: 1))
        } placeholder: {
            initials
        }
    }

    // MARK: Areas

    private var areasSection: some View {
        Section {
            header("nav.profile.areas")
            ForEach(Area.allCases, id: \.self) { area in
                let on = me.enabledAreas.contains(area)
                Toggle(isOn: Binding(get: { on }, set: { _ in Task { await store.toggle(area) } })) {
                    Label {
                        Text(area.tab.label(language.lang)).font(DSFont.row)
                    } icon: {
                        Image(systemName: area.tab.symbol).foregroundStyle(Color.mutedFg)
                    }
                }
                .tint(Color.acc)
                // at least one area stays on — none is the "not chosen yet" state
                .disabled(ProfileRules.isLocked(area, in: me.enabledAreas))
            }
            Group {
                if store.saveError == .areas {
                    Text("nav.profile.saveError", bundle: .l10n).foregroundStyle(Color.neg)
                } else {
                    Text("nav.profile.areasHint", bundle: .l10n).foregroundStyle(Color.mutedFg)
                }
            }
            .font(DSFont.caption)
            .listRowSeparator(.hidden)
        }
        .listRowBackground(Color.pageBg)
    }

    // MARK: Goals

    private var goalsSection: some View {
        Section {
            header("nav.profile.goals")
            ForEach(ProfileRules.goalAreas(me.enabledAreas), id: \.self) { area in
                NavigationLink {
                    if let settings = store.settings {
                        if area == .diet {
                            DietGoalView(settings: settings, store: store)
                        } else {
                            WeeklyGoalsView(settings: settings, areas: me.enabledAreas, unit: me.distanceUnit, store: store)
                        }
                    }
                } label: {
                    goalRow(area)
                }
                .disabled(store.settings == nil)
            }
            if store.loadFailed {
                Text("nav.profile.goalsLoadFailed", bundle: .l10n)
                    .font(DSFont.caption)
                    .foregroundStyle(Color.neg)
            }
        }
        .listRowBackground(Color.pageBg)
    }

    private func goalRow(_ area: Area) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(area.tab.label(language.lang)).font(DSFont.row)
                Text(goalDetailKey(area), bundle: .l10n)
                    .font(DSFont.caption)
                    .foregroundStyle(Color.mutedFg)
            }
            Spacer()
            Text(verbatim: goalValue(area))
                .font(Font.geistMono(14.5, relativeTo: .subheadline).weight(.medium))
        }
    }

    private func goalDetailKey(_ area: Area) -> LocalizedStringKey {
        switch area {
        case .run: "nav.profile.goalRunDetail"
        case .gym: "nav.profile.goalGymDetail"
        case .diet: "nav.profile.goalDietDetail"
        }
    }

    private func goalValue(_ area: Area) -> String {
        guard let settings = store.settings else { return "—" }
        switch area {
        case .run:
            let value = UnitConversion.goalDisplay(km: settings.weeklyRunKmGoal, in: me.distanceUnit)
            return "\(value) \(UnitConversion.label(me.distanceUnit))"
        case .gym:
            return "\(settings.weeklyWorkoutsGoal)"
        case .diet:
            return "\(settings.dailyKcalGoal.formatted(.number.locale(language.locale))) kcal"
        }
    }

    // MARK: App

    private var appSection: some View {
        Section {
            header("nav.profile.app")
            prefRow("nav.profile.theme") { ThemePicker().fixedSize() }
            prefRow("nav.profile.language") {
                Picker(selection: languageBinding) {
                    Text(verbatim: "PT").tag(AppLanguage.pt)
                    Text(verbatim: "EN").tag(AppLanguage.en)
                } label: {
                    Text("nav.profile.language", bundle: .l10n)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            // each unit only matters to its area: km/mi to Corrida, kg/lb to Treino
            if me.enabledAreas.contains(.run) {
                prefRow("nav.profile.unitsDistance") {
                    Picker(selection: Binding(get: { me.distanceUnit }, set: { unit in Task { await store.setDistanceUnit(unit) } })) {
                        ForEach(DistanceUnit.allCases, id: \.self) { Text(verbatim: UnitConversion.label($0)).tag($0) }
                    } label: {
                        Text("nav.profile.unitsDistance", bundle: .l10n)
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
            }
            if me.enabledAreas.contains(.gym) {
                prefRow("nav.profile.unitsWeight") {
                    Picker(selection: Binding(get: { me.weightUnit }, set: { unit in Task { await store.setWeightUnit(unit) } })) {
                        ForEach(WeightUnit.allCases, id: \.self) { Text(verbatim: UnitConversion.label($0)).tag($0) }
                    } label: {
                        Text("nav.profile.unitsWeight", bundle: .l10n)
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
            }
            if store.saveError == .units {
                Text("nav.profile.unitsError", bundle: .l10n)
                    .font(DSFont.caption)
                    .foregroundStyle(Color.neg)
            }
        }
        .listRowBackground(Color.pageBg)
    }

    /// PT/EN like the web's picker: the active one is the language in use,
    /// iPhone default included.
    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { language.lang == .en ? .en : .pt },
            set: { language.choice = $0 }
        )
    }

    private func prefRow(_ key: LocalizedStringKey, @ViewBuilder control: () -> some View) -> some View {
        HStack(spacing: 12) {
            Text(key, bundle: .l10n).font(DSFont.row)
            Spacer(minLength: 8)
            control()
        }
        .frame(minHeight: 40)
    }

    // MARK: Account

    private var accountSection: some View {
        Section {
            header("nav.profile.account")
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: "Strava").font(DSFont.row)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(me.hasStravaAccount ? Color.pos : Color.mutedFg)
                            .frame(width: 7, height: 7)
                        Text(me.hasStravaAccount ? "nav.profile.stravaConnected" : "nav.profile.stravaNotConnected", bundle: .l10n)
                            .font(DSFont.caption)
                            .foregroundStyle(Color.mutedFg)
                    }
                }
                Spacer()
                // connecting/disconnecting and passwords stay on the web (spec §2)
                Link(destination: WebLinks.home) {
                    Text("nav.profile.manageOnWeb", bundle: .l10n)
                }
                .buttonStyle(.chip)
            }

            Button(role: .destructive) {
                Task { await session.logout() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("nav.logOut", bundle: .l10n)
                }
                .font(DSFont.row)
                .foregroundStyle(Color.neg)
            }
        }
        .listRowBackground(Color.pageBg)
    }

    private var links: some View {
        Section {
            HStack(spacing: 16) {
                Link(destination: WebLinks.privacy) { Text("nav.profile.privacy", bundle: .l10n) }
                Link(destination: WebLinks.support) { Text("nav.profile.support", bundle: .l10n) }
            }
            .font(Font.geist(12.5, relativeTo: .footnote))
            .foregroundStyle(Color.mutedFg)
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .listRowSeparator(.hidden)

            #if DEBUG
            NavigationLink { DesignCatalog() } label: {
                Text(verbatim: "Design system · \(APIClient.storedBaseURL.host() ?? "—")")
                    .font(DSFont.caption)
                    .foregroundStyle(Color.mutedFg)
            }
            .listRowSeparator(.hidden)
            #endif
        }
        .listRowBackground(Color.pageBg)
    }

    /// A section title as a plain row: a `Section` header would stay pinned
    /// over the rows while scrolling, which the web doesn't do.
    private func header(_ key: LocalizedStringKey) -> some View {
        Text(key, bundle: .l10n)
            .font(DSFont.sectionTitle)
            .foregroundStyle(Color.fg)
            .padding(.top, 18)
            .listRowSeparator(.hidden)
    }
}

/// Pages that stay on the web (spec §2), on the canonical host.
enum WebLinks {
    static let home = URL(string: "https://www.sotreina.com")!
    static let privacy = URL(string: "https://www.sotreina.com/privacidade")!
    static let support = URL(string: "https://www.sotreina.com/suporte")!
}

private extension Area {
    /// The tab that shows this area (its label and symbol).
    var tab: AppTab {
        switch self {
        case .run: .run
        case .gym: .gym
        case .diet: .diet
        }
    }
}
