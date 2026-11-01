import AppKit
import Observation
import SwiftUI
import MickeyDomain
import MickeyEffects

/// Owns draw mode: the canvas window, the toolbar window and the drawing session.
@Observable
public final class AnnotationController {
    public private(set) var isDrawing = false
    /// Draw mode entered by holding a key; ends when the key is released.
    public private(set) var isMomentary = false
    public var session = AnnotationSession(tool: .freehand, color: .red) { didSet { canvas?.needsDisplay = true } }
    public var settings = AnnotationSettings()
    public var onDrawingChanged: ((Bool) -> Void)?
    /// Called when the toolbar edits a persisted setting (stroke width).
    public var onSettingsEdited: ((AnnotationSettings) -> Void)?

    @ObservationIgnored private var canvasPanel: CanvasPanel?
    @ObservationIgnored private var canvas: CanvasView?
    @ObservationIgnored private var toolbarPanel: NSPanel?
    @ObservationIgnored private var fadeTimer: Timer?
    @ObservationIgnored private var previousApp: NSRunningApplication?

    public init() {}

    public func apply(_ s: AnnotationSettings) {
        let firstTime = settings == AnnotationSettings() && session.annotations.isEmpty
        settings = s
        if firstTime || !isDrawing { session.selectedTool = s.defaultTool; session.color = s.color }
        updateFadeTimer()
        if !s.enabled && isDrawing { exit() }
    }

    public func toggle() { isDrawing ? exit() : enter(momentary: false) }

