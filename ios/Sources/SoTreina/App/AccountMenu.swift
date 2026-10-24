import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// The account menu (web `ProfileMenu` + Kokonut's profile-dropdown, spec
/// `.plans/profile-dropdown-mobile-spec.md`): the avatar at the top right of
/// every tab root opens a panel with theme, language, Configurações (→ Perfil)
/// and a press-and-hold sign out. The panel grows out of the avatar's own
/// circle — an animatable clip from the trigger's box to the panel's, the
/// web's `clip-path` — while the avatar travels into the header.

private let panelWidth: CGFloat = 288
private let panelRadius: CGFloat = 16
private let triggerAvatar: CGFloat = 34
private let headAvatar: CGFloat = 40
/// panel padding (6) + header padding (10): where the header avatar sits
private let headInset: CGFloat = 16
private let segmentWidth: CGFloat = 36
private let morph = Animation.spring(duration: 0.3, bounce: 0)

/// The trigger's frame, reported up to `AreaScreen`, which lays the panel
/// over the whole tab root anchored to it.
struct AccountTriggerKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

/// The Strava photo, or the initials (also while it loads or if it fails).
struct AccountAvatar: View {
    let me: Me
    let size: CGFloat

    var body: some View {
        let initials = Text(ProfileRules.initials(me.firstName))
            .font(Font.geist(size * 0.36, relativeTo: .subheadline).weight(.semibold))
            .foregroundStyle(Color.fg)
            .frame(width: size, height: size)
            .background(Color.chip, in: Circle())
        AsyncImage(url: me.profileImgUrl.flatMap(URL.init(string:))) { image in
            image.resizable().scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.fg.opacity(0.1), lineWidth: 1))
        } placeholder: {
            initials
        }
        .accessibilityHidden(true)
    }
}

/// 44×44 touch target, the 34pt avatar aligned to its right edge (the
/// header's gutter). Hidden while the panel's copy stands in for it.
struct AccountMenuTrigger: View {
    let me: Me
    let hidden: Bool
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            AccountAvatar(me: me, size: triggerAvatar)
                .opacity(hidden ? 0 : 1)
                .frame(width: 44, height: 44, alignment: .trailing)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .anchorPreference(key: AccountTriggerKey.self, value: .bounds) { $0 }
        .accessibilityLabel(Text("nav.profileMenu.menu", bundle: .l10n))
        .accessibilityAddTraits(.isButton)
    }
}

/// The panel's visible box: at 0 the trigger avatar's circle (trailing, 5pt
/// down inside the 44pt trigger), at 1 the whole panel.
private struct MorphClip: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let start = CGRect(
            x: rect.maxX - triggerAvatar, y: (44 - triggerAvatar) / 2,
            width: triggerAvatar, height: triggerAvatar
        )
        let p = progress
        let box = CGRect(
            x: start.minX + (rect.minX - start.minX) * p,
            y: start.minY + (rect.minY - start.minY) * p,
            width: start.width + (rect.width - start.width) * p,
            height: start.height + (rect.height - start.height) * p
        )
        let radius = triggerAvatar / 2 + (panelRadius - triggerAvatar / 2) * p
        return Path(roundedRect: box, cornerRadius: radius, style: .continuous)
    }
}

/// The panel, laid over the tab root by `AreaScreen` while `isPresented`:
/// a tap anywhere outside closes it with the morph.
struct AccountMenuPanel: View {
    let me: Me
    @Binding var isPresented: Bool
    /// pushes Perfil on the tab's stack
    let openSettings: () -> Void
    /// set by `close` once the morph back finishes: hides the panel for real
    let onClosed: () -> Void

    @Environment(SessionStore.self) private var session
    @Environment(AppLanguageStore.self) private var language
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(ThemePreference.storageKey) private var themeRaw = ThemePreference.auto.rawValue
    @State private var progress: CGFloat = 0
    @State private var closing = false

