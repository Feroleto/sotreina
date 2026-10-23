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
