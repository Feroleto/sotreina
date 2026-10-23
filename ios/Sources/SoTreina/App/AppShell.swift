import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// Logged-in shell (spec §3, Fase S): a tab bar with Hoje, the enabled areas
/// and Perfil (`AppTab.tabs`, the web's `mobileTabsFor`). An open workout
/// covers it full screen until minimized into the bar above the tab bar.
/// Reloads on every return to the foreground, which is how a workout started
/// or finished on the web shows up here.
struct AppShell: View {
    let me: Me
    @Binding var pendingLink: ActivityLink?
    @State private var store: WorkoutStore
    @State private var history: GymHistoryStore
    @SceneStorage("selectedTab") private var selectedTab: String = AppTab.gym.rawValue
    private let session: SessionStore
    @Environment(AppLanguageStore.self) private var language
    @Environment(\.scenePhase) private var scenePhase
    @State private var appliedLaunchTab = false

    init(session: SessionStore, me: Me, pendingLink: Binding<ActivityLink?>) {
        self.session = session
        self.me = me
        _pendingLink = pendingLink
        _store = State(initialValue: WorkoutStore(session: session))
        _history = State(initialValue: GymHistoryStore(session: session))
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
                    // the minimized session rides above the tab bar on every tab
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if let workout = store.active, store.sessionMinimized {
                            ActiveWorkoutBar(workout: workout) { store.sessionMinimized = false }
                        }
                    }
                    .tabItem { Label(tab.label(language.lang), systemImage: tab.symbol) }
                    .tag(tab)
            }
        }
        .tint(Color.acc)
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
        .task { await store.load() }
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
            if phase == .active { Task { await store.load() } }
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
            get: { store.lastFinished != nil || (store.active != nil && !store.sessionMinimized) },
            set: { presented in
                guard !presented else { return }
                if store.lastFinished != nil { store.dismissSummary() } else { store.sessionMinimized = true }
            }
        )
    }

    @ViewBuilder
    private func content(for tab: AppTab) -> some View {
        switch tab {
        case .profile:
            ProfileView(session: session, me: me)
        case .gym:
            AreaScreen(tab: tab) { page in
                switch page {
                case .gymRoutines: RoutinesView(store: store)
                case .gymHistory: GymHistoryView(store: history)
                default: ComingSoonView()
                }
            }
        case .today, .run, .diet:
            AreaScreen(tab: tab) { _ in ComingSoonView() }
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
        case .profile: "person.crop.circle"
        }
    }
}
