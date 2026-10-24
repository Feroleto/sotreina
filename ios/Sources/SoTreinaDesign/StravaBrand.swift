import SwiftUI
import UIKit

/// "Powered by Strava" (the web's `PoweredByStrava`): black on light, white
/// on dark, 14pt tall. The PNGs are the official SVGs from
/// `client/src/assets/strava/` rendered @3x without any change — the brand
/// guidelines forbid altering the logo (color, opacity, proportions).
public struct PoweredByStrava: View {
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        if let image = Self.image(colorScheme == .dark ? "white" : "black") {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(height: 14)
                .accessibilityLabel(Text(verbatim: "Powered by Strava"))
        }
    }

    private static func image(_ variant: String) -> UIImage? {
        guard let url = Bundle.module.url(
            forResource: "powered_by_strava_\(variant)@3x", withExtension: "png", subdirectory: "Strava"
        ), let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data, scale: 3)
    }
}

/// "Connect with Strava" (the web's `ConnectWithStrava`): the official orange
/// button, 48pt tall, the SVG rendered @3x unchanged like `PoweredByStrava`.
/// The kit's orange variant is the one the web uses on both themes.
public struct ConnectWithStrava: View {
    private let busy: Bool
    private let action: () -> Void

    public init(busy: Bool = false, action: @escaping () -> Void) {
        self.busy = busy
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            if let image = Self.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 48)
            }
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .opacity(busy ? 0.6 : 1)
        .accessibilityLabel(Text(verbatim: "Connect with Strava"))
    }

    private static let image: UIImage? = {
        guard let url = Bundle.module.url(
            forResource: "connect_with_strava_orange@3x", withExtension: "png", subdirectory: "Strava"
        ), let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data, scale: 3)
    }()
}
