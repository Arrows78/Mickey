import Foundation

/// sRGB color with alpha, stored as plain numbers.
public struct RGBAColor: Codable, Equatable, Hashable, Sendable {
    public var red: Double, green: Double, blue: Double, alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }

    public static let white = RGBAColor(red: 1, green: 1, blue: 1)
    public static let black = RGBAColor(red: 0, green: 0, blue: 0)
    public static let blue = RGBAColor(red: 0, green: 0.48, blue: 1)
    public static let red = RGBAColor(red: 1, green: 0.23, blue: 0.19)
    public static let yellow = RGBAColor(red: 1, green: 0.8, blue: 0)
    public static let green = RGBAColor(red: 0.2, green: 0.78, blue: 0.35)
    public static let orange = RGBAColor(red: 1, green: 0.58, blue: 0)
    public static let purple = RGBAColor(red: 0.69, green: 0.32, blue: 0.87)

    public static let presets: [RGBAColor] = [.red, .orange, .yellow, .green, .blue, .purple, .white, .black]

    public func withAlpha(_ a: Double) -> RGBAColor { RGBAColor(red: red, green: green, blue: blue, alpha: a) }

    func clamped() -> RGBAColor {
        RGBAColor(red: red.clamped(to: 0...1), green: green.clamped(to: 0...1),
                  blue: blue.clamped(to: 0...1), alpha: alpha.clamped(to: 0...1))
    }
}

/// A global keyboard shortcut: virtual key code + Carbon-independent modifier mask.
public struct KeyCombo: Codable, Equatable, Hashable, Sendable {
    public struct Modifiers: OptionSet, Codable, Hashable, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let control = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let shift = Modifiers(rawValue: 1 << 2)
        public static let command = Modifiers(rawValue: 1 << 3)
    }

    public var keyCode: UInt32
    public var modifiers: Modifiers
    /// Printable key label captured at recording time ("K", "F5", "Space").
    public var keyLabel: String

    public init(keyCode: UInt32, modifiers: Modifiers, keyLabel: String) {
        self.keyCode = keyCode; self.modifiers = modifiers; self.keyLabel = keyLabel
    }

    public var displayString: String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option) { s += "⌥" }
        if modifiers.contains(.shift) { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        return s + keyLabel
    }

    /// Function keys (F1–F20) may be used without modifiers.
    static let functionKeyCodes: Set<UInt32> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111,
                                                 105, 107, 113, 106, 64, 79, 80, 90]

    public enum ValidationError: Error, Equatable {
        case needsModifier, commandOnlyReserved, shiftOnly
    }

    /// Rules for a combination to be accepted as a global hotkey.
    public func validate() -> ValidationError? {
        if Self.functionKeyCodes.contains(keyCode) { return nil }
        if modifiers.isEmpty { return .needsModifier }
        if modifiers == .shift { return .shiftOnly }
        if modifiers == .command { return .commandOnlyReserved }
        return nil
    }
}

public struct GeneralSettings: Codable, Equatable, Sendable {
    public var masterEnabled = true
    public var showInMenuBar = true
    public var showInDock = false
    public var launchAtLogin = false
    public var updateRateHz = 60.0
    public var hasCompletedOnboarding = false
    public var menuBarItems: Set<MenuBarItem> = Set(MenuBarItem.allCases)
    public init() {}

    public static let updateRateRange = 30.0...120.0
}

public struct SpotlightSettings: Codable, Equatable, Sendable {
    public var enabled = false
    public var radius = 150.0
    public var spotOpacity = 1.0
    public var backgroundOpacity = 0.6
    public var shape = SpotlightShape.circle
    public var barThickness = 60.0
    public var hideCursor = false
    public var dismissOnMove = false
    public var dismissDistance = 40.0
    public var holdKey: TriggerKey?
    public var holdDelay = 0.5
    public init() {}

    public static let radiusRange = 40.0...500.0
    public static let barThicknessRange = 20.0...400.0
    public static let dismissDistanceRange = 10.0...400.0
    public static let holdDelayRange = 0.0...2.0
}

public struct RingSettings: Codable, Equatable, Sendable {
    public var enabled = false
    public var radius = 50.0
    public var thickness = 3.0
    public var color = RGBAColor.blue
    public var animated = false
    public var animationSpeed = 1.0
    public var neon = false
    public init() {}

