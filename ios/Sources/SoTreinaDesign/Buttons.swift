import SwiftUI

/// The `press` utility of the web: scale 0.96 while pressed, skipped under
/// Reduce Motion.
private struct Press: ViewModifier {
    let pressed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed && !reduceMotion ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: pressed)
    }
}

/// Primary action: mustard block, dark text (`rounded-[11px] bg-acc text-acc-fg`).
public struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSFont.button)
            .frame(maxWidth: .infinity, minHeight: 46)
            .padding(.horizontal, 16)
            .foregroundStyle(Color.accFg)
            .background(Color.acc, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .opacity(isEnabled ? 1 : 0.5)
            .modifier(Press(pressed: configuration.isPressed))
    }
}

/// Compact mustard pill in a row ("Iniciar": `h-10 rounded-full bg-acc px-[18px]`).
public struct PillButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSFont.pill)
            .padding(.horizontal, 18)
            .frame(minHeight: 40)
            .foregroundStyle(Color.accFg)
            .background(Color.acc, in: Capsule())
            .opacity(isEnabled ? 1 : 0.5)
            .modifier(Press(pressed: configuration.isPressed))
    }
}

/// Secondary action: neutral chip (`rounded-full bg-chip text-foreground`).
public struct ChipButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSFont.pill)
            .monospacedDigit()
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .foregroundStyle(Color.fg)
            .background(Color.chip, in: Capsule())
            .opacity(isEnabled ? 1 : 0.4)
            .modifier(Press(pressed: configuration.isPressed))
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    public static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == PillButtonStyle {
    public static var pill: PillButtonStyle { PillButtonStyle() }
}

extension ButtonStyle where Self == ChipButtonStyle {
    public static var chip: ChipButtonStyle { ChipButtonStyle() }
}
