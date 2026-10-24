import SoTreinaDesign
import SwiftUI

/// The entry screens' frame (design `Login Transicao.dc.html`): a scroll
/// view at least as tall as the screen, so the content can push itself to
/// the bottom with a `Spacer` and still scroll once the keyboard eats the
/// space. Follows the theme, like the rest of the app (spec §2).
struct EntryScroll<Content: View>: View {
    var submitID: String?
    var focused: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) { content }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                        .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .topLeading)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
                // a focused field scrolls itself into view, not the button
                // under it: bring the button up too (spec §3.1, "Teclado")
                .onChange(of: focused) {
                    guard focused, let submitID else { return }
                    withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(submitID, anchor: .bottom) }
                }
            }
        }
        .background(Color.pageBg.ignoresSafeArea())
    }
}

/// Title and subtitle above a form (`30/600` and `16` in the design).
struct EntryHeading: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title, bundle: .l10n)
                .font(Font.geist(30, relativeTo: .largeTitle).weight(.semibold))
                .tracking(-0.9)
                .foregroundStyle(Color.fg)
            Text(subtitle, bundle: .l10n)
                .font(Font.geist(16, relativeTo: .body))
                .foregroundStyle(Color.mutedFg)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The 54pt input box: card fill, hairline border, 17pt text (above the
/// 16pt floor under which iOS zooms in on focus).
private struct EntryFieldBox: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Font.geist(17, relativeTo: .body))
            .foregroundStyle(Color.fg)
            .tint(Color.acc)
            .padding(.horizontal, 16)
            .frame(minHeight: 54)
            .background(Color.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.border, lineWidth: 1)
            }
    }
}

extension View {
    func entryFieldBox() -> some View { modifier(EntryFieldBox()) }
}

/// Password box with the eye toggle (web `PasswordInput`). One UIKit field
/// whose `isSecureTextEntry` flips in place: swapping a `SecureField` for a
/// `TextField` drops the first responder (the keyboard closes and reopens)
/// and the two have different insets (the eye jumps). Being UIKit, its focus
/// is a `Bool` of its own, not the screen's `FocusState`.
struct EntryPasswordField: View {
    /// L10n key of the placeholder
    let label: String
    @Binding var text: String
    let isNew: Bool
    @Binding var isFocused: Bool
    var returnKey: UIReturnKeyType = .go
    var onSubmit: () -> Void = {}
    @Environment(AppLanguageStore.self) private var language
    @State private var revealed = false

    var body: some View {
        HStack(spacing: 8) {
            PasswordTextField(
                text: $text,
                isFocused: $isFocused,
                revealed: revealed,
                placeholder: L10n.string(label, lang: language.lang),
                contentType: isNew ? .newPassword : .password,
                returnKey: returnKey,
                onSubmit: onSubmit
            )

            Button {
                revealed.toggle()
            } label: {
                Image(systemName: revealed ? "eye.slash" : "eye")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.mutedFg)
                    .frame(width: 32, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(revealed ? "auth.login.hidePassword" : "auth.login.showPassword", bundle: .l10n))
        }
        .entryFieldBox()
    }
}

private struct PasswordTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let revealed: Bool
    let placeholder: String
    let contentType: UITextContentType
    let returnKey: UIReturnKeyType
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        field.font = Self.font
        field.adjustsFontForContentSizeCategory = true
        field.textColor = monolitoUIColor(.foreground)
        field.tintColor = monolitoUIColor(.acc)
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.isSecureTextEntry = true
        // fill the row, never push the eye out
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentHuggingPriority(.required, for: .vertical)
        return field
    }

    /// Its own line height, never the height offered: a UIKit view takes
    /// everything SwiftUI proposes and would eat the screen's `Spacer`.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView field: UITextField, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? field.intrinsicContentSize.width, height: field.intrinsicContentSize.height)
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text { field.text = text }
        field.textContentType = contentType
        field.returnKeyType = returnKey
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: monolitoUIColor(.mutedForeground), .font: Self.font]
        )

        if field.isSecureTextEntry == revealed {
            field.isSecureTextEntry = !revealed
            // the toggle resets the font, and a field turned secure while
            // editing wipes its text on the next keystroke unless it's
            // re-inserted now
            field.font = Self.font
            if !revealed, field.isFirstResponder, let current = field.text, !current.isEmpty {
                field.text = ""
                field.insertText(current)
            }
        }

        if isFocused, !field.isFirstResponder {
            DispatchQueue.main.async { field.becomeFirstResponder() }
        } else if !isFocused, field.isFirstResponder {
            DispatchQueue.main.async { field.resignFirstResponder() }
        }
    }

    private static var font: UIFont { AppFonts.uiFont(17, weight: 400, relativeTo: .body) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: PasswordTextField

        init(_ parent: PasswordTextField) { self.parent = parent }

        @objc func changed(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        func textFieldDidBeginEditing(_ field: UITextField) {
            if !parent.isFocused { parent.isFocused = true }
        }

        func textFieldDidEndEditing(_ field: UITextField) {
            if parent.isFocused { parent.isFocused = false }
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            parent.onSubmit()
            return false
        }
    }
}

/// The entry's main action: the app's primary button at the design's size
/// (54pt, radius 14, 17/600).
struct EntryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Font.geist(17, relativeTo: .body).weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(Color.accFg)
            .background(Color.acc, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Error under the fields, in `--neg`.
struct EntryError<Extra: View>: View {
    let text: Text
    @ViewBuilder var extra: Extra

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            text
                .font(Font.geist(14, relativeTo: .subheadline))
                .foregroundStyle(Color.neg)
            extra
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension EntryError where Extra == EmptyView {
    init(text: Text) {
        self.text = text
        self.extra = EmptyView()
    }
}

/// Privacidade · Suporte, same pair and style as the end of Perfil.
struct EntryLegalLinks: View {
    var body: some View {
        HStack(spacing: 16) {
            Link(destination: WebLinks.privacy) { Text("nav.profile.privacy", bundle: .l10n) }
            Link(destination: WebLinks.support) { Text("nav.profile.support", bundle: .l10n) }
        }
        .font(Font.geist(12.5, relativeTo: .footnote))
        .foregroundStyle(Color.mutedFg)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

/// The pushed entry screens (Criar conta, Esqueci a senha): the bar keeps
/// only the back chevron, the title lives in the content like on Entrar.
extension View {
    func entryPushedScreen() -> some View {
        navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
    }
}
