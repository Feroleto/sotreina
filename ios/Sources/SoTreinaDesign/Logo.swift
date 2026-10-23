import SwiftUI

/// The "Pulso" mark, same geometry as the web's `LogoMark`
/// (client/src/components/Logo.tsx, 48×48 viewBox): a heartbeat stroke in
/// the foreground color ending in the mustard dot.
public struct LogoMark: View {
    public init() {}

    public var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height) / 48
            var stroke = Path()
            // M3 27h10l4-14 7.5 24 4.5-10h4
            stroke.move(to: CGPoint(x: 3 * s, y: 27 * s))
            for (x, y) in [(13.0, 27.0), (17, 13), (24.5, 37), (29, 27), (33, 27)] {
                stroke.addLine(to: CGPoint(x: x * s, y: y * s))
            }
            context.stroke(stroke, with: .color(.fg),
                           style: StrokeStyle(lineWidth: 5 * s, lineCap: .round, lineJoin: .round))
            let r = 4.4 * s
            context.fill(Path(ellipseIn: CGRect(x: 41 * s - r, y: 27 * s - r, width: 2 * r, height: 2 * r)),
                         with: .color(.acc))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