    public static let radiusRange = 10.0...150.0
    public static let thicknessRange = 1.0...20.0
    public static let speedRange = 0.25...3.0
}

public struct SoundReference: Codable, Equatable, Sendable {
    public var bookmark: Data
    public var displayName: String
    public init(bookmark: Data, displayName: String) { self.bookmark = bookmark; self.displayName = displayName }
}

public struct ClickSettings: Codable, Equatable, Sendable {
    public var feedbackEnabled = false
    public var showOnClicks = true
    public var tapKey: TriggerKey?
    public var effectType = ClickEffectType.singleRing
    public var color = RGBAColor.white
    public var size = 100.0
    public var speed = 1.0
    public var lineWidth = 3.0
    public var soundEnabled = false
    public var soundVolume = 0.5
    public var customSound: SoundReference?
    public init() {}

    public static let sizeRange = 20.0...300.0
    public static let speedRange = 0.25...3.0
    public static let lineWidthRange = 1.0...10.0

    /// True when visual feedback is on but nothing can ever trigger it.
    public func feedbackUnreachable(hasShowEffectHotkey: Bool) -> Bool {
        feedbackEnabled && !showOnClicks && tapKey == nil && !hasShowEffectHotkey
    }
}

public struct TrailSettings: Codable, Equatable, Sendable {
    public var enabled = false
    public var style = TrailStyle.solid
    public var length = 30
    public var width = 5.0
    public var opacity = 0.8
    public var color = RGBAColor.white
    public var fadeSpeed = 1.0
    public var spawnRate = 4.0
    public init() {}

    public static let lengthRange = 5...100
    public static let widthRange = 1.0...30.0
    public static let fadeSpeedRange = 0.25...3.0
    public static let spawnRateRange = 1.0...10.0
}

public struct ShakeSettings: Codable, Equatable, Sendable {
    public var enabled = true
    public var sensitivity = 0.95
    public init() {}

    public static let sensitivityRange = 0.1...1.0
}

public struct AnnotationSettings: Codable, Equatable, Sendable {
    public var enabled = false
    public var rightOptionTrigger = false
    public var defaultTool = AnnotationTool.freehand
    public var color = RGBAColor.red
    public var strokeWidth = 4.0
    public var highlighterColor = RGBAColor.yellow
    public var highlighterSize = 32.0
    public var calloutSize = 26.0
    public var autoFade = false
    public var autoFadeDelay = 5.0
    public var clearOnExit = false
    public init() {}

    public static let strokeWidthRange = 1.0...20.0
    public static let highlighterSizeRange = 8.0...80.0
    public static let calloutSizeRange = 14.0...60.0
    public static let autoFadeDelayRange = 1.0...30.0
}

public struct Settings: Codable, Equatable, Sendable {
    /// 2: default hotkeys introduced. 3: presenter tools (keystrokes, zoom, loupe, focus, camera, captions, recorder).
    public static let currentSchemaVersion = 3

    public var schemaVersion = Settings.currentSchemaVersion
    public var general = GeneralSettings()
    public var spotlight = SpotlightSettings()
    public var ring = RingSettings()
    public var click = ClickSettings()
    public var trail = TrailSettings()
    public var shake = ShakeSettings()
    public var annotations = AnnotationSettings()
    public var keystrokes = KeystrokeSettings()
    public var zoom = ZoomSettings()
    public var loupe = LoupeSettings()
    public var focus = FocusSettings()
    public var camera = CameraSettings()
    public var captions = CaptionSettings()
    public var recorder = RecorderSettings()
    public var autoMode = AutoModeSettings()
    public var hotkeys: [HotkeyAction: KeyCombo] = HotkeyAction.defaultHotkeys

    public init() {}

    public static let defaults = Settings()

