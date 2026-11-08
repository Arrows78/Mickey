import AppKit
import QuartzCore
import MickeyDomain
import MickeyEffects
import MickeySystem

/// Borderless, click-through panel used by the presenter overlays.
final class StudioPanel: NSPanel {
    init(level: NSWindow.Level, clickThrough: Bool = true) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = clickThrough
        self.level = level
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isReleasedWhenClosed = false
        // Hiding Mickey (⌘H, or Hide Others in another app) must not hide the overlays.
        canHide = false
        // Otherwise AppKit hides the panel when Mickey loses focus and shows it again when Mickey gets focus
        // back, even if the tool was turned off meanwhile: a turned-off zoom came back frozen over the screen.
        hidesOnDeactivate = false
        let view = NSView()
        view.wantsLayer = true
        contentView = view
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    var rootLayer: CALayer { contentView!.layer! }
}

/// Live zoom (whole screen) and loupe (glass around the pointer), fed by one screen capture.
final class Magnifier {
    var onError: ((String) -> Void)?

    private let source = ScreenFrameSource()
    private let zoomPanel = StudioPanel(level: OverlayLevel.zoom)
    private let zoomImage = CALayer()
    private let loupePanel = StudioPanel(level: OverlayLevel.toolbar)
    private let loupeImage = CALayer()
    private var zoom = ZoomSettings()
    private var loupe = LoupeSettings()
    private var pointer = CGPoint.zero
    /// Decides how much the screen is magnified at each frame: it glides in and out, and in click mode follows the clicks.
    private var zoomController = ZoomController()

    init() {
        for (panel, image) in [(zoomPanel, zoomImage), (loupePanel, loupeImage)] {
            panel.rootLayer.masksToBounds = true
            panel.rootLayer.backgroundColor = CGColor(gray: 0, alpha: 1)
            image.contentsGravity = .resize
            image.actions = ["contents": NSNull(), "frame": NSNull(), "position": NSNull(), "bounds": NSNull()]
            panel.rootLayer.addSublayer(image)
        }
        source.onFrame = { [weak self] surface in self?.show(surface) }
        source.onError = { [weak self] message in self?.onError?(message) }
    }

    /// True while something is shown or still gliding out, so the capture and the per-frame updates must go on.
    var isActive: Bool { zoom.enabled || loupe.enabled || !zoomController.isIdle }

    /// A mouse click: in click mode the zoom goes in around it.
    func registerClick() { zoomController.click(at: ProcessInfo.processInfo.systemUptime, settings: zoom) }

    /// Tries capturing again after a failure (permission granted, screens changed).
    func retry() { source.retry() }

    func apply(zoom: ZoomSettings, loupe: LoupeSettings) {
        self.zoom = zoom
        self.loupe = loupe
        loupePanel.rootLayer.cornerRadius = loupe.shape == .circle ? loupe.size / 2 : 24
        loupePanel.rootLayer.borderWidth = 3
        loupePanel.rootLayer.borderColor = loupe.borderColor.cgColor
        if !loupe.enabled { loupePanel.orderOut(nil) }
        if isActive {
            update(pointer: NSEvent.mouseLocation)
        } else {
            zoomPanel.orderOut(nil)
            source.stop()
        }
    }

    /// Per-frame update with the pointer position.
    func update(pointer p: CGPoint) {
        guard isActive, let screen = NSScreen.containing(p) else { return }
        pointer = p
        source.capture(screen)
        let level = zoomController.level(at: ProcessInfo.processInfo.systemUptime, settings: zoom,
                                         reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if level > 1.0001 {
            if zoomPanel.frame != screen.frame { zoomPanel.setFrame(screen.frame, display: false) }
            let src = MagnifierGeometry.zoomSource(pointer: p, screen: screen.frame, factor: level)
            zoomImage.frame = MagnifierGeometry.imageFrame(source: src, screen: screen.frame, viewSize: screen.frame.size)
            if zoomImage.contents != nil, !zoomPanel.isVisible { zoomPanel.orderFrontRegardless() }
        } else if zoomPanel.isVisible {
            zoomPanel.orderOut(nil)
        }
        if loupe.enabled {
            let size = loupe.size
            loupePanel.setFrame(CGRect(x: p.x - size / 2, y: p.y - size / 2, width: size, height: size), display: false)
            // With the zoom on, the loupe magnifies the zoomed picture's source area.
            let src = MagnifierGeometry.loupeSource(pointer: p, size: size, factor: loupe.factor * level)
            loupeImage.frame = MagnifierGeometry.imageFrame(source: src, screen: screen.frame, viewSize: CGSize(width: size, height: size))
        }
        CATransaction.commit()
        // The zoom has glided back out and nothing else needs the screen: stop capturing.
        if !isActive { source.stop() }
    }

    private func show(_ surface: IOSurfaceRef) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // The panel itself is shown by `update`, once there is something to magnify.
        if zoom.enabled || !zoomController.isIdle { zoomImage.contents = surface }
        if loupe.enabled {
            loupeImage.contents = surface
            if !loupePanel.isVisible { loupePanel.orderFrontRegardless() }
        }
        CATransaction.commit()
    }
}

/// Dims every screen except a rounded hole around the frontmost window.
final class FocusOverlay {
    private var panels: [StudioPanel] = []
    private var dims: [CAShapeLayer] = []
    private var settings = FocusSettings()
    private var timer: Timer?
    private var lastRect: CGRect?

    func apply(_ s: FocusSettings) {
        settings = s
        if s.enabled {
            // Panels are only rebuilt when the overlay was off: dragging a slider must not flash the screen.
            if timer == nil { rebuild() }
            refresh(force: true)
            if timer == nil {
                // The window list is cheap but not free: ten checks a second follow window moves well enough.
                let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.refresh(force: false) } }
                RunLoop.main.add(t, forMode: .common)
                timer = t
            }
        } else {
            timer?.invalidate(); timer = nil
            panels.forEach { $0.orderOut(nil) }
            lastRect = nil
        }
    }

    func screensChanged() { if settings.enabled { rebuild(); refresh(force: true) } }

    private func rebuild() {
        panels.forEach { $0.orderOut(nil) }
        panels = NSScreen.screens.map { screen in
            let panel = StudioPanel(level: OverlayLevel.focus)
            panel.setFrame(screen.frame, display: false)
            return panel
        }
        dims = panels.map { panel in
            let dim = CAShapeLayer()
            dim.fillRule = .evenOdd
            dim.frame = CGRect(origin: .zero, size: panel.frame.size)
            panel.rootLayer.addSublayer(dim)
            return dim
        }
        panels.forEach { $0.orderFrontRegardless() }
    }

    private func refresh(force: Bool) {
        let rect = FrontWindow.rect()?.insetBy(dx: -settings.padding, dy: -settings.padding)
        guard force || rect != lastRect else { return }
        lastRect = rect
        for (panel, dim) in zip(panels, dims) {
            let bounds = CGRect(origin: .zero, size: panel.frame.size)
            let path = CGMutablePath()
            path.addRect(bounds)
            if let rect, rect.intersects(panel.frame) {
                let local = rect.offsetBy(dx: -panel.frame.minX, dy: -panel.frame.minY)
                let r = min(settings.cornerRadius, local.width / 2, local.height / 2)
                path.addRoundedRect(in: local, cornerWidth: r, cornerHeight: r)
            }
            dim.fillColor = CGColor(gray: 0, alpha: settings.dimOpacity)
            // A short animation makes the hole glide when the front window changes.
            CATransaction.begin()
            CATransaction.setAnimationDuration(force || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.15)
            dim.path = path
            CATransaction.commit()
        }
    }
}
