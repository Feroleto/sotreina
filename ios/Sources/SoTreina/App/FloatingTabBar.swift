import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// What the floating tab bar and the screens under it share (spec
/// ios-floating-tab-bar): collapsed or not, hidden by a screen, the
/// pop-to-root and scroll-to-top signals of a tap on the selected tab, and
/// the room the bar takes at the bottom.
@MainActor @Observable
final class TabBarState {
    /// read on every scroll frame, so only `isCollapsed` is observed
    @ObservationIgnored private var collapse: TabBarCollapse
    private(set) var isCollapsed: Bool
    /// a page's main scroll view is moving: the pill shrinks a little
    private(set) var isScrolling = false
    /// screens on screen that hide the bar; a counter, since pushes nest.
    /// Counted on `onAppear`/`onDisappear`, which a tab switch no longer
    /// sends (hidden tabs stay mounted): fine while every such screen hides
    /// the pill, so no switch can happen under one
    private(set) var hiders = 0
    private(set) var popTokens: [AppTab: Int] = [:]
    private(set) var scrollTopTokens: [AppTab: Int] = [:]
    /// a page another tab asked to open (Hoje's taps), until its tab applies it
    private(set) var pageRequests: [AppTab: AppPage] = [:]
    @ObservationIgnored private var atRoot: [AppTab: Bool] = [:]
    /// height of the expanded bar above the bottom safe area, so the last
    /// row of a list can scroll above it
    var reservedHeight: CGFloat = 0
    /// a validation launch keeps the circle on screen
    @ObservationIgnored private let pinned: Bool

    init() {
        pinned = ValidationLaunch.current.destination == .tabBarCollapsed
        collapse = TabBarCollapse(isCollapsed: pinned)
        isCollapsed = pinned
    }

    var isHidden: Bool { hiders > 0 }

    func scrolled(to offset: Double, maxOffset: Double) {
        guard !pinned else { return }
        collapse.scrolled(to: offset, maxOffset: maxOffset)
        if collapse.isCollapsed != isCollapsed { isCollapsed = collapse.isCollapsed }
    }

    func expand() {
        guard !pinned else { return }
        collapse.reset()
        if isCollapsed { isCollapsed = false }
    }

    func scrolling(_ value: Bool) {
        if isScrolling != value { isScrolling = value }
    }

    func hide() { hiders += 1 }
    func unhide() { hiders = max(0, hiders - 1) }

    /// The tab's root page appeared or got covered by a push (or another
    /// tab). Either way the bar starts expanded on what's now on screen.
    func setAtRoot(_ tab: AppTab, _ value: Bool) {
        guard atRoot[tab] != value else { return }
        atRoot[tab] = value
        expand()
    }

    /// Hoje's taps: the area's tab lands on `page`, back at its root (the
    /// web navigates to the page, which drops whatever was drilled into).
    func open(_ page: AppPage) {
        popTokens[page.tab, default: 0] += 1
        pageRequests[page.tab] = page
        expand()
    }

    func consumePageRequest(_ tab: AppTab) {
        pageRequests[tab] = nil
    }

    func reselect(_ tab: AppTab) {
        switch TabReselect(atRoot: atRoot[tab] ?? true) {
        case .popToRoot: popTokens[tab, default: 0] += 1
        case .scrollToTop: scrollTopTokens[tab, default: 0] += 1
        }
        expand()
    }
}

private struct AppTabKey: EnvironmentKey {
    static let defaultValue: AppTab? = nil
}

extension EnvironmentValues {
    /// The tab a view lives in (set by `AppShell` on each tab's content).
    var appTab: AppTab? {
        get { self[AppTabKey.self] }
        set { self[AppTabKey.self] = newValue }
    }
}

extension View {
    /// Hides the floating tab bar while this screen is on screen — the
    /// screens with their own bar at the bottom, and Perfil.
    func hidesFloatingTabBar() -> some View {
        modifier(HidesFloatingTabBar())
    }

    /// Runs `action` when the selected tab is tapped again with a screen
    /// pushed: the page clears the state that pushed it.
    func onPopToRoot(perform action: @escaping () -> Void) -> some View {
        modifier(PopToRoot(action: action))
    }