    /// Clamps every bounded value into its range.
    public func clamped() -> Settings {
        var s = self
        s.general.updateRateHz = s.general.updateRateHz.clamped(to: GeneralSettings.updateRateRange)
        s.spotlight.radius = s.spotlight.radius.clamped(to: SpotlightSettings.radiusRange)
        s.spotlight.spotOpacity = s.spotlight.spotOpacity.clamped(to: 0...1)
        s.spotlight.backgroundOpacity = s.spotlight.backgroundOpacity.clamped(to: 0...1)
        s.spotlight.barThickness = s.spotlight.barThickness.clamped(to: SpotlightSettings.barThicknessRange)
        s.spotlight.dismissDistance = s.spotlight.dismissDistance.clamped(to: SpotlightSettings.dismissDistanceRange)
        s.spotlight.holdDelay = s.spotlight.holdDelay.clamped(to: SpotlightSettings.holdDelayRange)
        s.ring.radius = s.ring.radius.clamped(to: RingSettings.radiusRange)
        s.ring.thickness = s.ring.thickness.clamped(to: RingSettings.thicknessRange)
        s.ring.animationSpeed = s.ring.animationSpeed.clamped(to: RingSettings.speedRange)
        s.ring.color = s.ring.color.clamped()
        s.click.size = s.click.size.clamped(to: ClickSettings.sizeRange)
        s.click.speed = s.click.speed.clamped(to: ClickSettings.speedRange)
        s.click.lineWidth = s.click.lineWidth.clamped(to: ClickSettings.lineWidthRange)
        s.click.soundVolume = s.click.soundVolume.clamped(to: 0...1)
        s.click.color = s.click.color.clamped()
        s.trail.length = min(max(s.trail.length, TrailSettings.lengthRange.lowerBound), TrailSettings.lengthRange.upperBound)
        s.trail.width = s.trail.width.clamped(to: TrailSettings.widthRange)
        s.trail.opacity = s.trail.opacity.clamped(to: 0...1)
        s.trail.fadeSpeed = s.trail.fadeSpeed.clamped(to: TrailSettings.fadeSpeedRange)
        s.trail.spawnRate = s.trail.spawnRate.clamped(to: TrailSettings.spawnRateRange)
        s.trail.color = s.trail.color.clamped()
        s.shake.sensitivity = s.shake.sensitivity.clamped(to: ShakeSettings.sensitivityRange)
        s.annotations.strokeWidth = s.annotations.strokeWidth.clamped(to: AnnotationSettings.strokeWidthRange)
        s.annotations.highlighterSize = s.annotations.highlighterSize.clamped(to: AnnotationSettings.highlighterSizeRange)
        s.annotations.calloutSize = s.annotations.calloutSize.clamped(to: AnnotationSettings.calloutSizeRange)
        s.annotations.autoFadeDelay = s.annotations.autoFadeDelay.clamped(to: AnnotationSettings.autoFadeDelayRange)
        s.annotations.color = s.annotations.color.clamped()
        s.annotations.highlighterColor = s.annotations.highlighterColor.clamped()
        s.keystrokes.fontSize = s.keystrokes.fontSize.clamped(to: KeystrokeSettings.fontSizeRange)
        s.keystrokes.duration = s.keystrokes.duration.clamped(to: KeystrokeSettings.durationRange)
        s.zoom.factor = s.zoom.factor.clamped(to: ZoomSettings.factorRange)
        s.loupe.size = s.loupe.size.clamped(to: LoupeSettings.sizeRange)
        s.loupe.factor = s.loupe.factor.clamped(to: LoupeSettings.factorRange)
        s.loupe.borderColor = s.loupe.borderColor.clamped()
        s.focus.dimOpacity = s.focus.dimOpacity.clamped(to: FocusSettings.dimOpacityRange)
        s.focus.cornerRadius = s.focus.cornerRadius.clamped(to: FocusSettings.cornerRadiusRange)
        s.focus.padding = s.focus.padding.clamped(to: FocusSettings.paddingRange)
        s.camera.size = s.camera.size.clamped(to: CameraSettings.sizeRange)
        s.camera.borderColor = s.camera.borderColor.clamped()
        s.captions.fontSize = s.captions.fontSize.clamped(to: CaptionSettings.fontSizeRange)
        s.captions.backgroundOpacity = s.captions.backgroundOpacity.clamped(to: 0...1)
        s.captions.maxLines = min(max(s.captions.maxLines, CaptionSettings.maxLinesRange.lowerBound), CaptionSettings.maxLinesRange.upperBound)
        s.recorder.countdown = min(max(s.recorder.countdown, RecorderSettings.countdownRange.lowerBound), RecorderSettings.countdownRange.upperBound)
        return s
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        isFinite ? Swift.min(Swift.max(self, range.lowerBound), range.upperBound) : range.lowerBound
    }
}
