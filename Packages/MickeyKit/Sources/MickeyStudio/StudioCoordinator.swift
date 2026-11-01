import AppKit
import MickeyDomain
import MickeySystem

/// Drives the presenter tools from settings: keystrokes, live zoom, loupe, focus, camera, captions, recorder.
public final class StudioCoordinator {
    /// (recording, start date)
    public var onRecordingChanged: ((Bool, Date?) -> Void)?
    public var onRecordingSaved: ((URL) -> Void)?
    /// A problem worth showing to the user, or nil to clear it.
    public var onMessage: ((String?) -> Void)?

    private let keystrokes = KeystrokeHUD()
    private let magnifier = Magnifier()
    private let focus = FocusOverlay()
    private let camera = CameraBubble()
    private let captions = Captions()
    private let recorder = ScreenRecorder()
    private let countdown = Countdown()

    public init() {
        keystrokes.onPermissionMissing = { [weak self] in
            self?.onMessage?("Keystrokes need Input Monitoring: allow Mickey in System Settings › Privacy & Security.")
        }
        magnifier.onError = { [weak self] in self?.onMessage?($0) }
        camera.onError = { [weak self] in self?.onMessage?($0) }
        captions.onError = { [weak self] in self?.onMessage?($0) }
        recorder.onStarted = { [weak self] in self?.onRecordingChanged?(true, Date()) }
        recorder.onFinished = { [weak self] url, error in
            guard let self else { return }
            onRecordingChanged?(false, nil)
            if let url { onRecordingSaved?(url) }
            if let error { onMessage?("Recording: \(error)") }
        }
    }

    public static var recordingsFolder: URL { ScreenRecorder.folder }

    public var isRecording: Bool { recorder.isRecording || countdown.isRunning }

    public func apply(_ s: Settings, old: Settings?) {
        if old?.keystrokes != s.keystrokes { keystrokes.apply(s.keystrokes) }
        if old?.zoom != s.zoom || old?.loupe != s.loupe { magnifier.apply(zoom: s.zoom, loupe: s.loupe) }
        if old?.focus != s.focus { focus.apply(s.focus) }
        if old?.camera != s.camera { camera.apply(s.camera) }
        if old?.captions != s.captions { captions.apply(s.captions) }
    }

    /// Per-frame update with the pointer position.
    public func tick(pointer: CGPoint) {
        if magnifier.isActive { magnifier.update(pointer: pointer) }
    }

    public func screensChanged() {
        focus.screensChanged()
        magnifier.retry()
    }

    /// Retries tools that were waiting for a permission.
    public func permissionsChanged() {
        magnifier.retry()
        keystrokes.retry()
        captions.retry()
    }

    /// Stops a countdown or a recording; `completion` runs once the movie file is complete.
    public func stopRecording(completion: @escaping () -> Void) {
        if countdown.isRunning { countdown.cancel() }
        recorder.stop(completion: completion)
    }

    public func toggleRecording(settings: RecorderSettings) {
        if countdown.isRunning { countdown.cancel(); return }
        if recorder.isRecording { recorder.stop(); return }
        guard Permissions.status(.screenRecording) == .granted else {
            onMessage?("Recording needs Screen Recording access: allow Mickey in System Settings › Privacy & Security.")
            Permissions.request(.screenRecording) { _ in }
            return
        }
        guard let screen = NSScreen.containing(NSEvent.mouseLocation) else { return }
        onMessage?(nil)
        countdown.run(from: settings.countdown, on: screen) { [weak self] in
            self?.recorder.start(on: screen, settings: settings)
        }
    }
}
