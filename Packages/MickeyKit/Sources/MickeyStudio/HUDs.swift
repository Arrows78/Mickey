import AppKit
import AVFoundation
import Observation
import SwiftUI
import MickeyDomain
import MickeyEffects
import MickeySystem

/// Frame of a HUD band of `height` on `screen` for `position`.
func hudFrame(on screen: NSScreen, position: HUDPosition, height: CGFloat) -> CGRect {
    let v = screen.visibleFrame
    let y = position == .topCenter ? v.maxY - height - 24 : v.minY + 48
    return CGRect(x: v.minX + 24, y: y, width: v.width - 48, height: height)
}

func hudAlignment(_ position: HUDPosition) -> Alignment {
    switch position {
    case .bottomCenter: .bottom
    case .topCenter: .top
    case .bottomLeft: .bottomLeading
    case .bottomRight: .bottomTrailing
    }
}

// MARK: Keystrokes

@Observable
final class KeystrokeHUDModel {
    var history = KeystrokeHistory()
    var settings = KeystrokeSettings()
}

struct KeystrokeHUDView: View {
    let model: KeystrokeHUDModel

    var body: some View {
        let stack = HStack(spacing: 10) {
            ForEach(model.history.entries) { entry in
                Text(entry.label)
                    .font(.system(size: model.settings.fontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, model.settings.fontSize * 0.55)
                    .padding(.vertical, model.settings.fontSize * 0.3)
                    .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: model.settings.fontSize * 0.4))
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeOut(duration: 0.15), value: model.history.entries)
        return stack.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: hudAlignment(model.settings.position))
    }
}

/// Shows typed shortcuts at the bottom (or top) of the screen under the pointer.
final class KeystrokeHUD {
    var onPermissionMissing: (() -> Void)?

    private let monitor = KeystrokeMonitor()
    private let model = KeystrokeHUDModel()
    private let panel = StudioPanel(level: OverlayLevel.toolbar)
    private var timer: Timer?

    init() {
        let host = NSHostingView(rootView: KeystrokeHUDView(model: model))
        host.frame = panel.contentView!.bounds
        host.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(host)
        monitor.onKey = { [weak self] flags, code, chars in self?.key(flags: flags, code: code, chars: chars) }
    }

    func apply(_ s: KeystrokeSettings) {
        model.settings = s
        if s.enabled {
            if !monitor.start() { onPermissionMissing?() }
        } else {
            monitor.stop()
            model.history = KeystrokeHistory()
            panel.orderOut(nil)
        }
    }

    /// Retries after the user grants Input Monitoring.
    func retry() { if model.settings.enabled { apply(model.settings) } }

    private func key(flags: UInt64, code: UInt16, chars: String) {
        guard let text = KeystrokeFormatter.format(flags: flags, keyCode: code, characters: chars,
                                                   shortcutsOnly: model.settings.shortcutsOnly),
              let screen = NSScreen.containing(NSEvent.mouseLocation) else { return }
        model.history.add(text, at: ProcessInfo.processInfo.systemUptime)
        panel.setFrame(hudFrame(on: screen, position: model.settings.position, height: model.settings.fontSize * 2.4), display: false)
        panel.orderFrontRegardless()
        if timer == nil {
            let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.expire() } }
            RunLoop.main.add(t, forMode: .common)
            timer = t
        }
    }

    private func expire() {
        model.history.expire(now: ProcessInfo.processInfo.systemUptime, duration: model.settings.duration)
        if model.history.entries.isEmpty {
            timer?.invalidate(); timer = nil
            panel.orderOut(nil)
        }
    }
}

// MARK: Countdown

@Observable
final class CountdownModel { var value = 0 }

struct CountdownView: View {
    let model: CountdownModel

