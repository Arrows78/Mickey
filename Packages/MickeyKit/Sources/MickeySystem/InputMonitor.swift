import AppKit
import CoreGraphics
import MickeyDomain

/// Samples pointer position and modifier state at a fixed rate and forwards global mouse events.
///
/// Uses polling (`NSEvent.mouseLocation`, `CGEventSource.flagsState`) and global mouse monitors,
/// none of which require Accessibility or Input Monitoring permission.
public final class InputMonitor {
    public var onTick: ((InputSnapshot) -> Void)?
    public var onMouseDown: ((CGPoint) -> Void)?
    public var onScroll: (() -> Void)?

    private var timer: Timer?
    private var monitors: [Any] = []
    private let startUptime = ProcessInfo.processInfo.systemUptime

    public init() {}

    public var rateHz: Double = 60 {
        didSet { if timer != nil && oldValue != rateHz { restartTimer() } }
    }

    public func start() {
        guard timer == nil else { return }
        restartTimer()
        let mouseMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        if let m = NSEvent.addGlobalMonitorForEvents(matching: mouseMask, handler: { [weak self] _ in
            self?.onMouseDown?(NSEvent.mouseLocation)
        }) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: mouseMask, handler: { [weak self] e in
            self?.onMouseDown?(NSEvent.mouseLocation); return e
        }) { monitors.append(m) }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel, handler: { [weak self] _ in
            self?.onScroll?()
        }) { monitors.append(m) }
    }

    public func stop() {
        timer?.invalidate(); timer = nil
        monitors.forEach(NSEvent.removeMonitor); monitors.removeAll()
    }

    public var now: TimeInterval { ProcessInfo.processInfo.systemUptime - startUptime }

    private func restartTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 1.0 / max(rateHz, 1), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func sample() {
        let flags = CGEventSource.flagsState(.combinedSessionState).rawValue
        // Only probe the keyboard while a modifier is held: that is when combinations matter.
        let other = flags & 0x00FF_0000 != 0 ? Self.anyNonModifierKeyDown() : false
        onTick?(InputSnapshot(position: NSEvent.mouseLocation, flags: flags, otherKeyDown: other, time: now))
    }

    private static let nonModifierKeyCodes: [CGKeyCode] = (0..<128).map(CGKeyCode.init).filter { !(54...63).contains($0) }

    static func anyNonModifierKeyDown() -> Bool {
        nonModifierKeyCodes.contains { CGEventSource.keyState(.combinedSessionState, key: $0) }
    }
}