    /// The page's main scroll view: folds the bar on scroll, goes back to
    /// the top on a tap on the selected tab, and scrolls far enough for its
    /// last row to clear the bar.
    func floatingTabBarScroll() -> some View {
        modifier(FloatingTabBarScroll())
    }

    /// A pushed screen that scrolls: room at the bottom for its last row to
    /// clear the bar. Applied on the screen itself, inside the navigation
    /// stack: a `safeAreaInset` around the stack never reaches the scroll
    /// view's insets (measured on the iPhone, iOS 27).
    func floatingTabBarSpace() -> some View {
        modifier(FloatingTabBarSpace())
    }
}

private struct HidesFloatingTabBar: ViewModifier {
    @Environment(TabBarState.self) private var tabBar: TabBarState?

    func body(content: Content) -> some View {
        content
            .onAppear { tabBar?.hide() }
            .onDisappear { tabBar?.unhide() }
    }
}

private struct PopToRoot: ViewModifier {
    let action: () -> Void
    @Environment(TabBarState.self) private var tabBar: TabBarState?
    @Environment(\.appTab) private var tab

    func body(content: Content) -> some View {
        content.onChange(of: tab.flatMap { tabBar?.popTokens[$0] }) { action() }
    }
}

private struct FloatingTabBarSpace: ViewModifier {
    @Environment(TabBarState.self) private var tabBar: TabBarState?

    func body(content: Content) -> some View {
        // `safeAreaPadding`, not `contentMargins`: margins reach every scroll
        // view inside, the horizontal carousels too
        content.safeAreaPadding(.bottom, tabBar.map { $0.isHidden ? 0 : $0.reservedHeight } ?? 0)
    }
}

private struct FloatingTabBarScroll: ViewModifier {
    @Environment(TabBarState.self) private var tabBar: TabBarState?
    @Environment(\.appTab) private var tab
    @Environment(\.tabActivation) private var activation
    @State private var position = ScrollPosition(edge: .top)

    private struct Sample: Equatable {
        var offset: Double
        var maxOffset: Double
    }

    func body(content: Content) -> some View {
        content
            .scrollPosition($position)
            .onScrollGeometryChange(for: Sample.self) { geometry in
                // 0 at the top of the content, whatever the insets
                let insets = geometry.contentInsets
                return Sample(
                    offset: geometry.contentOffset.y + insets.top,
                    maxOffset: geometry.contentSize.height + insets.top + insets.bottom - geometry.containerSize.height
                )
            } action: { _, sample in
                // a hidden tab still coasting doesn't fold the pill
                guard activation.isActive else { return }
                tabBar?.scrolled(to: sample.offset, maxOffset: sample.maxOffset)
            }
            .onScrollPhaseChange { _, phase in
                guard activation.isActive else { return }
                tabBar?.scrolling(phase.isScrolling)
            }
            // a push or a tab switch mid-scroll never reports the idle phase
            .onDisappear { tabBar?.scrolling(false) }
            .onChange(of: activation.isActive) { _, active in
                if !active { tabBar?.scrolling(false) }
            }
            .onChange(of: tab.flatMap { tabBar?.scrollTopTokens[$0] }) {
                withAnimation { position.scrollTo(edge: .top) }
            }
            .floatingTabBarSpace()
    }
}

/// The web's mobile pill (`MobileTabBar`): icons only, the selected tab in
/// a chip with its name. Liquid Glass on iOS 26+, the web's solid page
/// background with a hairline before that. While a page scrolls the pill
/// shrinks a little. With an open workout minimized, scrolling down folds it
/// into a circle at the bottom left, the workout beside it (spec
/// ios-floating-tab-bar §2–5).
struct FloatingTabBar: View {
    let tabs: [AppTab]
    @Binding var selection: AppTab
    /// false with a single area: no pill, the workout alone
    let showsTabs: Bool
    /// the minimized open workout
    let workout: WorkoutDetail?
    let onResumeWorkout: () -> Void
    @Environment(TabBarState.self) private var state
    @Environment(AppLanguageStore.self) private var language
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Namespace private var namespace

    /// only with a workout to make room for; never under VoiceOver, so no
    /// target goes away
    private var collapsed: Bool { showsTabs && workout != nil && state.isCollapsed && !voiceOver }