    var body: some View {
        Text("\(model.value)")
            .font(.system(size: 120, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 220, height: 220)
            .background(.black.opacity(0.7), in: Circle())
            .contentTransition(.numericText(countsDown: true))
            .animation(.easeOut(duration: 0.2), value: model.value)
    }
}

/// Big centered "3, 2, 1" before a recording starts.
final class Countdown {
    private let model = CountdownModel()
    private let panel = StudioPanel(level: OverlayLevel.toolbar)
    private var timer: Timer?

    init() {
        let host = NSHostingView(rootView: CountdownView(model: model))
        host.frame = CGRect(x: 0, y: 0, width: 220, height: 220)
        panel.contentView?.addSubview(host)
    }

    var isRunning: Bool { timer != nil }

    func run(from seconds: Int, on screen: NSScreen, completion: @escaping @MainActor () -> Void) {
        cancel()
        guard seconds > 0 else { completion(); return }
        model.value = seconds
        let f = screen.frame
        panel.setFrame(CGRect(x: f.midX - 110, y: f.midY - 110, width: 220, height: 220), display: false)
        panel.orderFrontRegardless()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.model.value -= 1
                if self.model.value <= 0 {
                    self.cancel()
                    // Let the countdown disappear from the screen before capture starts.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { completion() }
                }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func cancel() {
        timer?.invalidate(); timer = nil
        panel.orderOut(nil)
    }
}

// MARK: Camera bubble

/// Webcam preview in a floating bubble that can be dragged anywhere.
final class CameraBubble {
    var onError: ((String) -> Void)?

    private let panel = StudioPanel(level: OverlayLevel.toolbar, clickThrough: false)
    private var session: AVCaptureSession?
    private var preview: AVCaptureVideoPreviewLayer?
    private var settings = CameraSettings()
    private let sessionQueue = DispatchQueue(label: "dev.local.mickey.camera")

    init() {
        panel.isMovableByWindowBackground = true
        panel.hasShadow = true
        panel.rootLayer.masksToBounds = true
    }

    func apply(_ s: CameraSettings) {
        let old = settings
        settings = s
        guard s.enabled else { stop(); return }
        if session == nil && !start() { return }
        let side = s.size
        panel.rootLayer.cornerRadius = s.shape == .circle ? side / 2 : 28
        panel.rootLayer.borderWidth = 3
        panel.rootLayer.borderColor = s.borderColor.cgColor
        preview?.frame = CGRect(x: 0, y: 0, width: side, height: side)
        if let connection = preview?.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = s.mirrored
        }
        // Keep a dragged bubble where it is unless the size or corner changed.
        if !panel.isVisible || old.corner != s.corner || old.size != s.size {
            place(size: side, corner: s.corner)
        }
        panel.orderFrontRegardless()
    }

    private func place(size: Double, corner: ScreenCorner) {
        guard let screen = NSScreen.containing(NSEvent.mouseLocation) else { return }
        let v = screen.visibleFrame, m = 32.0
        let x = corner == .bottomLeft || corner == .topLeft ? v.minX + m : v.maxX - size - m
        let y = corner == .bottomLeft || corner == .bottomRight ? v.minY + m : v.maxY - size - m
        panel.setFrame(CGRect(x: x, y: y, width: size, height: size), display: true)
    }

    private func start() -> Bool {
        guard Permissions.status(.camera) == .granted else {
            onError?("Camera access is needed for the bubble.")
            return false
        }
        guard let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device) else {
            onError?("No camera was found.")
            return false
        }
        let session = AVCaptureSession()
        session.sessionPreset = .high
        guard session.canAddInput(input) else { onError?("The camera is in use by another app."); return false }
        session.addInput(input)
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        panel.rootLayer.addSublayer(preview)
        self.session = session
        self.preview = preview
        nonisolated(unsafe) let running = session
        sessionQueue.async { running.startRunning() }
        return true
    }

    private func stop() {
        panel.orderOut(nil)
        preview?.removeFromSuperlayer()
        preview = nil
        if let session {
            nonisolated(unsafe) let stopping = session
            sessionQueue.async { stopping.stopRunning() }
        }
        session = nil
    }
}
