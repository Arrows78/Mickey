import Foundation

public enum SpotlightShape: String, CaseIterable, Codable, Sendable {
    case circle, horizontalBar, verticalBar

    public var title: String {
        switch self {
        case .circle: tr("Circle")
        case .horizontalBar: tr("Horizontal Bar")
        case .verticalBar: tr("Vertical Bar")
        }
    }
}

/// Modifier keys usable alone as a hold or tap trigger.
public enum TriggerKey: String, CaseIterable, Codable, Sendable {
    case leftControl, rightCommand, rightOption, rightShift, rightControl

    public var title: String {
        switch self {
        case .leftControl: tr("Left Control (⌃)")
        case .rightCommand: tr("Right Command (⌘)")
        case .rightOption: tr("Right Option (⌥)")
        case .rightShift: tr("Right Shift (⇧)")
        case .rightControl: tr("Right Control (⌃)")
        }
    }

    /// Device-dependent bit in CGEventFlags (IOKit NX_DEVICE*KEYMASK).
    public var deviceFlagMask: UInt64 {
        switch self {
        case .leftControl: 0x0000_0001
        case .rightShift: 0x0000_0004
        case .rightCommand: 0x0000_0010
        case .rightOption: 0x0000_0040
        case .rightControl: 0x0000_2000
        }
    }

    /// Device-independent bit of the same modifier (control, shift, command or option).
    public var genericFlagMask: UInt64 {
        switch self {
        case .leftControl, .rightControl: 0x0004_0000
        case .rightShift: 0x0002_0000
        case .rightCommand: 0x0010_0000
        case .rightOption: 0x0008_0000
        }
    }

    /// Caveat shown next to the picker, if any.
    public var caveat: String? {
        switch self {
        case .leftControl: tr("Also used for Control-click and Mission Control. Increase the delay if it triggers by accident.")
        case .rightShift: tr("Repeated or long Shift presses can trigger Sticky Keys or Slow Keys when enabled in Accessibility.")
        case .rightControl: tr("Most Apple keyboards have no Right Control key.")
        case .rightCommand, .rightOption: nil
        }
    }
}

/// Shake-to-locate animation.
public enum LocatorStyle: String, CaseIterable, Codable, Sendable {
    case enlargedPointer, ring

    public var title: String {
        switch self {
        case .enlargedPointer: tr("Enlarged Pointer")
        case .ring: tr("Shrinking Ring")
        }
    }
}

public enum ClickEffectType: String, CaseIterable, Codable, Sendable {
    case singleRing, ripple, ringBurst, colorFlash, particleBurst, glowPulse, scaleBounce

    public var title: String {
        switch self {
        case .singleRing: tr("Single Ring")
        case .ripple: tr("Ripple")
        case .ringBurst: tr("Ring Burst")
        case .colorFlash: tr("Color Flash")
        case .particleBurst: tr("Particle Burst")
        case .glowPulse: tr("Glow Pulse")
        case .scaleBounce: tr("Scale Bounce")
        }
    }
}

public enum TrailStyle: String, CaseIterable, Codable, Sendable {
    case solid, dots, dashed, particles, glow, stars, image

    public var title: String {
        switch self {
        case .solid: tr("Solid")
        case .dots: tr("Dots")
        case .dashed: tr("Dashed")
        case .particles: tr("Particles")
        case .glow: tr("Glow")
        case .stars: tr("Stars")
        case .image: tr("Hearts")
        }
    }

    /// Styles drawn as discrete items (spawn rate applies) rather than a continuous line.
    public var isDiscrete: Bool {
        switch self {
        case .solid, .dashed, .glow: false
        case .dots, .particles, .stars, .image: true
        }
    }
}

public enum AnnotationTool: String, CaseIterable, Codable, Sendable {
    case freehand, arrow, rectangle, circle, line, highlighter, text, callout

    public var title: String {
        switch self {
        case .freehand: tr("Freehand")
        case .arrow: tr("Arrow")
        case .rectangle: tr("Rectangle")
        case .circle: tr("Circle")
        case .line: tr("Line")
        case .highlighter: tr("Highlighter")
        case .text: tr("Text")
        case .callout: tr("Callout")
        }
    }

    public var symbolName: String {
        switch self {
        case .freehand: "scribble"
        case .arrow: "arrow.up.right"
        case .rectangle: "rectangle"
        case .circle: "circle"
        case .line: "line.diagonal"
        case .highlighter: "highlighter"
        case .text: "textformat"
        case .callout: "1.circle.fill"
        }
    }

    /// Single-letter shortcut available while drawing.
    public var shortcutKey: Character? {
        switch self {
        case .freehand: "f"
        case .arrow: "a"
        case .rectangle: "r"
        case .circle: "c"
        case .line: "l"
        case .highlighter: "h"
        case .text: "t"
        case .callout: "n"
        }
    }

