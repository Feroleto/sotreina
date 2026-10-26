import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// Logged-in shell (spec §3, Fase S): the floating pill with Hoje and the
/// enabled areas (`AppTab.tabs`, the web's `mobileTabsFor`), gone when only
/// Hoje is left; Perfil opens from the account menu on each tab's header. An
/// open workout covers it full screen until minimized into the capsule above
/// the pill. The tabs are a stack of their own, not a `TabView` (whose switch
/// can't animate): each mounts on its first visit and stays alive, keeping
/// its navigation stack and scroll, and a switch fades the new one in over
/// the old (spec ios-transicoes-de-pagina §3.1).
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
    @State private var plan: PlanStore
    @State private var tabBar = TabBarState()
    @SceneStorage("selectedTab") private var selectedTab: String = AppTab.today.rawValue
    private let session: SessionStore
    @Environment(AppLanguageStore.self) private var language
    @Environment(\.scenePhase) private var scenePhase
    @State private var appliedLaunchTab = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// which tabs are on screen; nil until the first `onAppear`
    @State private var shown: TabTransitionQueue<AppTab>?
    /// tabs visited at least once: kept alive, hidden when not shown
    @State private var mounted: Set<AppTab> = []
    /// the active tab finished (or started) its fade-in
    @State private var revealed = true
    /// the active tab's body, below its place until the fade starts
    @State private var rise: CGFloat = 0

    init(
        session: SessionStore, me: Me, pendingLink: Binding<ActivityLink?>,
        holdsCovers: Bool = false, onFirstLoad: @escaping () -> Void = {}
    ) {
        self.session = session
        self.me = me
        _pendingLink = pendingLink
        self.holdsCovers = holdsCovers
        self.onFirstLoad = onFirstLoad
        let workout = WorkoutStore(session: session)
        let plan = PlanStore(session: session)
        workout.plan = plan
        _store = State(initialValue: workout)
        _plan = State(initialValue: plan)
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

    private var queue: TabTransitionQueue<AppTab> { shown ?? TabTransitionQueue(active: selection.wrappedValue) }

    var body: some View {
        ZStack {
            ForEach(tabs, id: \.self) { tab in
                if mounted.contains(tab) || tab == queue.active {
                    let active = tab == queue.active
                    content(for: tab)
                        .environment(\.appTab, tab)
                        .environment(
                            \.tabActivation,
                            TabActivation(isActive: active, generation: queue.activatedIn[tab] ?? 0, rise: active ? rise : 0)
                        )
                        .opacity(active ? (revealed ? 1 : 0) : (queue.isVisible(tab) ? 1 : 0))
                        // the active one on top, the one it covers just below
                        .zIndex(active ? 2 : queue.isVisible(tab) ? 1 : 0)
                        .allowsHitTesting(active)
                        .accessibilityHidden(!active)
                }
            }
        }
        .tint(Color.acc)
        // Perfil and the plan editor reach these without new parameters
        .environment(plan)
        .environment(store)
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
        .onChange(of: selection.wrappedValue) { _, tab in switchTab(to: tab) }
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
        .task { await plan.load() }
        .onAppear {
            guard shown == nil else { return }
            var start = selection.wrappedValue
            // a validation launch opens on its screen's tab, once (debug
            // only), without a transition
            if !appliedLaunchTab, let tab = ValidationLaunch.current.tab {
                appliedLaunchTab = true
                selectedTab = tab.rawValue
                if tabs.contains(tab) { start = tab }
            }
            shown = TabTransitionQueue(active: start)
            mounted.insert(start)
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
                Task { await plan.load() }
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

    /// Fade + rise (spec §3.1): the new tab goes on top, transparent, its
    /// body a little low, while the old one stays opaque below, so what the
    /// two share (avatar, background) never blinks; any other tab hides at
    /// once. The fade's end hides the old one, unless a newer tap came.
    private func switchTab(to tab: AppTab) {
        var next = queue
        let from = next.active
        guard next.select(tab) else { return }
        let generation = next.generation
        var instant = Transaction()
        instant.disablesAnimations = true
        guard case .tab(let distance, let duration) = PageTransition.between(.init(tab: from), .init(tab: tab), reduceMotion: reduceMotion) else { return }
        withTransaction(instant) {
            shown = next
            mounted.insert(from)
            mounted.insert(tab)
            revealed = false
            rise = distance
        }
        // on the next run loop: set and animated in the same update, the
        // fade would start from the value already on screen
        DispatchQueue.main.async {
            guard shown?.generation == generation else { return }
            withAnimation(.easeOut(duration: duration), completionCriteria: .logicallyComplete) {
                revealed = true
                rise = 0
            } completion: {
                withTransaction(instant) { shown?.finish(generation) }
            }
            // VoiceOver's focus doesn't move between layers on its own
            AccessibilityNotification.ScreenChanged(tab.label(language.lang)).post()
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
                    diet: diet, dietHistory: dietHistory, profile: profile, plan: plan
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