    var body: some View {
        // the body fades in behind the growing clip, out ahead of it
        let bodyOpacity = max(0, (progress - 0.35) / 0.65)
        VStack(alignment: .leading, spacing: 0) {
            header(bodyOpacity: bodyOpacity)
            Group {
                SegmentRow(
                    label: Text("nav.profileMenu.theme", bundle: .l10n),
                    options: [
                        .init(id: ThemePreference.auto.rawValue, a11y: Text("common.theme.auto", bundle: .l10n)) {
                            Image(systemName: "display")
                        },
                        .init(id: ThemePreference.light.rawValue, a11y: Text("common.theme.light", bundle: .l10n)) {
                            Image(systemName: "sun.max")
                        },
                        .init(id: ThemePreference.dark.rawValue, a11y: Text("common.theme.dark", bundle: .l10n)) {
                            Image(systemName: "moon")
                        },
                    ],
                    selection: $themeRaw
                )
                SegmentRow(
                    label: Text("nav.profileMenu.language", bundle: .l10n),
                    options: [
                        .init(id: AppLanguage.pt.rawValue, a11y: Text(verbatim: "Português")) { Text(verbatim: "PT") },
                        .init(id: AppLanguage.en.rawValue, a11y: Text(verbatim: "English")) { Text(verbatim: "EN") },
                    ],
                    // PT/EN like Perfil: the active one is the language in
                    // use, iPhone default included
                    selection: Binding(
                        get: { language.lang == .en ? AppLanguage.en.rawValue : AppLanguage.pt.rawValue },
                        set: { language.choice = AppLanguage(rawValue: $0) ?? .auto }
                    )
                )
                separator
                Button {
                    // the screen is about to change: no morph back
                    closing = true
                    isPresented = false
                    onClosed()
                    openSettings()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Color.mutedFg)
                            .frame(width: 18)
                        Text("nav.profileMenu.settings", bundle: .l10n)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.mutedFg)
                    }
                }
                .buttonStyle(MenuRowStyle())
                separator
                HoldSignOutRow {
                    Task { await session.logout() }
                }
            }
            .opacity(bodyOpacity)
        }
        .padding(6)
        .frame(width: panelWidth, alignment: .leading)
        .background {
            MorphClip(progress: progress)
                .fill(Color.card)
                .overlay { MorphClip(progress: progress).stroke(Color.border, lineWidth: 1) }
                .shadow(color: .black.opacity(0.10), radius: 14, y: 10)
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        }
        .clipShape(MorphClip(progress: progress))
        .allowsHitTesting(!closing)
        .onAppear {
            if reduceMotion {
                progress = 1
            } else {
                withAnimation(morph) { progress = 1 }
            }
        }
        .onChange(of: isPresented) { _, presented in
            guard !presented, !closing else { return }
            close()
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { isPresented = false }
    }

    /// Avatar (travelling from the trigger), name, email or the Strava fallback.
    private func header(bodyOpacity: CGFloat) -> some View {
        // the avatar's offset/scale from its trigger spot, shrinking to 0
        let rest = 1 - progress
        let dx = (panelWidth - triggerAvatar - headInset) * rest
        let dy = ((44 - triggerAvatar) / 2 - headInset) * rest
        let scale = 1 - (1 - triggerAvatar / headAvatar) * rest
        return VStack(alignment: .leading, spacing: 12) {
            AccountAvatar(me: me, size: headAvatar)
                .scaleEffect(scale, anchor: .topLeading)
                .offset(x: dx, y: dy)
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    if let name = me.firstName, !name.isEmpty {
                        Text(verbatim: name)
                    } else {
                        Text("nav.runnerFallback", bundle: .l10n)
                    }
                }
                .font(Font.geist(14, relativeTo: .subheadline).weight(.semibold))
                .foregroundStyle(Color.fg)
                Group {
                    if let email = me.email {
                        Text(verbatim: email)
                    } else {
                        Text("nav.profileMenu.viaStrava", bundle: .l10n)
                    }
                }
                .font(Font.geist(12, relativeTo: .caption))
                .foregroundStyle(Color.mutedFg)
            }
            .lineLimit(1)
            .opacity(bodyOpacity)
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.border)
            .frame(height: 1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
    }

    private func close() {
        closing = true
        if reduceMotion {
            progress = 0
            onClosed()
            return
        }
        withAnimation(morph) {
            progress = 0
        } completion: {
            onClosed()
        }
    }
}

