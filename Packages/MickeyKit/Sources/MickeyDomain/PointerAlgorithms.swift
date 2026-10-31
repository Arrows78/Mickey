import CoreGraphics
import Foundation

public struct PointerSample: Equatable, Sendable {
    public var position: CGPoint
    public var time: TimeInterval
    public init(_ position: CGPoint, at time: TimeInterval) { self.position = position; self.time = time }
}

/// Detects a rapid back-and-forth "shake" of the pointer.
///
/// A shake is a burst of direction reversals on either axis inside a short window, while the
/// pointer stays roughly in place. Higher sensitivity lowers both the movement threshold and
/// the number of reversals required.
public struct ShakeDetector: Sendable {
    public var sensitivity: Double
    public var window: TimeInterval = 0.5
    public var maxSamples = 30
    public var cooldown: TimeInterval = 1.5
    public var maxDisplacement: Double = 200

    public private(set) var samples: [PointerSample] = []
    public private(set) var lastShake: TimeInterval = -.infinity

    public init(sensitivity: Double) { self.sensitivity = sensitivity }

    /// Minimum per-step movement (points) for a step to count toward a reversal.
    public var stepThreshold: Double { (1.1 - sensitivity) * 5 }
    /// Number of reversals (x + y) required.
    public var requiredReversals: Int { Int(6 - 3 * sensitivity) }

    /// Feeds a sample; returns true when a shake is detected.
    public mutating func add(_ sample: PointerSample) -> Bool {
        if let last = samples.last, last.position == sample.position { return false }
        samples.append(sample)
        samples.removeAll { sample.time - $0.time > window }
        if samples.count > maxSamples { samples.removeFirst(samples.count - maxSamples) }
        guard samples.count >= 5, sample.time - lastShake > cooldown else { return false }

        var reversals = 0
        var prevDX = 0.0, prevDY = 0.0
        let threshold = stepThreshold
        for i in 1..<samples.count {
            let dx = samples[i].position.x - samples[i - 1].position.x
            let dy = samples[i].position.y - samples[i - 1].position.y
            if i > 1 {
                if dx * prevDX < 0 && abs(dx) > threshold && abs(prevDX) > threshold { reversals += 1 }
                if dy * prevDY < 0 && abs(dy) > threshold && abs(prevDY) > threshold { reversals += 1 }
            }
            prevDX = dx; prevDY = dy
        }
        let first = samples[0].position, last = samples[samples.count - 1].position
        let displacement = hypot(last.x - first.x, last.y - first.y)
        guard reversals >= requiredReversals, displacement < maxDisplacement else { return false }
        lastShake = sample.time
        samples.removeAll()
        return true
    }
}

/// Bounded list of recent pointer positions, used to draw the trail.
public struct TrailBuffer: Sendable {
    public struct Point: Equatable, Sendable {
        public var position: CGPoint
        public var birth: TimeInterval
    }

    public private(set) var points: [Point] = []
    private var lastSpawn: TimeInterval = -.infinity

    public init() {}

    /// Lifetime of a trail point: one second at fade speed 1.
    public static func lifetime(fadeSpeed: Double) -> TimeInterval { 1.0 / max(fadeSpeed, 0.01) }

    public mutating func update(position: CGPoint, time: TimeInterval, settings: TrailSettings) {
        let life = Self.lifetime(fadeSpeed: settings.fadeSpeed)
        points.removeAll { time - $0.birth > life }
        let moved = points.last.map { hypot($0.position.x - position.x, $0.position.y - position.y) } ?? .infinity
        // Discrete styles spawn items at most `spawnRate` px apart (lower = denser);
        // continuous styles keep every distinct sample.
        let minSpacing = settings.style.isDiscrete ? settings.spawnRate * 4 : 1
        if moved >= minSpacing {
            points.append(Point(position: position, birth: time))
            lastSpawn = time
        }
        if points.count > settings.length { points.removeFirst(points.count - settings.length) }
    }

    /// Opacity of point `index` (0 = oldest) at `time`.
    public func opacity(at index: Int, time: TimeInterval, settings: TrailSettings) -> Double {
        guard points.indices.contains(index) else { return 0 }
        let positional = Double(index + 1) / Double(points.count)
        let age = (time - points[index].birth) / Self.lifetime(fadeSpeed: settings.fadeSpeed)
        return settings.opacity * positional * max(0, 1 - age)
    }

    public mutating func clear() { points.removeAll() }
}

/// Recognizes a lone, short press of a trigger key (no other key, click or scroll meanwhile).
public struct TapRecognizer: Sendable {
    public var maxDuration: TimeInterval = 0.35
    private var downAt: TimeInterval?
    private var cancelled = false

    public init() {}

    public mutating func keyDown(at t: TimeInterval) { downAt = t; cancelled = false }
    public mutating func otherInput() { if downAt != nil { cancelled = true } }

    /// Returns true when the release completes a valid tap.
    public mutating func keyUp(at t: TimeInterval) -> Bool {
        defer { downAt = nil; cancelled = false }
        guard let d = downAt, !cancelled else { return false }
        return t - d <= maxDuration
    }

    public var isDown: Bool { downAt != nil }
}

/// Turns "key held for at least `delay`" into begin/end events.
public struct HoldRecognizer: Sendable {
    public enum Event: Equatable, Sendable { case began, ended }
    public var delay: TimeInterval
    private var downAt: TimeInterval?
    public private(set) var isActive = false

    public init(delay: TimeInterval) { self.delay = delay }

    /// Call on every poll with the current key state; returns an event on transitions.
    public mutating func update(isDown: Bool, at t: TimeInterval) -> Event? {
        if isDown {
            if downAt == nil { downAt = t }
            if !isActive, let d = downAt, t - d >= delay { isActive = true; return .began }
        } else {
            downAt = nil
            if isActive { isActive = false; return .ended }
        }
        return nil
    }

    /// Cancels a pending hold (e.g. the key was used in a combination).
    public mutating func cancelPending() { if !isActive { downAt = nil } }
}

/// "Turn off when moving": once armed, reports when the pointer leaves the anchor radius.
public struct SpotlightDismissTracker: Sendable {
    public var armDelay: TimeInterval = 0.25
    private var anchor: CGPoint?
    private var armedAt: TimeInterval = 0

    public init() {}

    public mutating func arm(at position: CGPoint, time: TimeInterval) { anchor = position; armedAt = time }
    public mutating func disarm() { anchor = nil }
    public var isArmed: Bool { anchor != nil }

    /// Returns true when the spotlight should be dismissed.
    public mutating func shouldDismiss(position: CGPoint, time: TimeInterval, distance: Double) -> Bool {
        guard let a = anchor else { return false }
        if time - armedAt < armDelay { anchor = position; return false }
        if hypot(position.x - a.x, position.y - a.y) > distance { anchor = nil; return true }
        return false
    }
}