    public static func forShortcut(_ key: Character) -> AnnotationTool? {
        allCases.first { $0.shortcutKey == Character(key.lowercased()) }
    }

    /// Shapes defined by two points (start, end) rather than a free path.
    public var isTwoPoint: Bool {
        switch self {
        case .arrow, .rectangle, .circle, .line: true
        case .freehand, .highlighter, .text, .callout: false
        }
    }
}

public enum SettingsSection: String, CaseIterable, Codable, Sendable, Identifiable {
    case effects, annotations, keystrokes, zoom, loupe, focus, recorder, captions, hotkeys, general, advanced, help, support

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .effects: tr("Cursor Effects")
        case .annotations: tr("Annotations")
        case .keystrokes: tr("Keystrokes")
        case .zoom: tr("Live Zoom")
        case .loupe: tr("Loupe")
        case .focus: tr("Focus")
        case .recorder: tr("Recorder & Camera")
        case .captions: tr("Captions")
        case .hotkeys: tr("Hotkeys")
        case .general: tr("General")
        case .advanced: tr("Advanced")
        case .help: tr("Help")
        case .support: tr("Support")
        }
    }

    public var symbolName: String {
        switch self {
        case .effects: "cursorarrow.rays"
        case .annotations: "pencil.tip.crop.circle"
        case .keystrokes: "command.square"
        case .zoom: "plus.magnifyingglass"
        case .loupe: "magnifyingglass.circle"
        case .focus: "macwindow.on.rectangle"
        case .recorder: "record.circle"
        case .captions: "captions.bubble"
        case .hotkeys: "keyboard.badge.ellipsis"
        case .general: "gearshape"
        case .advanced: "slider.horizontal.3"
        case .help: "questionmark.circle"
        case .support: "bubble.left.and.bubble.right"
        }
    }
}

