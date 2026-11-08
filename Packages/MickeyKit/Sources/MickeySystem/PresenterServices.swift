import AppKit
import AVFoundation
import CoreGraphics
import IOKit.hid
import MickeyDomain
import Speech

/// Status, request and System Settings shortcut for each privacy permission.
public enum Permissions {
    public static func status(_ p: Permission) -> PermissionStatus {
        switch p {
        case .inputMonitoring:
            if CGPreflightListenEventAccess() { return .granted }
            return IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeUnknown ? .notDetermined : .denied
        case .screenRecording:
            // macOS does not tell "never asked" from "refused" here.
            return CGPreflightScreenCaptureAccess() ? .granted : .notDetermined
        case .camera: return status(AVCaptureDevice.authorizationStatus(for: .video))
        case .microphone: return status(AVCaptureDevice.authorizationStatus(for: .audio))
        case .speechRecognition:
            switch SFSpeechRecognizer.authorizationStatus() {
            case .authorized: return .granted
            case .notDetermined: return .notDetermined
            default: return .denied
            }
        }
    }

    private static func status(_ s: AVAuthorizationStatus) -> PermissionStatus {
        switch s {
        case .authorized: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    /// Shows the system prompt when macOS still allows it, otherwise opens the matching System Settings pane.
    public static func request(_ p: Permission, completion: @escaping @MainActor (PermissionStatus) -> Void) {
        let finish: @Sendable () -> Void = { DispatchQueue.main.async { MainActor.assumeIsolated { completion(status(p)) } } }
        if status(p) == .denied { openSettings(p); finish(); return }
        switch p {
        case .inputMonitoring:
            if !CGRequestListenEventAccess() { openSettings(p) }
            finish()
        case .screenRecording:
            if !CGRequestScreenCaptureAccess() { openSettings(p) }
            finish()
        // These answers arrive on background queues: the closures must not be main-actor isolated.
        case .camera: AVCaptureDevice.requestAccess(for: .video) { @Sendable _ in finish() }
        case .microphone: AVCaptureDevice.requestAccess(for: .audio) { @Sendable _ in finish() }
        case .speechRecognition: SFSpeechRecognizer.requestAuthorization { @Sendable _ in finish() }
        }
    }

    public static func openSettings(_ p: Permission) {
        let anchor = switch p {
        case .inputMonitoring: "Privacy_ListenEvent"
        case .screenRecording: "Privacy_ScreenCapture"
        case .camera: "Privacy_Camera"
        case .microphone: "Privacy_Microphone"
        case .speechRecognition: "Privacy_SpeechRecognition"
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") { NSWorkspace.shared.open(url) }
    }
}

/// Reports every key press system-wide through a listen-only event tap (requires Input monitoring).
public final class KeystrokeMonitor {
    /// (CGEventFlags raw value, virtual key code, characters ignoring modifiers)
    public var onKey: ((UInt64, UInt16, String) -> Void)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    public init() {}

    public var isRunning: Bool { tap != nil }

    /// Returns false when Input monitoring is not granted.
    @discardableResult
    public func start() -> Bool {
        guard tap == nil else { return true }
        guard CGPreflightListenEventAccess() else { return false }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
                                          eventsOfInterest: mask, callback: { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            // The tap's run-loop source is on the main run loop.
            MainActor.assumeIsolated {
                Unmanaged<KeystrokeMonitor>.fromOpaque(context).takeUnretainedValue().handle(type, event)
            }
            return Unmanaged.passUnretained(event)
        }, userInfo: context) else { return false }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        return true
    }

    public func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        guard type == .keyDown, event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else { return }
        let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let chars = NSEvent(cgEvent: event)?.charactersIgnoringModifiers ?? ""
        onKey?(event.flags.rawValue, code, chars)
    }
}

/// Frame of the frontmost window, read from the window server (no permission needed for bounds).
public enum FrontWindow {
    public static func rect() -> CGRect? {
        guard let front = NSWorkspace.shared.frontmostApplication,
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
              let primary = NSScreen.screens.first
        else { return nil }
        let windows = list.compactMap { w -> WindowInfo? in
            guard let pid = w[kCGWindowOwnerPID as String] as? Int32, let layer = w[kCGWindowLayer as String] as? Int,
                  let b = w[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: b) else { return nil }
            return WindowInfo(pid: pid, layer: layer, bounds: bounds, alpha: w[kCGWindowAlpha as String] as? Double ?? 1)
        }
        return FocusSelector.focusRect(windows: windows, frontmostPID: front.processIdentifier,
                                       primaryScreenHeight: primary.frame.height)
    }
}

/// Reports the bundle identifiers of running apps whenever an app launches or quits.
public final class AppWatcher {
    public var onChange: ((Set<String>) -> Void)?
    private var observers: [NSObjectProtocol] = []

    public init() {}

    public var running: Set<String> { Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)) }

    public func start() {
        guard observers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { guard let self else { return }; self.onChange?(self.running) }
            })
        }
        onChange?(running)
    }

    public func stop() {
        observers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        observers.removeAll()
    }
}
