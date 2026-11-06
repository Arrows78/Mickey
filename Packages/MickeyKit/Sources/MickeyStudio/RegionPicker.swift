import AppKit
import MickeyDomain
import MickeyEffects

/// Dims one screen and lets the user drag the rectangle to record. Esc, or a selection that is too small, cancels.
final class RegionPicker {
    private var panel: RegionPanel?

    var isActive: Bool { panel != nil }

    /// `completion` receives the selection in Cocoa screen coordinates, or nil when the selection was cancelled.
    func pick(on screen: NSScreen, completion: @escaping (CGRect?) -> Void) {
        guard panel == nil else { return }
        let panel = RegionPanel(screen: screen)
        panel.selectionView.onFinish = { [weak self] rect in
            self?.close()
            completion(rect)
        }
        self.panel = panel
        panel.orderFrontRegardless()
        // Like the drawing canvas: a non-activating panel that still takes the keyboard, so Esc works.
        panel.makeKey()
        panel.makeFirstResponder(panel.selectionView)
    }

    func cancel() {
        guard let panel else { return }
        close()
        panel.selectionView.onFinish?(nil)
    }

    private func close() {
        panel?.orderOut(nil)
        panel = nil
    }
}

final class RegionPanel: NSPanel {
    let selectionView: RegionSelectionView

    init(screen: NSScreen) {
        selectionView = RegionSelectionView(screen: screen.frame)
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = OverlayLevel.toolbar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isReleasedWhenClosed = false
        canHide = false
        hidesOnDeactivate = false
        contentView = selectionView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class RegionSelectionView: NSView {
    /// Called once, with the selection or nil.
    var onFinish: ((CGRect?) -> Void)?
    /// The screen in Cocoa coordinates: the view is as big as the screen and its origin is the screen's.
    private let screen: CGRect
    private var start: CGPoint?
    private var current: CGPoint?

    init(screen: CGRect) {
        self.screen = screen
        super.init(frame: CGRect(origin: .zero, size: screen.size))
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    private func global(_ localPoint: CGPoint) -> CGPoint { CGPoint(x: localPoint.x + screen.minX, y: localPoint.y + screen.minY) }

    private var dragged: CGRect? {
        guard let start, let current else { return nil }
        return CGRect(x: min(start.x, current.x), y: min(start.y, current.y), width: abs(start.x - current.x), height: abs(start.y - current.y))
    }

    override func mouseDown(with event: NSEvent) {
        start = convert(event.locationInWindow, from: nil)
        current = start
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        guard let start, let current else { return }
        onFinish?(RecordingRegion.selection(from: global(start), to: global(current), in: screen))
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onFinish?(nil) } else { super.keyDown(with: event) } // Escape
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        Self.draw(selection: dragged, in: bounds, context: context)
    }

    /// The dimmed screen with the selection left clear and outlined, its size written next to it; a hint while nothing is selected.
    static func draw(selection: CGRect?, in bounds: CGRect, context c: CGContext) {
        c.setFillColor(CGColor(gray: 0, alpha: 0.35))
        c.fill(bounds)
        guard let selection, selection.width > 1, selection.height > 1 else {
            drawText(tr("Drag to choose the area to record. Esc cancels."), at: CGPoint(x: bounds.midX, y: bounds.midY), size: 18, in: c)
            return
        }
        c.setBlendMode(.clear)
        c.fill(selection)
        c.setBlendMode(.normal)
        c.setStrokeColor(CGColor(gray: 1, alpha: 0.95))
        c.setLineWidth(2)
        c.stroke(selection.insetBy(dx: -1, dy: -1))
        let label = "\(Int(selection.width)) × \(Int(selection.height))"
        drawText(label, at: CGPoint(x: selection.midX, y: max(selection.minY - 18, bounds.minY + 14)), size: 13, in: c)
    }

    private static func drawText(_ text: String, at center: CGPoint, size: CGFloat, in c: CGContext) {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: .semibold), .foregroundColor: NSColor.white]
        let string = NSAttributedString(string: text, attributes: attrs)
        let box = string.size()
        let pad: CGFloat = 8
        let rect = CGRect(x: center.x - box.width / 2 - pad, y: center.y - box.height / 2 - pad / 2, width: box.width + pad * 2, height: box.height + pad)
        c.setFillColor(CGColor(gray: 0, alpha: 0.7))
        c.addPath(CGPath(roundedRect: rect, cornerWidth: 6, cornerHeight: 6, transform: nil))
        c.fillPath()
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: c, flipped: false)
        string.draw(at: CGPoint(x: center.x - box.width / 2, y: center.y - box.height / 2))
        NSGraphicsContext.restoreGraphicsState()
    }
}
