import AppKit
import QuartzCore
import MickeyDomain

/// Transparent, click-through, always-on-top panel covering one screen.
final class OverlayPanel: NSPanel {
    let screenID: CGDirectDisplayID

    init(screen: NSScreen) {
        screenID = screen.displayID
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = OverlayLevel.effects
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isReleasedWhenClosed = false
        // Hiding Mickey (⌘H, or Hide Others in another app) must not hide the effects.
        canHide = false
        // AppKit would show it again when Mickey gets focus back, even if it was hidden meanwhile.
        hidesOnDeactivate = false
        let view = NSView(frame: CGRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        contentView = view
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Window levels just below the cursor, so effects stay above menus, the Dock and full-screen apps.
/// From bottom to top: focus dimming, live zoom, cursor effects, drawing, then toolbars and HUDs.
public enum OverlayLevel {
    private static let cursor = Int(CGWindowLevelForKey(.cursorWindow))
    public static let focus = NSWindow.Level(rawValue: cursor - 5)
    public static let zoom = NSWindow.Level(rawValue: cursor - 4)
    public static let effects = NSWindow.Level(rawValue: cursor - 3)
    public static let drawing = NSWindow.Level(rawValue: cursor - 2)
    public static let toolbar = NSWindow.Level(rawValue: cursor - 1)
}

extension NSScreen {
    public var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}

/// Layers for one screen.
final class ScreenLayers {
    let panel: OverlayPanel
    let root = CALayer()
    let dim = CAShapeLayer()
    let hole = CAShapeLayer()
    let trail = CALayer()
    let ring = CAShapeLayer()
    let effects = CALayer()

    init(screen: NSScreen) {
        panel = OverlayPanel(screen: screen)
        let host = panel.contentView!.layer!
        root.frame = host.bounds
        host.addSublayer(root)
        dim.fillRule = .evenOdd
        for l in [dim, hole, trail, ring, effects] as [CALayer] {
            l.frame = root.bounds
            root.addSublayer(l)
        }
        ring.fillColor = nil
        ring.bounds = CGRect(x: 0, y: 0, width: 1, height: 1)
        ring.isHidden = true
    }

    var frame: CGRect { panel.frame }
    func local(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x - frame.minX, y: p.y - frame.minY) }
}

/// Renders spotlight, ring, trail, click effects and the shake locator on every screen.
public final class EffectsEngine {
    private var screens: [ScreenLayers] = []
    private var trail = TrailBuffer()
    private var trailPool: [CGDirectDisplayID: [CAShapeLayer]] = [:]
    private var lastRingKey = ""
    private var visible = false

    public init() {
        rebuildScreens()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuildScreens() }
        }
    }

    public func rebuildScreens() {
        screens.forEach { $0.panel.orderOut(nil) }
        screens = NSScreen.screens.map(ScreenLayers.init)
        trailPool.removeAll()
        lastRingKey = ""
        if visible { screens.forEach { $0.panel.orderFrontRegardless() } }
    }

    private func setVisible(_ v: Bool) {
        guard v != visible else { return }
        visible = v
        screens.forEach { v ? $0.panel.orderFrontRegardless() : $0.panel.orderOut(nil) }
    }

    private func screen(containing p: CGPoint) -> ScreenLayers? {
        screens.first { $0.frame.contains(p) } ?? screens.first
    }

    /// Per-frame update.
    public func render(pointer: CGPoint, time: TimeInterval, settings s: Settings, spotlightVisible: Bool) {
        let master = s.general.masterEnabled
        let ringOn = master && s.ring.enabled
        let trailOn = master && s.trail.enabled
        if trailOn { trail.update(position: pointer, time: time, settings: s.trail) } else { trail.clear() }
        let hasTransient = screens.contains { !($0.effects.sublayers ?? []).isEmpty }
        setVisible(spotlightVisible || ringOn || trailOn || hasTransient)
        guard visible else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let current = screen(containing: pointer)
        for layers in screens {
            renderSpotlight(layers, pointer: pointer, isCurrent: layers === current, visible: spotlightVisible, settings: s.spotlight)
            renderRing(layers, pointer: pointer, isCurrent: layers === current, on: ringOn, settings: s.ring)
            renderTrail(layers, time: time, on: trailOn, settings: s.trail)
        }
        CATransaction.commit()
    }

