import CoreGraphics
import Foundation

/// Snapshot of global input, sampled at the update rate.
public struct InputSnapshot: Sendable {
    public var position: CGPoint
    /// Raw CGEventFlags, including device-dependent left/right bits.
    public var flags: UInt64
    /// A non-modifier key is currently down (best effort; may be unavailable without permission).
    public var otherKeyDown: Bool
    public var time: TimeInterval

    public init(position: CGPoint, flags: UInt64, otherKeyDown: Bool = false, time: TimeInterval) {
        self.position = position; self.flags = flags; self.otherKeyDown = otherKeyDown; self.time = time
    }

    public static let secondaryFnMask: UInt64 = 0x0080_0000
    /// Device-independent modifier bits (shift, control, option, command).
    static let modifierMask: UInt64 = 0x0002_0000 | 0x0004_0000 | 0x0008_0000 | 0x0010_0000

    public func isDown(_ key: TriggerKey) -> Bool { flags & key.deviceFlagMask != 0 }

    /// Left/right bits of control, shift, command and option.
    static let deviceModifierMask: UInt64 = 0x0000_207F

    /// True when `key` is the only modifier held (either side of any other modifier counts) and no other key was pressed.
    func isAlone(_ key: TriggerKey) -> Bool {
        isDown(key)
            && flags & Self.deviceModifierMask & ~key.deviceFlagMask == 0
            && flags & Self.modifierMask & ~key.genericFlagMask == 0
            && !otherKeyDown
    }
}

/// Keeps the secondary-Fn flag only for a real Fn (🌐) press.
///
/// macOS also sets that flag while an arrow, Home/End, Page Up/Down or F-key is down. A real Fn press is a
/// modifier change, while those keys are key-downs: the event that raised the flag tells them apart.
public struct FnKeyFilter: Sendable {
    private var wasDown = false
    private var ignoring = false

    public init() {}

    /// Arrow keys also raise the numeric-pad flag; the Fn (🌐) key never does.
    static let numericPadMask: UInt64 = 0x0020_0000

    /// Longest age of the last modifier change for it to be the Fn press itself rather than an earlier ⌃ or ⇧.
    static let freshChange: TimeInterval = 0.08

    /// `keyDownIsLatest`: the most recent keyboard event is a key-down rather than a modifier change.
    /// `modifierChangeAge`: seconds since that modifier change. A system shortcut such as ⌃← can swallow the
    /// key-down, leaving an older ⌃ change as the latest event; an Fn press always has a fresh one.
    public mutating func filter(_ flags: UInt64, keyDownIsLatest: Bool, modifierChangeAge: TimeInterval = 0) -> UInt64 {
        let down = flags & InputSnapshot.secondaryFnMask != 0
        if down && !wasDown {
            ignoring = keyDownIsLatest || flags & Self.numericPadMask != 0 || modifierChangeAge > Self.freshChange
        }
        if !down { ignoring = false }
        wasDown = down
        return ignoring ? flags & ~InputSnapshot.secondaryFnMask : flags
    }
}

public enum InteractionCommand: Equatable, Sendable {
    case clickEffect(CGPoint)
    case clickSound
    case locate(CGPoint)
    case disableSpotlight
}

/// Turns raw input into effect commands, applying every trigger rule from the product spec.
public struct InteractionEngine: Sendable {
    public private(set) var spotlightHeld = false
    public private(set) var lastPosition: CGPoint = .zero

    private var spotlightHold = HoldRecognizer(delay: 0.5)
    private var tap = TapRecognizer()
    private var shake = ShakeDetector(sensitivity: 0.95)
    private var dismiss = SpotlightDismissTracker()
    private var spotlightWasEnabled = false
    private var tapKeyWasDown = false

    public init() {}

    /// Whether the spotlight should currently be drawn.
    public func spotlightVisible(_ s: Settings) -> Bool {
        guard s.general.masterEnabled, s.spotlight.enabled else { return false }
        return s.spotlight.holdKey == nil || spotlightHeld
    }

    public func shouldHideCursor(_ s: Settings) -> Bool { spotlightVisible(s) && s.spotlight.hideCursor }

    public mutating func tick(_ input: InputSnapshot, settings s: Settings) -> [InteractionCommand] {
        var out: [InteractionCommand] = []
        let t = input.time
        lastPosition = input.position
        let effectsOn = s.general.masterEnabled

        // Spotlight "hold a key to show".
        if let key = s.spotlight.holdKey {
            spotlightHold.delay = s.spotlight.holdDelay
            let down = input.isAlone(key) || (spotlightHold.isActive && input.isDown(key))
            switch spotlightHold.update(isDown: down, at: t) {
            case .began: spotlightHeld = true
            case .ended: spotlightHeld = false
            case nil: break
            }
        } else {
            spotlightHeld = false
            _ = spotlightHold.update(isDown: false, at: t)
        }

        // Spotlight "turn off when moving": arm when the spotlight is switched on.
        let spotlightEnabled = effectsOn && s.spotlight.enabled
        if spotlightEnabled && !spotlightWasEnabled && s.spotlight.dismissOnMove {
            dismiss.arm(at: input.position, time: t)
        }
        if !spotlightEnabled || !s.spotlight.dismissOnMove { dismiss.disarm() }
        spotlightWasEnabled = spotlightEnabled
        if dismiss.shouldDismiss(position: input.position, time: t, distance: s.spotlight.dismissDistance) {
            out.append(.disableSpotlight)
        }

        // Click effect on a lone tap of the tap key.
        if let key = s.click.tapKey {
            let down = input.isDown(key)
            if down && !tapKeyWasDown {
                if input.isAlone(key) { tap.keyDown(at: t) }
            } else if down && tap.isDown && !input.isAlone(key) {
                tap.otherInput()
            } else if !down && tapKeyWasDown {
                // A hold that revealed the spotlight is not a tap.
                if spotlightHeld || spotlightHold.isActive { tap.otherInput() }
                if tap.keyUp(at: t) && effectsOn && s.click.feedbackEnabled {
                    out.append(.clickEffect(input.position))
                }
            }
            tapKeyWasDown = down
        } else {
            tapKeyWasDown = false
        }

        // Shake to locate.
        if effectsOn && s.shake.enabled {
            shake.sensitivity = s.shake.sensitivity
            if shake.add(PointerSample(input.position, at: t)) { out.append(.locate(input.position)) }
        }
        return out
    }

    public mutating func mouseDown(at position: CGPoint, settings s: Settings) -> [InteractionCommand] {
        tap.otherInput()
        spotlightHold.cancelPending()
        guard s.general.masterEnabled else { return [] }
        var out: [InteractionCommand] = []
        if s.click.feedbackEnabled && s.click.showOnClicks { out.append(.clickEffect(position)) }
        if s.click.soundEnabled { out.append(.clickSound) }
        return out
    }

    public mutating func scrolled() {
        tap.otherInput()
        spotlightHold.cancelPending()
    }

    /// Hotkey "Show click effect".
    public func showClickEffect(settings s: Settings) -> [InteractionCommand] {
        s.general.masterEnabled ? [.clickEffect(lastPosition)] : []
    }
}
