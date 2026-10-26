import SoTreinaKit
import SwiftUI

/// A tab's state in the shell's stack of live tabs (spec
/// ios-transicoes-de-pagina §4.2). Hidden tabs stay mounted, so this is
/// the signal that replaces the `onAppear`/`onDisappear` the `TabView` used
/// to send on every switch.
struct TabActivation: Equatable {
    /// on top and taking touches
    var isActive: Bool
    /// changes every time the tab becomes active (0: the launch tab)
    var generation: Int
    /// how far the body sits below its place while the tab fades in
    var rise: CGFloat

    /// outside the shell (previews, the entry screens): always on
    static let standalone = TabActivation(isActive: true, generation: 0, rise: 0)
}

private struct TabActivationKey: EnvironmentKey {
    static let defaultValue = TabActivation.standalone
}

extension EnvironmentValues {
    /// Set by `AppShell` on each tab's content.
    var tabActivation: TabActivation {
        get { self[TabActivationKey.self] }
        set { self[TabActivationKey.self] = newValue }
    }
}

extension View {
    /// `.task` for a screen in a tab: runs when it shows and again every
    /// time its tab becomes active, as the `TabView` did. A tab left
    /// mid-load lets that load finish.
    func taskOnTabActivation(_ action: @escaping @MainActor () async -> Void) -> some View {
        modifier(TaskOnTabActivation(action: action))
    }
}

private struct TaskOnTabActivation: ViewModifier {
    let action: @MainActor () async -> Void
    @Environment(\.tabActivation) private var activation

    func body(content: Content) -> some View {
        content.task(id: activation.generation) {
            guard activation.isActive else { return }
            await action()
        }
    }
}