    // MARK: Spotlight

    private func renderSpotlight(_ l: ScreenLayers, pointer: CGPoint, isCurrent: Bool, visible: Bool, settings s: SpotlightSettings) {
        // Only the screen under the pointer is dimmed.
        guard visible && isCurrent else { l.dim.path = nil; l.hole.path = nil; return }
        let bounds = l.root.bounds
        let hole = SpotlightHole.make(center: l.local(pointer), in: bounds, settings: s)
        l.dim.path = Shapes.dimPath(bounds: bounds, hole: hole)
        l.dim.fillColor = CGColor(gray: 0, alpha: s.backgroundOpacity)
        if s.spotOpacity < 1 {
            l.hole.path = Shapes.holePath(hole)
            l.hole.fillColor = CGColor(gray: 0, alpha: s.backgroundOpacity * (1 - s.spotOpacity))
        } else {
            l.hole.path = nil
        }
    }

    // MARK: Ring

    private func renderRing(_ l: ScreenLayers, pointer: CGPoint, isCurrent: Bool, on: Bool, settings s: RingSettings) {
        l.ring.isHidden = !(on && isCurrent)
        guard on && isCurrent else { return }
        l.ring.position = l.local(pointer)
        let key = "\(s.radius)-\(s.thickness)-\(s.color)-\(s.animated)-\(s.animationSpeed)-\(s.neon)-\(l.panel.screenID)"
        guard key != lastRingKey || l.ring.path == nil else { return }
        lastRingKey = key
        l.ring.path = Shapes.circle(radius: s.radius)
        l.ring.lineWidth = s.thickness
        l.ring.strokeColor = s.color.cgColor
        l.ring.shadowColor = s.color.cgColor
        l.ring.shadowRadius = s.neon ? 8 : 0
        l.ring.shadowOpacity = s.neon ? 1 : 0
        l.ring.shadowOffset = .zero
        l.ring.removeAnimation(forKey: "pulse")
        if s.animated {
            let a = CABasicAnimation(keyPath: "transform.scale")
            a.fromValue = 0.9; a.toValue = 1.1
            a.duration = 0.8 / s.animationSpeed
            a.autoreverses = true
            a.repeatCount = .infinity
            a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            l.ring.add(a, forKey: "pulse")
        }
    }

    // MARK: Trail

    private func renderTrail(_ l: ScreenLayers, time: TimeInterval, on: Bool, settings s: TrailSettings) {
        var pool = trailPool[l.panel.screenID] ?? []
        let points = on ? trail.points : []
        let needed = s.style.isDiscrete ? points.count : max(points.count - 1, 0)
        while pool.count < needed {
            let layer = CAShapeLayer()
            l.trail.addSublayer(layer)
            pool.append(layer)
        }
        for (i, layer) in pool.enumerated() {
            guard i < needed else { layer.isHidden = true; continue }
            layer.isHidden = false
            let opacity = Float(trail.opacity(at: s.style.isDiscrete ? i : i + 1, time: time, settings: s))
            layer.opacity = opacity
            let color = s.color.cgColor
            if s.style.isDiscrete {
                let p = l.local(points[i].position)
                let size = CGFloat(s.width) * (s.style == .dots ? 1 : 1.8)
                layer.position = jittered(p, index: i, birth: points[i].birth, style: s.style, time: time)
                layer.path = switch s.style {
                case .stars: Shapes.star(radius: size)
                case .image: Shapes.heart(size: size * 2)
                case .particles: Shapes.circle(radius: size * 0.5)
                default: Shapes.circle(radius: size * 0.6)
                }
                layer.fillColor = s.style == .image ? RGBAColor(red: 1, green: 0.4, blue: 0.6).cgColor : color
                layer.strokeColor = nil
                layer.shadowOpacity = 0
            } else {
                let a = l.local(points[i].position), b = l.local(points[i + 1].position)
                let path = CGMutablePath()
                path.move(to: a); path.addLine(to: b)
                layer.position = .zero
                layer.path = path
                layer.fillColor = nil
                layer.strokeColor = color
                layer.lineCap = s.style == .dashed ? .butt : .round
                layer.lineWidth = s.width
                layer.lineDashPattern = s.style == .dashed ? [NSNumber(value: s.width * 2), NSNumber(value: s.width * 1.5)] : nil
                layer.shadowColor = color
                layer.shadowOpacity = s.style == .glow ? 1 : 0
                layer.shadowRadius = s.style == .glow ? s.width * 1.5 : 0
                layer.shadowOffset = .zero
            }
        }
        trailPool[l.panel.screenID] = pool
    }