/// A menu row: the chip highlight while pressed (the web's focus highlight).
private struct MenuRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Font.geist(14, relativeTo: .subheadline))
            .foregroundStyle(Color.fg.opacity(configuration.isPressed ? 1 : 0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                configuration.isPressed ? Color.chip : .clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .contentShape(Rectangle())
    }
}

/// Label + equal-width segmented radios on a chip track, the checked one on
/// a card indicator that slides by its index.
private struct SegmentRow: View {
    struct Option: Identifiable {
        let id: String
        let a11y: Text
        let content: AnyView

        init(id: String, a11y: Text, @ViewBuilder content: () -> some View) {
            self.id = id
            self.a11y = a11y
            self.content = AnyView(content())
        }
    }

    let label: Text
    let options: [Option]
    @Binding var selection: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let index = CGFloat(options.firstIndex { $0.id == selection } ?? 0)
        HStack {
            label
                .font(Font.geist(14, relativeTo: .subheadline))
                .foregroundStyle(Color.mutedFg)
            Spacer(minLength: 8)
            HStack(spacing: 0) {
                ForEach(options) { option in
                    let checked = option.id == selection
                    Button {
                        selection = option.id
                    } label: {
                        option.content
                            .font(Font.geist(12, relativeTo: .caption).weight(.medium))
                            .imageScale(.small)
                            .foregroundStyle(checked ? Color.fg : Color.mutedFg)
                            .frame(width: segmentWidth, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.a11y)
                    .accessibilityAddTraits(checked ? .isSelected : [])
                }
            }
            .background(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.card)
                    .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
                    .frame(width: segmentWidth, height: 28)
                    .offset(x: index * segmentWidth)
                    .animation(reduceMotion ? nil : .spring(duration: 0.25, bounce: 0), value: index)
            }
            .padding(2)
            .background(Color.chip, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

/// Sign out, confirmed by holding 1.2 s: an inverted copy of the row fills
/// left to right while pressed and snaps back if let go early. Logging out
/// bumps `tokenVersion` and ends every session (web included), hence the hold.
private struct HoldSignOutRow: View {
    let onComplete: () -> Void
    private let duration = 1.2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fill: CGFloat = 0
    @State private var done = false
    @State private var nudge = false
    @State private var nudgeTask: Task<Void, Never>?

    var body: some View {
        label
            .foregroundStyle(Color.fg.opacity(0.8))
            .overlay {
                // the fill: the same row inverted, revealed by its mask. The
                // linear fill is the gesture's feedback and stays under reduce
                // motion; only the snap-back is dropped
                label
                    .foregroundStyle(Color.pageBg)
                    .background(Color.fg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .mask(alignment: .leading) {
                        GeometryReader { geo in
                            Rectangle().frame(width: geo.size.width * fill)
                        }
                    }
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: duration, maximumDistance: 40) {
                done = true
                fill = 1
                onComplete()
            } onPressingChanged: { pressing in
                if pressing {
                    nudgeTask?.cancel()
                    nudge = false
                    withAnimation(.linear(duration: duration)) { fill = 1 }
                } else {
                    // a completed hold also reports "not pressing" — give the
                    // `perform` closure its turn before snapping back
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(60))
                        guard !done else { return }
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) { fill = 0 }
                        nudge = true
                        nudgeTask = Task { @MainActor in
                            try? await Task.sleep(for: .seconds(1.4))
                            if !Task.isCancelled { nudge = false }
                        }
                    }
                }
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: done)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("nav.profileMenu.signOut", bundle: .l10n))
            .accessibilityHint(Text("nav.profileMenu.holdHint", bundle: .l10n))
            .accessibilityAddTraits(.isButton)
            // VoiceOver's double-tap is already deliberate
            .accessibilityAction { onComplete() }
    }

    private var label: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.portrait.and.arrow.right")
                .frame(width: 18)
            Text("nav.profileMenu.signOut", bundle: .l10n)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(nudge ? "nav.profileMenu.keepHolding" : "nav.profileMenu.hold", bundle: .l10n)
                .font(Font.geist(12, relativeTo: .caption))
                .opacity(0.6)
        }
        .font(Font.geist(14, relativeTo: .subheadline))
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
