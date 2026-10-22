import SwiftUI
import SoTreinaKit

/// Logged-in shell: an open workout takes over the screen, otherwise the
/// routines list. Reloads on every return to the foreground, which is how a
/// workout started or finished on the web shows up here.
struct WorkoutRootView: View {
    let me: Me
    @Binding var pendingLink: ActivityLink?
    @State private var store: WorkoutStore
    @Environment(\.scenePhase) private var scenePhase

    init(session: SessionStore, me: Me, pendingLink: Binding<ActivityLink?>) {
        self.me = me
        _pendingLink = pendingLink
        _store = State(initialValue: WorkoutStore(session: session))
    }

    var body: some View {
        Group {
            if let finished = store.lastFinished {
                WorkoutSummaryView(finished: finished) { store.dismissSummary() }
                    .transition(.opacity)
            } else if let workout = store.active {
                WorkoutSessionView(store: store, workout: workout)
                    .transition(.move(edge: .bottom))
            } else {
                RoutinesView(store: store, me: me)
            }
        }
        .animation(.default, value: store.active?.id)
        .animation(.default, value: store.lastFinished?.detail.id)
        .task { await store.load() }
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
        .alert(
            "Não deu certo",
            isPresented: Binding(get: { store.actionError != nil }, set: { if !$0 { store.actionError = nil } }),
            presenting: store.actionError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }
}