    /// Particles drift slightly away from their spawn point as they age.
    private func jittered(_ p: CGPoint, index: Int, birth: TimeInterval, style: TrailStyle, time: TimeInterval) -> CGPoint {
        guard style == .particles else { return p }
        let seed = Double(Int(birth * 1000) % 360) * .pi / 180
        let age = min(time - birth, 1) * 14
        return CGPoint(x: p.x + cos(seed * 7) * age, y: p.y + sin(seed * 11) * age)
    }

    // MARK: Click effects

    public func spawnClick(at point: CGPoint, settings s: ClickSettings) {
        guard let l = screen(containing: point) else { return }
        setVisible(true)
        let center = l.local(point)
        let duration = ClickEffectTiming.duration(type: s.effectType, speed: s.speed)
        let radius = CGFloat(s.size / 2)
        let color = s.color.cgColor
        var layers: [CALayer] = []

        func ring(_ r: CGFloat, delay: Double = 0, from: CGFloat = 0.2, to: CGFloat = 1, dashed: Bool = false) {
            let layer = CAShapeLayer()
            layer.path = Shapes.circle(radius: r)
            layer.position = center
            layer.fillColor = nil
            layer.strokeColor = color
            layer.lineWidth = s.lineWidth
            layer.opacity = 0
            if dashed { layer.lineDashPattern = [6, 5] }
            layer.add(group(duration: duration, delay: delay, scale: (from, to), opacity: (1, 0)), forKey: "fx")
            layers.append(layer)
        }

        switch s.effectType {
        case .singleRing:
            ring(radius)
        case .ripple:
            for i in 0..<ClickEffectTiming.ringCount(.ripple) { ring(radius, delay: Double(i) * duration * 0.18) }
        case .ringBurst:
            ring(radius * 1.2, from: 0.1, to: 1.3, dashed: true)
            ring(radius * 0.6, from: 0.3, to: 1)
        case .colorFlash:
            let layer = CAShapeLayer()
            layer.path = Shapes.circle(radius: radius)
            layer.position = center
            layer.fillColor = color
            layer.opacity = 0
            layer.add(group(duration: duration, scale: (0.5, 1), opacity: (0.6, 0)), forKey: "fx")
            layers.append(layer)
        case .particleBurst:
            for i in 0..<12 {
                let angle = CGFloat(i) / 12 * 2 * .pi
                let dot = CAShapeLayer()
                dot.path = Shapes.circle(radius: max(2, s.lineWidth))
                dot.fillColor = color
                dot.position = center
                dot.opacity = 0
                let move = CABasicAnimation(keyPath: "position")
                move.fromValue = NSValue(point: center)
                move.toValue = NSValue(point: CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius))
                let fade = CABasicAnimation(keyPath: "opacity")
                fade.fromValue = 1; fade.toValue = 0
                let g = CAAnimationGroup()
                g.animations = [move, fade]
                g.duration = duration
                g.timingFunction = CAMediaTimingFunction(name: .easeOut)
                dot.add(g, forKey: "fx")
                layers.append(dot)
            }
        case .glowPulse:
            let layer = CAShapeLayer()
            layer.path = Shapes.circle(radius: radius * 0.6)
            layer.position = center
            layer.fillColor = s.color.withAlpha(0.5).cgColor
            layer.shadowColor = color
            layer.shadowRadius = radius * 0.4
            layer.shadowOpacity = 1
            layer.shadowOffset = .zero
            layer.opacity = 0
            layer.add(group(duration: duration, scale: (0.6, 1.15), opacity: (1, 0)), forKey: "fx")
            layers.append(layer)
        case .scaleBounce:
            let layer = CAShapeLayer()
            layer.path = Shapes.circle(radius: radius * 0.7)
            layer.position = center
            layer.fillColor = nil
            layer.strokeColor = color
            layer.lineWidth = s.lineWidth
            layer.opacity = 0
            let spring = CASpringAnimation(keyPath: "transform.scale")
            spring.fromValue = 0.2; spring.toValue = 1
            spring.damping = 8; spring.initialVelocity = 12
            spring.duration = duration
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [1, 1, 0]; fade.keyTimes = [0, 0.6, 1]
            let g = CAAnimationGroup()
            g.animations = [spring, fade]
            g.duration = duration
            layer.add(g, forKey: "fx")
            layers.append(layer)
        }

