import Foundation

public enum SpotlightShape: String, CaseIterable, Codable, Sendable {
    case circle, horizontalBar, verticalBar

    public var title: String {
        switch self {
        case .circle: "Circle"
        case .horizontalBar: "Horizontal Bar"
        case .verticalBar: "Vertical Bar"
        }
    }
}

/// Modifier keys usable alone as a hold or tap trigger.
public enum TriggerKey: String, CaseIterable, Codable, Sendable {
    case leftControl, rightCommand, rightOption, rightShift, rightControl

    public var title: String {
        switch self {
        case .leftControl: "Left Control (⌃)"
        case .rightCommand: "Right Command (⌘)"
        case .rightOption: "Right Option (⌥)"
        case .rightShift: "Right Shift (⇧)"
        case .rightControl: "Right Control (⌃)"
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

    /// Caveat shown next to the picker, if any.
    public var caveat: String? {
        switch self {
        case .leftControl: "Also used for Control-click and Mission Control. Increase the delay if it triggers by accident."
        case .rightShift: "Repeated or long Shift presses can trigger Sticky Keys or Slow Keys when enabled in Accessibility."
        case .rightControl: "Most Apple keyboards have no Right Control key."
        case .rightCommand, .rightOption: nil
        }
    }
}

/// Shake-to-locate animation.
public enum LocatorStyle: String, CaseIterable, Codable, Sendable {
    case enlargedPointer, ring

    public var title: String {
        switch self {
        case .enlargedPointer: "Enlarged Pointer"
        case .ring: "Shrinking Ring"
        }
    }
}

public enum ClickEffectType: String, CaseIterable, Codable, Sendable {
    case singleRing, ripple, ringBurst, colorFlash, particleBurst, glowPulse, scaleBounce

    public var title: String {
        switch self {
        case .singleRing: "Single Ring"
        case .ripple: "Ripple"
        case .ringBurst: "Ring Burst"
        case .colorFlash: "Color Flash"
        case .particleBurst: "Particle Burst"
        case .glowPulse: "Glow Pulse"
        case .scaleBounce: "Scale Bounce"
        }
    }
}

public enum TrailStyle: String, CaseIterable, Codable, Sendable {
    case solid, dots, dashed, particles, glow, stars, image

    public var title: String {
        switch self {
        case .solid: "Solid"
        case .dots: "Dots"
        case .dashed: "Dashed"
        case .particles: "Particles"
        case .glow: "Glow"
        case .stars: "Stars"
        case .image: "Hearts"
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
        case .freehand: "Freehand"
        case .arrow: "Arrow"
        case .rectangle: "Rectangle"
        case .circle: "Circle"
        case .line: "Line"
        case .highlighter: "Highlighter"
        case .text: "Text"
        case .callout: "Callout"
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
        case .effects: "Cursor Effects"
        case .annotations: "Annotations"
        case .keystrokes: "Keystrokes"
        case .zoom: "Live Zoom"
        case .loupe: "Loupe"
        case .focus: "Focus"
        case .recorder: "Recorder & Camera"
        case .captions: "Captions"
        case .hotkeys: "Hotkeys"
        case .general: "General"
        case .advanced: "Advanced"
        case .help: "Help"
        case .support: "Support"
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
         toggleKeystrokes, toggleLiveZoom, toggleLoupe, toggleFocus, toggleCameraBubble, toggleCaptions, toggleRecording

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .toggleMaster: "Toggle Mickey"
        case .toggleSpotlight: "Toggle Spotlight"
        case .toggleRing: "Toggle Ring"
        case .toggleTrail: "Toggle Trail"
        case .toggleClickFeedback: "Toggle Click Feedback"
        case .toggleClickSound: "Toggle Click Sounds"
        case .showClickEffect: "Show Click Effect"
        case .toggleShakeToLocate: "Toggle Shake to Locate"
        case .toggleAnnotationMode: "Toggle Annotation Mode"
        case .toggleKeystrokes: "Toggle Keystrokes"
        case .toggleLiveZoom: "Toggle Live Zoom"
        case .toggleLoupe: "Toggle Loupe"
        case .toggleFocus: "Toggle Focus"
        case .toggleCameraBubble: "Toggle Camera Bubble"
        case .toggleCaptions: "Toggle Captions"
        case .toggleRecording: "Start / Stop Recording"
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
        }
    }

    /// Virtual key codes of the default letters on a US (ANSI) keyboard.
    static let usKeyCodes: [Character: UInt32] = [
        "M": 46, "S": 1, "R": 15, "T": 17, "C": 8, "K": 40, "F": 3, "L": 37,
        "D": 2, "Y": 16, "Z": 6, "O": 31, "W": 13, "E": 14, "A": 0, "V": 9,
    ]

    /// Settings schema version that introduced the action, so migrations add only new defaults.
    public var introducedInSchema: Int {
        switch self {
        case .toggleKeystrokes, .toggleLiveZoom, .toggleLoupe, .toggleFocus, .toggleCameraBubble, .toggleCaptions, .toggleRecording: 3
        default: 2
        }
    }

    public static var defaultHotkeys: [HotkeyAction: KeyCombo] { defaultHotkeys(keyCode: { _ in nil }) }

    public static func defaultHotkeys(keyCode: (Character) -> UInt32?) -> [HotkeyAction: KeyCombo] {
        Dictionary(uniqueKeysWithValues: allCases.map { ($0, $0.defaultHotkey(keyCode: keyCode)) })
    }

    public var detail: String {
        switch self {
        case .toggleMaster: "Turn every effect on or off"
        case .toggleSpotlight: "Dim the screen around the pointer"
        case .toggleRing: "Ring that follows the pointer"
        case .toggleTrail: "Trail behind the pointer"
        case .toggleClickFeedback: "Visual effect on clicks"
        case .toggleClickSound: "Audible click"
        case .showClickEffect: "Flash the click effect at the pointer"
        case .toggleShakeToLocate: "Shake the mouse to find the pointer"
        case .toggleAnnotationMode: "Enter or leave drawing mode"
        case .toggleKeystrokes: "Show typed shortcuts on screen"
        case .toggleLiveZoom: "Magnify the whole screen around the pointer"
        case .toggleLoupe: "Magnifying glass that follows the pointer"
        case .toggleFocus: "Dim everything but the front window"
        case .toggleCameraBubble: "Floating webcam bubble"
        case .toggleCaptions: "Live subtitles from the microphone"
        case .toggleRecording: "Record the screen to a movie"
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
        case .spotlight: "Spotlight"
        case .ring: "Ring"
        case .clickFeedback: "Click Feedback"
        case .clickSound: "Click Sounds"
        case .trail: "Trail"
        case .shake: "Shake to Locate"
        case .annotations: "Annotations"
        case .keystrokes: "Keystrokes"
        case .liveZoom: "Live Zoom"
        case .loupe: "Loupe"
        case .focus: "Focus"
        case .cameraBubble: "Camera Bubble"
        case .captions: "Captions"
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
