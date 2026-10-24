import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// Logged-in shell (spec §3, Fase S): the floating pill with Hoje and the
/// enabled areas (`AppTab.tabs`, the web's `mobileTabsFor`), gone when only
/// Hoje is left; Perfil opens from the account menu on each tab's header. An
/// open workout covers it full screen until minimized into the capsule above
/// the pill. The system tab bar stays hidden (`AreaScreen`): the `TabView` is
/// kept for what it holds, one live navigation stack per tab.
/// Reloads on every return to the foreground, which is how a workout started
/// or finished on the web shows up here.
struct AppShell: View {
    let me: Me
    @Binding var pendingLink: ActivityLink?
    /// during the entry transition: an open workout's cover waits for it to
    /// end instead of sliding up over the ball
    let holdsCovers: Bool
    /// the first `WorkoutStore.load()` finished (the entry transition waits on it)
    let onFirstLoad: () -> Void
    @State private var store: WorkoutStore
    @State private var runStore: RunStore
    @State private var history: GymHistoryStore
    @State private var diet: DietStore
    @State private var dietHistory: DietHistoryStore
    @State private var profile: ProfileStore
    @State private var tabBar = TabBarState()
    @SceneStorage("selectedTab") private var selectedTab: String = AppTab.today.rawValue
    private let session: SessionStore
    @Environment(AppLanguageStore.self) private var language
    @Environment(\.scenePhase) private var scenePhase
    @State private var appliedLaunchTab = false

    init(
        session: SessionStore, me: Me, pendingLink: Binding<ActivityLink?>,
        holdsCovers: Bool = false, onFirstLoad: @escaping () -> Void = {}
    ) {
        self.session = session
        self.me = me
        _pendingLink = pendingLink
        self.holdsCovers = holdsCovers
        self.onFirstLoad = onFirstLoad
        _store = State(initialValue: WorkoutStore(session: session))
        _runStore = State(initialValue: RunStore(session: session))
        _history = State(initialValue: GymHistoryStore(session: session))
        _diet = State(initialValue: DietStore(session: session))
        _dietHistory = State(initialValue: DietHistoryStore(session: session))
        _profile = State(initialValue: ProfileStore(session: session))
    }

    private var tabs: [AppTab] { AppTab.tabs(for: me.enabledAreas) }

    /// the stored tab may belong to an area the user has since turned off
    private var selection: Binding<AppTab> {
        Binding(
            get: { AppTab(rawValue: selectedTab).flatMap { tabs.contains($0) ? $0 : nil } ?? tabs[0] },
            set: { selectedTab = $0.rawValue }
        )
    }

    var body: some View {
        TabView(selection: selection) {
            ForEach(tabs, id: \.self) { tab in
                content(for: tab)
                    .environment(\.appTab, tab)
                    .tag(tab)
            }
        }
        .tint(Color.acc)
        .overlay {
            FloatingTabBar(
                tabs: tabs,
                selection: selection,
                showsTabs: AppTab.showsTabBar(for: me.enabledAreas),
                workout: store.sessionMinimized ? store.active : nil
            ) { store.sessionMinimized = false }
        }
        .environment(tabBar)
        .onChange(of: selectedTab) { tabBar.expand() }
        .fullScreenCover(isPresented: sessionCovers) {
            Group {
                if let finished = store.lastFinished {
                    WorkoutSummaryView(finished: finished, weightUnit: store.weightUnit) { store.dismissSummary() }
                } else if let workout = store.active {
                    WorkoutSessionView(store: store, workout: workout)
                }
            }
            .monolitoTheme()
        }
        .task {
            await store.load()
            onFirstLoad()
        }
        .onAppear {
            // a validation launch opens on its screen's tab, once (debug only)
            guard !appliedLaunchTab, let tab = ValidationLaunch.current.tab else { return }
            appliedLaunchTab = true
            selectedTab = tab.rawValue
        }
        .task(id: pendingLink) {
            guard let link = pendingLink else { return }
            // clearing the id cancels this task, so the action (a network
            // call for "✓") runs in its own
            pendingLink = nil
            Task { await store.handle(link) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                tabBar.expand()
                Task { await store.load() }
                Task { await runStore.load() }
                // Registros added on the web, or a day that turned at midnight
                Task { await diet.load() }
            }
        }
        // exercise names come localized from the API (`Accept-Language`):
        // a language switch mid-workout refetches them, or they'd stay in the
        // old language until the next mutation
        .onChange(of: language.lang) { Task { await store.load() } }
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

    /// The summary, or an open session that isn't minimized.
    private var sessionCovers: Binding<Bool> {
        Binding(
            get: { !holdsCovers && (store.lastFinished != nil || (store.active != nil && !store.sessionMinimized)) },
            set: { presented in
                guard !presented else { return }
                if store.lastFinished != nil { store.dismissSummary() } else { store.sessionMinimized = true }
            }
        )
    }

    @ViewBuilder
    private func content(for tab: AppTab) -> some View {
        switch tab {
        case .gym:
            AreaScreen(tab: tab, me: me, profile: profile) { page in
                switch page {
                case .gymOverview: GymOverviewView(store: store, history: history)
                case .gymRoutines: RoutinesView(store: store)
                case .gymHistory: GymHistoryView(store: history)
                default: ComingSoonView()
                }
            }
        case .run:
            AreaScreen(tab: tab, me: me, profile: profile) { page in
                // spec login-app-ios §5: connect, then the first import, on
                // both sub-pages
                if !me.hasStravaAccount || ValidationLaunch.current.destination == .runConnect {
                    RunConnectView()
                } else if runStore.firstSync != nil {
                    RunFirstSyncView(store: runStore)
                } else {
                    switch page {
                    case .runOverview: RunOverviewView(store: runStore)
                    case .runActivities: RunActivitiesView(store: runStore)
                    default: ComingSoonView()
                    }
                }
            }
        case .diet:
            AreaScreen(tab: tab, me: me, profile: profile) { page in
                switch page {
                case .dietOverview: DietOverviewView(store: diet, profile: profile)
                case .dietHistory: DietHistoryView(store: dietHistory, profile: profile)
                default: ComingSoonView()
                }
            }
        case .today:
            AreaScreen(tab: tab, me: me, profile: profile) { _ in
                TodayView(
                    me: me, workout: store, run: runStore, gymHistory: history,
                    diet: diet, dietHistory: dietHistory, profile: profile
                ) { page in
                    // with one area there's no tab to switch to
                    guard tabs.contains(page.tab) else { return }
                    tabBar.open(page)
                    selectedTab = page.tab.rawValue
                }
            }
        }
    }
}

// also the area picker's icons
extension AppTab {
    var symbol: String {
        switch self {
        case .today: "house"
        case .run: "figure.run"
        case .gym: "dumbbell"
        case .diet: "fork.knife"
        }
    }
}
