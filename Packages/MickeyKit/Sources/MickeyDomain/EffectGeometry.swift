import CoreGraphics
import Foundation

/// The clear "hole" of the spotlight, in the coordinates of the screen it is drawn on.
public enum SpotlightHole: Equatable, Sendable {
    case ellipse(CGRect)
    case band(CGRect)

    public static func make(center: CGPoint, in screen: CGRect, settings s: SpotlightSettings) -> SpotlightHole {
        switch s.shape {
        case .circle:
            return .ellipse(CGRect(x: center.x - s.radius, y: center.y - s.radius, width: s.radius * 2, height: s.radius * 2))
        case .horizontalBar:
            let h = s.barThickness
            return .band(CGRect(x: screen.minX, y: center.y - h / 2, width: screen.width, height: h))
        case .verticalBar:
            let w = s.barThickness
            return .band(CGRect(x: center.x - w / 2, y: screen.minY, width: w, height: screen.height))
        }
    }

    public var rect: CGRect {
        switch self { case .ellipse(let r), .band(let r): r }
    }

    public func contains(_ p: CGPoint) -> Bool {
        switch self {
        case .band(let r): return r.contains(p)
        case .ellipse(let r):
            let dx = (p.x - r.midX) / (r.width / 2), dy = (p.y - r.midY) / (r.height / 2)
            return dx * dx + dy * dy <= 1
        }
    }
}

/// Timing of click effects: base duration 0.6 s at speed 1.
public enum ClickEffectTiming {
    public static func duration(type: ClickEffectType, speed: Double) -> TimeInterval {
        let base: TimeInterval = switch type {
        case .singleRing, .colorFlash: 0.5
        case .ripple, .ringBurst: 0.8
        case .particleBurst: 0.7
        case .glowPulse: 0.6
        case .scaleBounce: 0.45
        }
        return base / max(speed, 0.05)
    }

    /// Number of concentric rings for multi-ring effects.
    public static func ringCount(_ type: ClickEffectType) -> Int {
        switch type {
        case .ripple: 3
        case .ringBurst: 2
        default: 1
        }
    }
}

/// Shake-to-locate animation: a large ring that shrinks onto the pointer.
public enum LocatorAnimation {
    public static let duration: TimeInterval = 1.0
    public static let startRadius: Double = 220
    public static let endRadius: Double = 28

    public static func radius(progress t: Double) -> Double {
        let p = min(max(t, 0), 1)
        let eased = 1 - pow(1 - p, 3)
        return startRadius + (endRadius - startRadius) * eased
    }
}

/// How effects move when macOS asks to reduce motion: they fade in place instead of scaling or travelling.
public enum ReducedMotion {
    /// The scale animation to play: unchanged normally, held at its end value when motion is reduced.
    public static func scale(from: Double, to: Double, reduced: Bool) -> (from: Double, to: Double) {
        reduced ? (to, to) : (from, to)
    }
}