    public func enter(momentary: Bool) {
        guard !isDrawing else { return }
        isMomentary = momentary
        isDrawing = true
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        guard let screen else { return }
        showCanvas(on: screen)
        canvasPanel?.ignoresMouseEvents = false
        if momentary {
            // The canvas is a non-activating panel: it takes the keyboard without activating Mickey,
            // so tool shortcuts work while Fn is held and the previous app stays frontmost.
            canvasPanel?.makeKey()
        } else {
            previousApp = NSWorkspace.shared.frontmostApplication
            canvasPanel?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        // Without this, Esc and the tool shortcuts only work after a first click.
        canvasPanel?.makeFirstResponder(canvas)
        NSCursor.crosshair.push()
        showToolbar(on: screen)
        onDrawingChanged?(true)
    }

    public func exit() {
        guard isDrawing else { return }
        commitTextEditing()
        session.end()
        isDrawing = false
        isMomentary = false
        NSCursor.pop()
        canvasPanel?.ignoresMouseEvents = true
        toolbarPanel?.orderOut(nil)
        if settings.clearOnExit { session.clearAll() }
        if session.annotations.isEmpty { canvasPanel?.orderOut(nil) }
        if let app = previousApp, app != NSRunningApplication.current { app.activate() }
        previousApp = nil
        onDrawingChanged?(false)
    }

    /// Momentary mode ends when the trigger key is released, unless the user made it sticky.
    public func endMomentary() { if isMomentary { exit() } }

    public func select(_ tool: AnnotationTool) { commitTextEditing(); session.selectedTool = tool }
    public func setColor(_ c: RGBAColor) { session.color = c }
    public func setStrokeWidth(_ w: Double) {
        settings.strokeWidth = w
        onSettingsEdited?(settings)
    }
    public func undo() { session.undo(); hideIfIdle() }
    public func clearAll() { session.clearAll(); hideIfIdle() }

    private func hideIfIdle() { if !isDrawing && session.annotations.isEmpty { canvasPanel?.orderOut(nil) } }

    // MARK: Windows

    private func showCanvas(on screen: NSScreen) {
        if canvasPanel?.frame != screen.frame {
            canvasPanel?.orderOut(nil)
            let panel = CanvasPanel(frame: screen.frame)
            let view = CanvasView(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.controller = self
            panel.contentView = view
            canvasPanel = panel
            canvas = view
        }
        canvasPanel?.orderFrontRegardless()
        canvas?.needsDisplay = true
    }

    private func showToolbar(on screen: NSScreen) {
        if toolbarPanel == nil {
            let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.level = OverlayLevel.toolbar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.hasShadow = true
            panel.canHide = false
            let host = NSHostingView(rootView: AnnotationToolbarView(controller: self))
            panel.contentView = host
            panel.setContentSize(host.fittingSize)
            toolbarPanel = panel
        }
        guard let panel = toolbarPanel else { return }
        let size = panel.contentView?.fittingSize ?? panel.frame.size
        let visible = screen.visibleFrame
        panel.setFrame(CGRect(x: visible.midX - size.width / 2, y: visible.maxY - size.height - 12,
                              width: size.width, height: size.height), display: true)
        panel.orderFrontRegardless()
    }

    private func updateFadeTimer() {
        fadeTimer?.invalidate(); fadeTimer = nil
        guard settings.autoFade else { return }
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.session.removeExpired(now: Self.now, delay: self.settings.autoFadeDelay) { self.hideIfIdle() }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        fadeTimer = t
    }

    static var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    // MARK: Canvas callbacks

    func mouseDown(at p: CGPoint) {
        commitTextEditing()
        session.begin(at: p, time: Self.now, settings: settings)
        if let id = session.editingTextID, let a = session.annotations.first(where: { $0.id == id }) {
            canvas?.beginTextEditing(a)
        }
    }

    func mouseDragged(to p: CGPoint) { session.drag(to: p) }
    func mouseUp() { session.end() }

    func commitTextEditing() {
        guard let id = session.editingTextID else { return }
        session.setText(canvas?.endTextEditing() ?? "", for: id)
    }

    /// Returns true when the key was handled.
    func keyDown(_ event: NSEvent) -> Bool {
        if event.keyCode == 53 { exit(); return true } // Escape
        let cmd = event.modifierFlags.contains(.command)
        if cmd && event.charactersIgnoringModifiers == "z" { undo(); return true }
        if cmd && (event.keyCode == 51 || event.keyCode == 117) { clearAll(); return true } // ⌘⌫ / ⌘⌦
        if !cmd, let c = event.charactersIgnoringModifiers?.first, let tool = AnnotationTool.forShortcut(c) {
            select(tool); return true
        }
        return false
    }
}

final class CanvasPanel: NSPanel {
    init(frame: CGRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = OverlayLevel.drawing
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        ignoresMouseEvents = true
        acceptsMouseMovedEvents = true
        isReleasedWhenClosed = false
        canHide = false
    }
    override var canBecomeKey: Bool { true }
}

final class CanvasView: NSView {
    weak var controller: AnnotationController?
    private var textField: NSTextField?

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with e: NSEvent) { window?.makeFirstResponder(self); controller?.mouseDown(at: convert(e.locationInWindow, from: nil)) }
    override func mouseDragged(with e: NSEvent) { controller?.mouseDragged(to: convert(e.locationInWindow, from: nil)) }
    override func mouseUp(with e: NSEvent) { controller?.mouseUp() }
    override func keyDown(with e: NSEvent) { if controller?.keyDown(e) != true { super.keyDown(with: e) } }

    func beginTextEditing(_ a: Annotation) {
        let field = NSTextField(frame: CGRect(x: a.points[0].x, y: a.points[0].y - a.width * 0.6, width: 320, height: a.width * 1.4))
        field.font = .boldSystemFont(ofSize: a.width)
        field.textColor = a.color.nsColor
        field.drawsBackground = false
        field.isBordered = false
        field.focusRingType = .none
        field.placeholderString = "Type…"
        field.target = self
        field.action = #selector(commitText)
        addSubview(field)
        window?.makeFirstResponder(field)
        textField = field
    }

    @objc private func commitText() { controller?.commitTextEditing(); window?.makeFirstResponder(self) }

    func endTextEditing() -> String {
        let text = textField?.stringValue ?? ""
        textField?.removeFromSuperview()
        textField = nil
        return text
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let c = NSGraphicsContext.current?.cgContext, let controller else { return }
        let items = controller.session.annotations + (controller.session.current.map { [$0] } ?? [])
        for a in items where a.id != controller.session.editingTextID { AnnotationRenderer.draw(a, in: c) }
    }
}

enum AnnotationRenderer {
    static func draw(_ a: Annotation, in c: CGContext) {
        c.saveGState()
        defer { c.restoreGState() }
        c.setLineCap(.round)
        c.setLineJoin(.round)
        c.setStrokeColor(a.color.cgColor)
        c.setFillColor(a.color.cgColor)
        c.setLineWidth(a.width)
        let pts = a.points
        switch a.tool {
        case .freehand, .highlighter:
            guard let first = pts.first else { return }
            if a.tool == .highlighter { c.setBlendMode(.multiply); c.setLineCap(.butt) }
            c.move(to: first)
            if pts.count == 1 { c.addLine(to: first) }
            pts.dropFirst().forEach { c.addLine(to: $0) }
            c.strokePath()
        case .line, .arrow:
            c.move(to: pts[0]); c.addLine(to: pts[1]); c.strokePath()
            if a.tool == .arrow {
                let (l, r) = ArrowGeometry.head(from: pts[0], to: pts[1], width: a.width)
                c.move(to: l); c.addLine(to: pts[1]); c.addLine(to: r); c.strokePath()
            }
        case .rectangle:
            c.stroke(CGRect(x: min(pts[0].x, pts[1].x), y: min(pts[0].y, pts[1].y),
                            width: abs(pts[1].x - pts[0].x), height: abs(pts[1].y - pts[0].y)))
        case .circle:
            c.strokeEllipse(in: CGRect(x: min(pts[0].x, pts[1].x), y: min(pts[0].y, pts[1].y),
                                       width: abs(pts[1].x - pts[0].x), height: abs(pts[1].y - pts[0].y)))
        case .text:
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: a.width), .foregroundColor: a.color.nsColor]
            NSAttributedString(string: a.text ?? "", attributes: attrs).draw(at: CGPoint(x: pts[0].x, y: pts[0].y - a.width * 0.6))
        case .callout:
            let r = a.width
            c.fillEllipse(in: CGRect(x: pts[0].x - r, y: pts[0].y - r, width: r * 2, height: r * 2))
            let label = "\(a.calloutNumber ?? 0)"
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: r, weight: .heavy), .foregroundColor: NSColor.white]
            let str = NSAttributedString(string: label, attributes: attrs)
            let size = str.size()
            str.draw(at: CGPoint(x: pts[0].x - size.width / 2, y: pts[0].y - size.height / 2))
        }
    }
}