    /// the pill while the page scrolls, without a fold
    private var shrunk: Bool { !collapsed && state.isScrolling && !reduceMotion }

    /// Reduce Motion: states cross-fade instead of sliding or morphing
    private var animation: Animation {
        reduceMotion ? .easeInOut(duration: 0.15) : .snappy(duration: 0.32)
    }

    var body: some View {
        GeometryReader { proxy in
            // `max(20px, safe-area + 8px)` from the screen's bottom edge
            let bottom = max(8, 20 - proxy.safeAreaInsets.bottom)
            surfaces
                // a transform, so the reserved height never changes
                // mid-scroll. On the whole glass container: scaled inside it,
                // the glass shrinks but the icons on it don't
                .scaleEffect(shrunk ? 0.9 : 1, anchor: .bottom)
                .animation(.snappy(duration: 0.25), value: shrunk)
                .padding(.horizontal, 16)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    // the expanded height only: a list must not jump when it
                    // folds. 16pt clear between the last row and the bar
                    guard !collapsed else { return }
                    state.reservedHeight = height > 0 ? height + bottom + 16 : 0
                }
                .padding(.bottom, bottom)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        // the keyboard covers it instead of pushing it up
        .ignoresSafeArea(.keyboard)
        .opacity(state.isHidden ? 0 : 1)
        .offset(y: state.isHidden && !reduceMotion ? 12 : 0)
        .allowsHitTesting(!state.isHidden)
        .animation(.easeOut(duration: 0.2), value: state.isHidden)
        .animation(animation, value: collapsed)
    }

    @ViewBuilder private var surfaces: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 12) { layout }
        } else {
            layout
        }
    }

    @ViewBuilder private var layout: some View {
        if collapsed {
            HStack(spacing: 8) {
                circle
                if let workout {
                    workoutCapsule(workout)
                } else {
                    Spacer(minLength: 0)
                }
            }
        } else {
            VStack(spacing: 8) {
                if let workout { workoutCapsule(workout) }
                if showsTabs { pill }
            }
        }
    }

    private var pill: some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(5)
        .floatingSurface()
        .matched("bar", in: namespace, enabled: !reduceMotion)
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("tabs.label", bundle: .l10n))
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let active = tab == selection
        let label = tab.label(language.lang)
        return Button {
            if active {
                state.reselect(tab)
            } else {
                withAnimation(animation) { selection = tab }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 19, weight: active ? .semibold : .regular))
                    .foregroundStyle(active ? Color.accTx : Color.mutedFg)
                    .frame(width: 24, height: 24)
                if active {
                    Text(label)
                        .font(DSFont.pill)
                        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                        .foregroundStyle(Color.fg)
                        .lineLimit(1)
                        .fixedSize()
                        .transition(.opacity)
                }
            }
            .padding(.leading, active ? 12 : 0)
            .padding(.trailing, active ? 16 : 0)
            .frame(minWidth: 50, minHeight: 46)
            .background {
                if active {
                    Capsule()
                        .fill(Color.chip)
                        .matched("chip", in: namespace, enabled: !reduceMotion)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private var circle: some View {
        Button {
            state.expand()
        } label: {
            Image(systemName: selection.symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Color.accTx)
                .frame(width: 50, height: 50)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .floatingSurface()
        .matched("bar", in: namespace, enabled: !reduceMotion)
        .accessibilityLabel(Text("tabs.expand", bundle: .l10n))
        .accessibilityValue(selection.label(language.lang))
    }

    private func workoutCapsule(_ workout: WorkoutDetail) -> some View {
        ActiveWorkoutBar(workout: workout, onResume: onResumeWorkout)
            .floatingSurface()
            .matched("workout", in: namespace, enabled: !reduceMotion)
    }
}

extension View {
    /// The bar's material: Liquid Glass on iOS 26+, else the web's solid
    /// `--page-bg` with a hairline border.
    @ViewBuilder fileprivate func floatingSurface() -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular.interactive(), in: .capsule)
        } else {
            background(Color.pageBg, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.border, lineWidth: 1))
        }
    }

    @ViewBuilder fileprivate func matched(_ id: String, in namespace: Namespace.ID, enabled: Bool) -> some View {
        if enabled {
            matchedGeometryEffect(id: id, in: namespace)
        } else {
            self
        }
    }
}
