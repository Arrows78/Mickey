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
    case effects, annotations, hotkeys, general, advanced, help, support

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .effects: "Cursor Effects"
        case .annotations: "Annotations"
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
        case .hotkeys: "keyboard"
        case .general: "gearshape"
        case .advanced: "slider.horizontal.3"
        case .help: "questionmark.circle"
        case .support: "bubble.left.and.bubble.right"
        }
    }
}

public enum HotkeyAction: String, CaseIterable, Codable, CodingKeyRepresentable, Sendable, Identifiable {
    case toggleMaster, toggleSpotlight, toggleRing, toggleTrail, toggleClickFeedback,
         toggleClickSound, showClickEffect, toggleShakeToLocate, toggleAnnotationMode

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
        }
    }

    /// Default shortcut: ⌃⌥⌘ plus a mnemonic letter. The triple modifier is left free by macOS
    /// and by most apps, so the defaults rarely collide with anything.
    public var defaultHotkey: KeyCombo {
        let (code, label): (UInt32, String) = switch self {
        case .toggleMaster: (46, "M")
        case .toggleSpotlight: (1, "S")
        case .toggleRing: (15, "R")
        case .toggleTrail: (17, "T")
        case .toggleClickFeedback: (8, "C")
        case .toggleClickSound: (40, "K")
        case .showClickEffect: (3, "F")
        case .toggleShakeToLocate: (37, "L")
        case .toggleAnnotationMode: (2, "D")
        }
        return KeyCombo(keyCode: code, modifiers: [.control, .option, .command], keyLabel: label)
    }

    public static var defaultHotkeys: [HotkeyAction: KeyCombo] {
        Dictionary(uniqueKeysWithValues: allCases.map { ($0, $0.defaultHotkey) })
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
        }
    }
}

/// Quick toggles that can appear in the menu-bar popover.
public enum MenuBarItem: String, CaseIterable, Codable, Sendable, Identifiable {
    case spotlight, ring, clickFeedback, clickSound, trail, shake, annotations

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
        }
    }
}

public enum LoginItemState: Equatable, Sendable {
    case enabled, disabled, requiresApproval, failed(String)
}
