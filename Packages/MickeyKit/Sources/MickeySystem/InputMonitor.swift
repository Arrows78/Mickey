import AppKit
import CoreGraphics
import MickeyDomain
import os

/// Samples pointer position and modifier state at a fixed rate and forwards global mouse events.
///
/// Uses polling (`NSEvent.mouseLocation`, `CGEventSource` flag state and event timing) and global mouse
/// monitors, none of which require Accessibility or Input Monitoring permission.
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
        let flags = Self.currentFlags()
        let held = flags & Self.modifierMask != 0
        if held && modifiersDownAt == nil { modifiersDownAt = ProcessInfo.processInfo.systemUptime }
        if !held { modifiersDownAt = nil }
        let other = modifiersDownAt.map(Self.keyPressed(since:)) ?? false
        logIfChanged(flags: flags, other: other)
        onTick?(InputSnapshot(position: NSEvent.mouseLocation, flags: flags, otherKeyDown: other, time: now))
    }

    // MARK: Modifier state

    /// Device-independent bits of control, shift, option, command and fn.
    private static let modifierMask: UInt64 = 0x0004_0000 | 0x0002_0000 | 0x0008_0000 | 0x0010_0000 | InputSnapshot.secondaryFnMask
    private var modifiersDownAt: TimeInterval?

    /// True when a non-modifier key was pressed after `start` (system uptime).
    ///
    /// Per-key state is unreliable for sandboxed apps, but the time since the last key-down event is
    /// always available; modifier presses are flag changes, not key-downs, so they do not count.
    static func keyPressed(since start: TimeInterval) -> Bool {
        let sinceKeyDown = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        return ProcessInfo.processInfo.systemUptime - sinceKeyDown > start
    }

    /// Device-independent modifier bit → (both device bits, side assumed when unknown).
    /// The assumed side is the one offered as a trigger: Left Control, Right Shift/Command/Option.
    private static let sides: [(generic: UInt64, both: UInt64, assumed: UInt64)] = [
        (0x0004_0000, 0x0000_2001, 0x0000_0001), // control
        (0x0002_0000, 0x0000_0006, 0x0000_0004), // shift
        (0x0010_0000, 0x0000_0018, 0x0000_0010), // command
        (0x0008_0000, 0x0000_0060, 0x0000_0040), // option
    ]

    /// Modifier flags with left/right device bits.
    ///
    /// When the system does not say which side is held, the trigger side is assumed so a trigger still works.
    static func currentFlags() -> UInt64 {
        var flags = CGEventSource.flagsState(.combinedSessionState).rawValue
        for side in sides where flags & side.generic != 0 && flags & side.both == 0 {
            flags |= side.assumed
        }
        return flags
    }

    private var lastLogged: (UInt64, Bool) = (0, false)
    private static let log = Logger(subsystem: "dev.local.mickey", category: "input")

    /// Records modifier transitions with each raw source, to diagnose trigger keys on a given Mac.
    private func logIfChanged(flags: UInt64, other: Bool) {
        let modifiers = flags & 0x00FF_FFFF
        guard modifiers != lastLogged.0 || other != lastLogged.1 else { return }
        lastLogged = (modifiers, other)
        let raw = CGEventSource.flagsState(.combinedSessionState).rawValue & 0x00FF_FFFF
        let ns = UInt64(NSEvent.modifierFlags.rawValue) & 0x00FF_FFFF
        Self.log.notice("modifiers=\(String(modifiers, radix: 16), privacy: .public) raw=\(String(raw, radix: 16), privacy: .public) ns=\(String(ns, radix: 16), privacy: .public) otherKey=\(other, privacy: .public)")
    }
}
