import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// "Bola percorre o pulso" (spec login-app-ios §4), laid over the
/// destination once the entry form has played its exit:
///
/// 1. the logo appears (fade, zoom, blur out),
/// 2. the ball runs the stroke and lights it (`EntryPulse.step`: at least
///    1.6 s, waiting at 88% until `ready`),
/// 3. a quick pulse,
/// 4. a mustard circle grows from the ball to cover the screen,
/// 5. `onReveal` (the destination comes in) as the circle fades, then
///    `onFinish`.
///
/// Under Reduce Motion: the logo fades in complete and still, and fades out
/// as soon as the destination is ready.
struct EntryTransitionView: View {
    /// the destination finished its first load
    let ready: Bool
    let onReveal: () -> Void
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clock = TravelClock()
    @State private var phase: Phase = .travel
    @State private var logoShown = false
    @State private var ballScale: CGFloat = 1
    @State private var expandScale: CGFloat = 1
    @State private var circleOpacity = 1.0
    @State private var overlayOpacity = 1.0
    @State private var logoFrame: CGRect = .zero
    @State private var screen: CGSize = .zero

    private enum Phase {
        case travel
        case pulse
        case expand
        case reveal
    }

    private static let logoSize: CGFloat = 168
    private static let unit = logoSize / 48
    private static let ballDiameter = 2 * 4.4 * unit
    /// past this, the destination shows even if it hasn't finished loading
    /// (its own loading and error states take over)
    private static let readyTimeout: TimeInterval = 10

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if phase != .reveal {
                    Color.pageBg
                    logo
                }
                if phase == .expand || phase == .reveal {
                    Circle()
                        .fill(Color.acc)
                        .frame(width: Self.ballDiameter, height: Self.ballDiameter)
                        .scaleEffect(expandScale)
                        .position(ballCenter(at: 1))
                        .opacity(circleOpacity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .coordinateSpace(.named(Self.space))
            .onAppear { start(screen: geo.size) }
            .onChange(of: ready) { if reduceMotion, ready { finishStill() } }
        }
        .ignoresSafeArea()
        .opacity(overlayOpacity)
        .accessibilityHidden(true)
    }

    private static let space = "entryTransition"

    private var logo: some View {
        VStack(spacing: 18) {
            TimelineView(.animation(paused: phase != .travel || reduceMotion)) { context in
                let p = reduceMotion ? 1 : clock.tick(context.date, ready: ready, onArrive: arrive)
                PulseStroke(lit: EntryPulse.litFraction(p))
                    .frame(width: Self.logoSize, height: Self.logoSize)
                    .overlay(alignment: .topLeading) {
                        if phase != .expand {
                            let point = EntryPulse.ballPoint(at: p)
                            Circle()
                                .fill(Color.acc)
                                .frame(width: Self.ballDiameter, height: Self.ballDiameter)
                                .scaleEffect(ballScale)
                                .position(x: point.x * Self.unit, y: point.y * Self.unit)
                        }
                    }
            }
            .frame(width: Self.logoSize, height: Self.logoSize)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { logoFrame = $0 }

            Text(verbatim: "SoTreina")
                .font(Font.geist(30, relativeTo: .largeTitle).weight(.semibold))
                .tracking(-1.2)
                .foregroundStyle(Color.fg)
        }
        .opacity(logoShown ? 1 : 0)
        .scaleEffect(logoShown || reduceMotion ? 1 : 0.92)
        .blur(radius: logoShown || reduceMotion ? 0 : 6)
    }

    private func ballCenter(at p: Double) -> CGPoint {
        let point = EntryPulse.ballPoint(at: p)
        return CGPoint(x: logoFrame.minX + point.x * Self.unit, y: logoFrame.minY + point.y * Self.unit)
    }

    private func start(screen: CGSize) {
        self.screen = screen
        if reduceMotion {
            withAnimation(.linear(duration: 0.2)) { logoShown = true }
            if ready { finishStill() }
            return
        }
        clock.begin(at: .now, timeout: Self.readyTimeout)
        withAnimation(.timingCurve(0.2, 0.7, 0.2, 1, duration: 0.52)) { logoShown = true }
    }

    /// The ball reached the dot: pulse (1.3×, 320 ms), then expand.
    private func arrive() {
        guard phase == .travel else { return }
        phase = .pulse
        withAnimation(.easeOut(duration: 0.16)) {
            ballScale = 1.3
        } completion: {
            withAnimation(.easeOut(duration: 0.16)) { ballScale = 1 }
        }
        Task {
            try? await Task.sleep(for: .milliseconds(380))
            expand()
        }
    }

    private func expand() {
        let center = ballCenter(at: 1)
        let corners = [CGPoint.zero, CGPoint(x: screen.width, y: 0), CGPoint(x: 0, y: screen.height),
                       CGPoint(x: screen.width, y: screen.height)]
        let radius = corners.map { hypot($0.x - center.x, $0.y - center.y) }.max() ?? screen.height
        phase = .expand
        withAnimation(.timingCurve(0.65, 0, 0.35, 1, duration: 0.65)) {
            expandScale = (2 * radius + 4) / Self.ballDiameter
        } completion: {
            phase = .reveal
            onReveal()
            withAnimation(.easeOut(duration: 0.32)) {
                circleOpacity = 0
            } completion: {
                onFinish()
            }
        }
    }

    /// Reduce Motion: no travel, no circle — the still logo fades out over
    /// the destination fading in.
    private func finishStill() {
        guard phase == .travel else { return }
        phase = .reveal
        onReveal()
        withAnimation(.linear(duration: 0.3)) {
            overlayOpacity = 0
        } completion: {
            onFinish()
        }
    }
}

/// The travel's progress, advanced once per frame by the `TimelineView`.
/// A class outside SwiftUI's state on purpose: it changes every frame
/// inside `body`, and only the arrival is a state change (deferred).
@MainActor
private final class TravelClock {
    private var startedAt: Date?
    private var lastFrame: Date?
    private var timeout: TimeInterval = 10
    private var arrived = false
    private(set) var progress = 0.0

    func begin(at date: Date, timeout: TimeInterval) {
        startedAt = date
        lastFrame = date
        self.timeout = timeout
    }

    func tick(_ now: Date, ready: Bool, onArrive: @escaping () -> Void) -> Double {
        guard let startedAt, let last = lastFrame else { return progress }
        let elapsed = now.timeIntervalSince(startedAt) - EntryPulse.travelDelay
        let dt = max(0, now.timeIntervalSince(last))
        lastFrame = now
        progress = EntryPulse.step(
            progress: progress, elapsed: elapsed, dt: dt,
            loaded: ready || elapsed > timeout
        )
        if progress >= 1, !arrived {
            arrived = true
            // not a state change in the middle of `body`
            DispatchQueue.main.async(execute: onArrive)
        }
        return progress
    }
}

/// The logo's stroke: a faint base and the lit part behind the ball.
private struct PulseStroke: View {
    let lit: Double

    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height) / 48
            var path = Path()
            for (i, point) in EntryPulse.stroke.enumerated() {
                let p = CGPoint(x: point.x * s, y: point.y * s)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            let style = StrokeStyle(lineWidth: 5 * s, lineCap: .round, lineJoin: .round)
            context.stroke(path, with: .color(Color.fg.opacity(0.18)), style: style)
            if lit > 0 {
                context.stroke(path.trimmedPath(from: 0, to: lit), with: .color(.fg), style: style)
            }
        }
    }
}
