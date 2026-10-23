import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// One tab's root: the area's title and its sub-pages as text tabs (the
/// web's MobileHeader), then the selected page. Pushed screens get the
/// system navigation bar; the root shows only this header.
struct AreaScreen<Content: View>: View {
    let tab: AppTab
    @ViewBuilder let content: (AppPage?) -> Content
    @State private var page: AppPage?
    @Environment(AppLanguageStore.self) private var language

    /// Sub-pages already in the app. Landing on a placeholder every launch
    /// would be pointless, so a tab opens on its web landing page only once
    /// that page is ported; until then, on the first one that is.
    static var portedPages: Set<AppPage> { [.gymRoutines, .gymHistory, .runOverview, .runActivities] }

    init(tab: AppTab, @ViewBuilder content: @escaping (AppPage?) -> Content) {
        self.tab = tab
        self.content = content
        // a validation launch may name any page, ported or not
        if case .page(let launchPage) = ValidationLaunch.current.destination, launchPage.tab == tab {
            _page = State(initialValue: launchPage)
            return
        }
        let landing = tab.landingPage.flatMap { Self.portedPages.contains($0) ? $0 : nil }
        _page = State(initialValue: landing ?? tab.pages.first { Self.portedPages.contains($0) } ?? tab.landingPage)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AreaHeader(title: tab.label(language.lang), pages: tab.pages, selection: $page)
                content(page)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.pageBg)
            // never shown (the header above is the title), but it's what a
            // pushed screen's back button says, in the app's language;
            // without it the system writes "Back" in the iPhone's
            .navigationTitle(tab.label(language.lang))
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

/// Title 28 semibold, then text tabs with a 2px mustard underline on the
/// active one, over a hairline (MobileChrome.tsx). Switching is instant.
struct AreaHeader: View {
    let title: String
    let pages: [AppPage]
    @Binding var selection: AppPage?
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(DSFont.pageTitle)
                .tracking(-0.56)
                .foregroundStyle(Color.fg)
                .lineLimit(1)
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)

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
