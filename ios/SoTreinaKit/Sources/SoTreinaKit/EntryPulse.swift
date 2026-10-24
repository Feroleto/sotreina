import Foundation

/// The entry transition (spec login-app-ios §4, design "Bola percorre o
/// pulso"): after signing in, the ball runs the logo's stroke and lights it
/// up, never faster than `minDuration`, and waits at `holdAt` while the
/// destination isn't ready. Geometry in the logo's 48×48 viewBox, the same
/// as `LogoMark`.
public enum EntryPulse {
    public struct Point: Equatable, Sendable {
        public var x: Double
        public var y: Double

        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    /// seconds from the logo appearing to the ball starting
    public static let travelDelay = 0.65
    /// seconds of travel, even when the destination is ready at once
    public static let minDuration = 1.6
    /// how far the ball goes while the destination is still loading
    public static let holdAt = 0.88

    /// `M3 27h10l4-14 7.5 24 4.5-10h4`
    public static let stroke: [Point] = [
        Point(x: 3, y: 27), Point(x: 13, y: 27), Point(x: 17, y: 13),
        Point(x: 24.5, y: 37), Point(x: 29, y: 27), Point(x: 33, y: 27),
    ]
    /// the ball's path: the stroke, then on to the mustard dot at (41, 27)
    public static let ballPath: [Point] = stroke + [Point(x: 41, y: 27)]

    public static let strokeLength = length(of: stroke)
    public static let ballLength = length(of: ballPath)

    /// easeInOutQuad, the design's travel curve
    public static func ease(_ x: Double) -> Double {
        x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2
    }

    /// One frame of travel. `elapsed` counts from the travel's start (it's
    /// negative during `travelDelay`), `dt` is the frame's length. Never
    /// goes back, never jumps more than a third of the way per
    /// `minDuration × 0.3` (so a late load doesn't teleport the ball), and
    /// only reaches 1 once loaded and past `minDuration`.
    public static func step(
        progress p: Double,
        elapsed t: Double,
        dt: Double,
        loaded: Bool,
        minDuration: Double = minDuration
    ) -> Double {
        guard t > 0 else { return p }
        let curve = ease(min(1, t / minDuration))
        let desired = loaded ? curve : min(curve, holdAt)
        var next = max(p, min(desired, p + dt / (minDuration * 0.3)))
        if loaded, t >= minDuration, next > 0.995 { next = 1 }
        return next
    }

    /// Where the ball is at progress `p` (0…1 of `ballPath`).
    public static func ballPoint(at p: Double) -> Point {
        var remaining = min(max(p, 0), 1) * ballLength
        for (a, b) in zip(ballPath, ballPath.dropFirst()) {
            let segment = distance(a, b)
            if remaining <= segment {
                let f = segment == 0 ? 0 : remaining / segment
                return Point(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
            }
            remaining -= segment
        }
        return ballPath[ballPath.count - 1]
    }

    /// How much of the visible stroke is lit behind the ball (0…1 of
    /// `stroke`): all of it once the ball is past the stroke's end.
    public static func litFraction(_ p: Double) -> Double {
        min(1, max(0, p) * ballLength / strokeLength)
    }

    private static func distance(_ a: Point, _ b: Point) -> Double {
        hypot(b.x - a.x, b.y - a.y)
    }

    private static func length(of points: [Point]) -> Double {
        zip(points, points.dropFirst()).reduce(0) { $0 + distance($1.0, $1.1) }
    }
}