        CATransaction.begin()
        CATransaction.setCompletionBlock { MainActor.assumeIsolated { layers.forEach { $0.removeFromSuperlayer() } } }
        layers.forEach(l.effects.addSublayer)
        CATransaction.commit()
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.5) { layers.forEach { $0.removeFromSuperlayer() } }
    }

    /// Shake-to-locate, in the chosen style.
    public func playLocator(at point: CGPoint, color: RGBAColor, style: LocatorStyle) {
        switch style {
        case .ring: playRingLocator(at: point, color: color)
        case .enlargedPointer: playPointerLocator(at: point)
        }
    }

    /// A big pointer over the real one, flashing then shrinking back to normal size.
    private func playPointerLocator(at point: CGPoint) {
        guard let l = screen(containing: point) else { return }
        setVisible(true)
        let layer = CAShapeLayer()
        layer.position = l.local(point)
        layer.path = Shapes.pointer(height: 26)
        layer.fillColor = CGColor(gray: 1, alpha: 1)
        layer.strokeColor = CGColor(gray: 0, alpha: 1)
        layer.lineWidth = 1.2
        layer.lineJoin = .round
        layer.shadowColor = CGColor(gray: 0, alpha: 1)
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: -2)
        layer.opacity = 0
        let d = LocatorAnimation.duration
        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [1, 5, 5, 1]
        scale.keyTimes = [0, 0.15, 0.55, 1]
        scale.timingFunctions = [CAMediaTimingFunction(name: .easeOut), CAMediaTimingFunction(name: .linear), CAMediaTimingFunction(name: .easeInEaseOut)]
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0, 1, 1, 0]; fade.keyTimes = [0, 0.1, 0.85, 1]
        let g = CAAnimationGroup()
        g.animations = [scale, fade]
        g.duration = d
        layer.add(g, forKey: "fx")
        l.effects.addSublayer(layer)
        DispatchQueue.main.asyncAfter(deadline: .now() + d + 0.1) { layer.removeFromSuperlayer() }
    }

    /// A large ring that shrinks onto the pointer.
    private func playRingLocator(at point: CGPoint, color: RGBAColor) {
        guard let l = screen(containing: point) else { return }
        setVisible(true)
        let layer = CAShapeLayer()
        layer.position = l.local(point)
        layer.path = Shapes.circle(radius: LocatorAnimation.endRadius)
        layer.fillColor = color.withAlpha(0.15).cgColor
        layer.strokeColor = color.cgColor
        layer.lineWidth = 5
        layer.shadowColor = CGColor(gray: 0, alpha: 1)
        layer.shadowOpacity = 0.5
        layer.shadowRadius = 6
        layer.shadowOffset = .zero
        layer.opacity = 0
        let d = LocatorAnimation.duration
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = LocatorAnimation.startRadius / LocatorAnimation.endRadius
        scale.toValue = 1
        scale.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.3, 1)
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0, 1, 1, 0]; fade.keyTimes = [0, 0.1, 0.75, 1]
        let g = CAAnimationGroup()
        g.animations = [scale, fade]
        g.duration = d
        layer.add(g, forKey: "fx")
        l.effects.addSublayer(layer)
        DispatchQueue.main.asyncAfter(deadline: .now() + d + 0.1) { layer.removeFromSuperlayer() }
    }

    private func group(duration: Double, delay: Double = 0, scale: (CGFloat, CGFloat), opacity: (Float, Float)) -> CAAnimationGroup {
        let sc = CABasicAnimation(keyPath: "transform.scale")
        sc.fromValue = scale.0; sc.toValue = scale.1
        sc.timingFunction = CAMediaTimingFunction(name: .easeOut)
        let op = CABasicAnimation(keyPath: "opacity")
        op.fromValue = opacity.0; op.toValue = opacity.1
        let g = CAAnimationGroup()
        g.animations = [sc, op]
        g.duration = duration
        g.beginTime = CACurrentMediaTime() + delay
        g.fillMode = .backwards
        return g
    }
}
