import AppKit
import MickeyDomain
import MickeySystem

/// Drives the presenter tools from settings: keystrokes, live zoom, loupe, focus, camera, captions, recorder.
public final class StudioCoordinator {
    /// (recording, start date)
    public var onRecordingChanged: ((Bool, Date?) -> Void)?
    /// True when the recording was paused, false when it carries on.
    public var onRecordingPauseChanged: ((Bool) -> Void)?
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
    private let regionPicker = RegionPicker()

    public init() {
        keystrokes.onPermissionMissing = { [weak self] in
            self?.onMessage?(tr("Keystrokes need Input monitoring: allow Mickey in System Settings › Privacy & Security."))
        }
        magnifier.onError = { [weak self] in self?.onMessage?($0) }
        camera.onError = { [weak self] in self?.onMessage?($0) }
        captions.onError = { [weak self] in self?.onMessage?($0) }
        recorder.onStarted = { [weak self] in self?.onRecordingChanged?(true, Date()) }
        recorder.onFinished = { [weak self] url, error in
            guard let self else { return }
            onRecordingChanged?(false, nil)
            if let url { onRecordingSaved?(url) }
            if let error { onMessage?(trf("Recording: %@", error)) }
        }
    }

    public static var recordingsFolder: URL { ScreenRecorder.folder }

    public var isRecording: Bool { recorder.isRecording || countdown.isRunning || regionPicker.isActive }
    public var isPaused: Bool { recorder.isPaused }

    /// Turning Mickey off hides every overlay.
    public func apply(_ settings: Settings, old previous: Settings?) {
        let s = SettingsRules.presenterTools(of: settings)
        let old = previous.map(SettingsRules.presenterTools(of:))
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

    /// A mouse click, for the zoom that follows clicks.
    public func registerClick() { magnifier.registerClick() }

    public func screensChanged() {
        focus.screensChanged()
        magnifier.retry()
    }

    /// Retries tools that were waiting for a permission.
    public func permissionsChanged() {
        magnifier.retry()
        keystrokes.retry()
        captions.retry()
        camera.retry()
    }

    /// Stops a countdown or a recording; `completion` runs once the movie file is complete.
    public func stopRecording(completion: @escaping () -> Void) {
        if regionPicker.isActive { regionPicker.cancel() }
        if countdown.isRunning { countdown.cancel() }
        recorder.stop(completion: completion)
    }

    /// Pauses a running recording, or resumes a paused one. Does nothing when nothing is being recorded.
    public func togglePause() {
        guard recorder.isRecording else { return }
        if recorder.isPaused { recorder.resume() } else { recorder.pause() }
        onRecordingPauseChanged?(recorder.isPaused)
    }

    public func toggleRecording(settings: RecorderSettings) {
        if regionPicker.isActive { regionPicker.cancel(); return }
        if countdown.isRunning { countdown.cancel(); return }
        if recorder.isRecording { recorder.stop(); return }
        guard Permissions.status(.screenRecording) == .granted else {
            onMessage?(tr("Recording needs Screen recording access: allow Mickey in System Settings › Privacy & Security."))
            Permissions.request(.screenRecording) { _ in }
            return
        }
        guard let screen = NSScreen.containing(NSEvent.mouseLocation) else { return }
        onMessage?(nil)
        let begin = { [weak self] (region: CGRect?) in
            self?.countdown.run(from: settings.countdown, on: screen) { [weak self] in
                self?.recorder.start(on: screen, settings: settings, region: region)
            }
        }
        if settings.area == .region {
            regionPicker.pick(on: screen) { rect in if let rect { begin(rect) } }
        } else {
            begin(nil)
        }
    }
}
