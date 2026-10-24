import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// One tab's root: the area's title with the account menu's avatar, and its
/// sub-pages as text tabs (the web's MobileHeader), then the selected page.
/// Pushed screens get the system navigation bar; the root shows only this
/// header. Perfil is pushed here from the account menu (it isn't a tab).
struct AreaScreen<Content: View>: View {
    let tab: AppTab
    let me: Me
    let profile: ProfileStore
    @ViewBuilder let content: (AppPage?) -> Content
    @State private var page: AppPage?
    /// the panel is on screen (it stays through the morph back)
    @State private var menuMounted: Bool
    /// the panel should be open; false starts the morph back
    @State private var menuOpen: Bool
    @State private var showsProfile: Bool
    /// value-based pushes (a run's detail); the item-based ones are cleared by
    /// their pages on pop-to-root
    @State private var path = NavigationPath()
    @Environment(AppLanguageStore.self) private var language
    @Environment(TabBarState.self) private var tabBar: TabBarState?

    /// Sub-pages already in the app. Landing on a placeholder every launch
    /// would be pointless, so a tab opens on its web landing page only once
    /// that page is ported; until then, on the first one that is.
    static var portedPages: Set<AppPage> { [.gymOverview, .gymRoutines, .gymHistory, .runOverview, .runActivities, .dietOverview, .dietHistory] }

    init(tab: AppTab, me: Me, profile: ProfileStore, @ViewBuilder content: @escaping (AppPage?) -> Content) {
        self.tab = tab
        self.me = me
        self.profile = profile
        self.content = content
        // a validation launch may open Perfil or the menu itself (on Hoje)
        let launch = ValidationLaunch.current
        let here = launch.tab == tab
        _showsProfile = State(initialValue: here && launch.destination == .profile)
        _menuMounted = State(initialValue: here && launch.destination == .accountMenu)
        _menuOpen = State(initialValue: here && launch.destination == .accountMenu)
        // a validation launch may name any page, ported or not
        if case .page(let launchPage) = ValidationLaunch.current.destination, launchPage.tab == tab {
            _page = State(initialValue: launchPage)
            return
        }
        let landing = tab.landingPage.flatMap { Self.portedPages.contains($0) ? $0 : nil }
        _page = State(initialValue: landing ?? tab.pages.first { Self.portedPages.contains($0) } ?? tab.landingPage)
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                AreaHeader(title: tab.label(language.lang), pages: tab.pages, selection: $page) {
                    AccountMenuTrigger(me: me, hidden: menuMounted) {
                        menuMounted = true
                        menuOpen = true
                    }
                }
                content(page)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.pageBg)
            // a push covers the root (or another tab does): the pill decides
            // between pop and scroll to top on a tap on this tab
            .onAppear { tabBar?.setAtRoot(tab, true) }
            .onDisappear { tabBar?.setAtRoot(tab, false) }
            .overlayPreferenceValue(AccountTriggerKey.self) { anchor in
                if menuMounted, let anchor {
                    GeometryReader { proxy in
                        let trigger = proxy[anchor]
                        ZStack(alignment: .topLeading) {
                            // a tap anywhere outside closes, with the morph
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { menuOpen = false }
                            AccountMenuPanel(
                                me: me,
                                isPresented: $menuOpen,
                                openSettings: { showsProfile = true },
                                onClosed: { menuMounted = false }
                            )
                            // top-trailing on the trigger's, like the web's
                            // absolute top-0 right-0
                            .offset(x: trigger.maxX - 288, y: trigger.minY)
                        }
                    }
                }
            }
            // another tab or a pushed screen: never come back to an open menu
            .onDisappear {
                menuOpen = false
                menuMounted = false
            }
            .navigationDestination(isPresented: $showsProfile) {
                // full screen like the web's mobile Perfil: no tab bar
                ProfileView(me: me, store: profile)
                    .hidesFloatingTabBar()
            }
            // never shown (the header above is the title), but it's what a
            // pushed screen's back button says, in the app's language;
            // without it the system writes "Back" in the iPhone's
            .navigationTitle(tab.label(language.lang))
            .toolbar(.hidden, for: .navigationBar)
        }
        // around the stack, so every pushed screen hides the system bar too:
        // the floating pill (`FloatingTabBar`) replaces it
        .toolbar(.hidden, for: .tabBar)
        .onChange(of: tabBar?.popTokens[tab]) {
            path = NavigationPath()
            showsProfile = false
        }
    }
}

/// Title 28 semibold, then text tabs with a 2px mustard underline on the
/// active one, over a hairline (MobileChrome.tsx). Switching is instant.
struct AreaHeader<Trailing: View>: View {
    let title: String
    let pages: [AppPage]
    @Binding var selection: AppPage?
    /// the account menu's avatar, top right
    @ViewBuilder let trailing: () -> Trailing
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text(title)
                    .font(DSFont.pageTitle)
                    .tracking(-0.56)
                    .foregroundStyle(Color.fg)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                trailing()
            }
            .padding(.top, 8)

            if !pages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 22) {
                        ForEach(pages, id: \.self) { page in
                            let active = page == selection
                            Button {
                                selection = page
                            } label: {
                                Text(page.label(language.lang))
                                    .font(DSFont.row)
                                    .foregroundStyle(active ? Color.fg : Color.mutedFg)
                                    .frame(minHeight: 44)
                                    .overlay(alignment: .bottom) {
                                        Rectangle()
                                            .fill(active ? Color.acc : .clear)
                                            .frame(height: 2)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(active ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal, pageGutter)
                }
                .padding(.horizontal, -pageGutter)
                .padding(.top, 8)
                .overlay(alignment: .bottom) { Hairline() }
            }
        }
        .padding(.horizontal, pageGutter)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// An area page not ported yet (spec §3, Fase S): says so and points to the web.
struct ComingSoonView: View {
    var body: some View {
        ContentUnavailableView {
            Label { Text("app.comingSoon.title", bundle: .l10n) } icon: { Image(systemName: "hammer") }
        } description: {
            Text("app.comingSoon.body", bundle: .l10n)
        } actions: {
            Link(destination: URL(string: "https://www.sotreina.com")!) {
                Text("app.comingSoon.openWeb", bundle: .l10n)
            }
            .buttonStyle(.pill)
        }
    }
}