public enum HotkeyAction: String, CaseIterable, Codable, CodingKeyRepresentable, Sendable, Identifiable {
    case toggleMaster, toggleSpotlight, toggleRing, toggleTrail, toggleClickFeedback,
         toggleClickSound, showClickEffect, toggleShakeToLocate, toggleAnnotationMode,
         toggleKeystrokes, toggleLiveZoom, toggleLoupe, toggleFocus, toggleCameraBubble, toggleCaptions, toggleRecording,
         togglePauseRecording

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .toggleMaster: tr("Toggle Mickey")
        case .toggleSpotlight: tr("Toggle Spotlight")
        case .toggleRing: tr("Toggle Ring")
        case .toggleTrail: tr("Toggle Trail")
        case .toggleClickFeedback: tr("Toggle Click Feedback")
        case .toggleClickSound: tr("Toggle Click Sounds")
        case .showClickEffect: tr("Show Click Effect")
        case .toggleShakeToLocate: tr("Toggle Shake to Locate")
        case .toggleAnnotationMode: tr("Toggle Annotation Mode")
        case .toggleKeystrokes: tr("Toggle Keystrokes")
        case .toggleLiveZoom: tr("Toggle Live Zoom")
        case .toggleLoupe: tr("Toggle Loupe")
        case .toggleFocus: tr("Toggle Focus")
        case .toggleCameraBubble: tr("Toggle Camera Bubble")
        case .toggleCaptions: tr("Toggle Captions")
        case .toggleRecording: tr("Start / Stop Recording")
        case .togglePauseRecording: tr("Pause / Resume Recording")
        }
    }

    /// Default shortcut: ⌃⌥⌘ plus a mnemonic letter. The triple modifier is left free by macOS
    /// and by most apps, so the defaults rarely collide with anything.
    /// This is the US-layout key; `defaultHotkey(keyCode:)` follows the user's layout.
    public var defaultHotkey: KeyCombo { defaultHotkey(keyCode: { _ in nil }) }

    /// Default shortcut on the key printing `defaultLetter` in the current layout, as reported by `keyCode`,
    /// falling back to the US-layout key.
    public func defaultHotkey(keyCode: (Character) -> UInt32?) -> KeyCombo {
        let letter = defaultLetter
        let code = keyCode(Character(letter.lowercased())) ?? Self.usKeyCodes[letter] ?? 0
        return KeyCombo(keyCode: code, modifiers: [.control, .option, .command], keyLabel: String(letter))
    }

    /// Mnemonic letter of the default shortcut.
    public var defaultLetter: Character {
        switch self {
        case .toggleMaster: "M"
        case .toggleSpotlight: "S"
        case .toggleRing: "R"
        case .toggleTrail: "T"
        case .toggleClickFeedback: "C"
        case .toggleClickSound: "K"
        case .showClickEffect: "F"
        case .toggleShakeToLocate: "L"
        case .toggleAnnotationMode: "D"
        case .toggleKeystrokes: "Y"
        case .toggleLiveZoom: "Z"
        case .toggleLoupe: "O"
        case .toggleFocus: "W"
        case .toggleCameraBubble: "E"
        case .toggleCaptions: "A"
        case .toggleRecording: "V"
        case .togglePauseRecording: "P"
        }
    }

    /// Virtual key codes of the default letters on a US (ANSI) keyboard.
    static let usKeyCodes: [Character: UInt32] = [
        "M": 46, "S": 1, "R": 15, "T": 17, "C": 8, "K": 40, "F": 3, "L": 37,
        "D": 2, "Y": 16, "Z": 6, "O": 31, "W": 13, "E": 14, "A": 0, "V": 9, "P": 35,
    ]

    /// Settings schema version that introduced the action, so migrations add only new defaults.
    public var introducedInSchema: Int {
        switch self {
        case .toggleKeystrokes, .toggleLiveZoom, .toggleLoupe, .toggleFocus, .toggleCameraBubble, .toggleCaptions, .toggleRecording: 3
        case .togglePauseRecording: 5
        default: 2
        }
    }

    public static var defaultHotkeys: [HotkeyAction: KeyCombo] { defaultHotkeys(keyCode: { _ in nil }) }

    public static func defaultHotkeys(keyCode: (Character) -> UInt32?) -> [HotkeyAction: KeyCombo] {
        Dictionary(uniqueKeysWithValues: allCases.map { ($0, $0.defaultHotkey(keyCode: keyCode)) })
    }

    public var detail: String {
        switch self {
        case .toggleMaster: tr("Turn every effect on or off")
        case .toggleSpotlight: tr("Dim the screen around the pointer")
        case .toggleRing: tr("Ring that follows the pointer")
        case .toggleTrail: tr("Trail behind the pointer")
        case .toggleClickFeedback: tr("Visual effect on clicks")
        case .toggleClickSound: tr("Audible click")
        case .showClickEffect: tr("Flash the click effect at the pointer")
        case .toggleShakeToLocate: tr("Shake the mouse to find the pointer")
        case .toggleAnnotationMode: tr("Enter or leave drawing mode")
        case .toggleKeystrokes: tr("Show typed shortcuts on screen")
        case .toggleLiveZoom: tr("Magnify the whole screen around the pointer")
        case .toggleLoupe: tr("Magnifying glass that follows the pointer")
        case .toggleFocus: tr("Dim everything but the front window")
        case .toggleCameraBubble: tr("Floating webcam bubble")
        case .toggleCaptions: tr("Live subtitles from the microphone")
        case .toggleRecording: tr("Record the screen to a movie")
        case .togglePauseRecording: tr("Stop adding to the movie, then carry on")
        }
    }
}

/// Quick toggles that can appear in the menu-bar popover.
public enum MenuBarItem: String, CaseIterable, Codable, Sendable, Identifiable {
    case spotlight, ring, clickFeedback, clickSound, trail, shake, annotations,
         keystrokes, liveZoom, loupe, focus, cameraBubble, captions

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .spotlight: tr("Spotlight")
        case .ring: tr("Ring")
        case .clickFeedback: tr("Click Feedback")
        case .clickSound: tr("Click Sounds")
        case .trail: tr("Trail")
        case .shake: tr("Shake to Locate")
        case .annotations: tr("Annotations")
        case .keystrokes: tr("Keystrokes")
        case .liveZoom: tr("Live Zoom")
        case .loupe: tr("Loupe")
        case .focus: tr("Focus")
        case .cameraBubble: tr("Camera Bubble")
        case .captions: tr("Captions")
        }
    }

    /// Hotkey toggling the same setting. Annotations has none: its hotkey starts drawing rather than
    /// switching the feature on or off.
    public var hotkeyAction: HotkeyAction? {
        switch self {
        case .spotlight: .toggleSpotlight
        case .ring: .toggleRing
        case .clickFeedback: .toggleClickFeedback
        case .clickSound: .toggleClickSound
        case .trail: .toggleTrail
        case .shake: .toggleShakeToLocate
        case .annotations: nil
        case .keystrokes: .toggleKeystrokes
        case .liveZoom: .toggleLiveZoom
        case .loupe: .toggleLoupe
        case .focus: .toggleFocus
        case .cameraBubble: .toggleCameraBubble
        case .captions: .toggleCaptions
        }
    }
}

public enum LoginItemState: Equatable, Sendable {
    case enabled, disabled, requiresApproval, failed(String)
}
