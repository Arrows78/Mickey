import CoreGraphics
import Foundation

/// Ready-made combinations of effects, applied in one click.
public enum Preset: String, CaseIterable, Codable, Sendable, Identifiable {
    case presentation, tutorial, discreet

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .presentation: tr("Presentation")
        case .tutorial: tr("Tutorial Video")
        case .discreet: tr("Discreet")
        }
    }

    public var detail: String {
        switch self {
        case .presentation: tr("Ring, click feedback and spotlight on a key hold — easy to follow on a projector.")
        case .tutorial: tr("Ring, click feedback and sounds, and on-screen shortcuts for recordings.")
        case .discreet: tr("Only shake to locate and a click flash on demand.")
        }
    }

    /// Returns `settings` with the preset's effects; colors, sizes and hotkeys are kept.
    public func apply(to settings: Settings) -> Settings {
        var s = settings
        s.general.masterEnabled = true
        switch self {
        case .presentation:
            s.ring.enabled = true
            s.click.feedbackEnabled = true; s.click.showOnClicks = true
            s.click.soundEnabled = false
            s.spotlight.enabled = true; s.spotlight.holdKey = s.spotlight.holdKey ?? .leftControl
            s.spotlight.dismissOnMove = false
            s.trail.enabled = false
            s.shake.enabled = true
            s.keystrokes.enabled = false
        case .tutorial:
            s.ring.enabled = true
            s.click.feedbackEnabled = true; s.click.showOnClicks = true
            s.click.soundEnabled = true
            s.spotlight.enabled = false
            s.trail.enabled = false
            s.shake.enabled = true
            s.keystrokes.enabled = true
        case .discreet:
            s.ring.enabled = false
            s.click.feedbackEnabled = true; s.click.showOnClicks = false
            s.click.tapKey = s.click.tapKey ?? .leftControl
            s.click.soundEnabled = false
            s.spotlight.enabled = false
            s.trail.enabled = false
            s.shake.enabled = true
            s.keystrokes.enabled = false
        }
        return SettingsRules.normalize(old: settings, new: s)
    }
}

/// Text for one typed key combination, e.g. "⌃⌥⌘K" or "⇧⇥".
public enum KeystrokeFormatter {
    // CGEventFlags device-independent bits.
    static let shift: UInt64 = 0x0002_0000, control: UInt64 = 0x0004_0000
    static let option: UInt64 = 0x0008_0000, command: UInt64 = 0x0010_0000

    /// Keys shown even without a modifier, because they are not text.
    static let named: [UInt16: String] = [
        36: "↩", 76: "⌤", 48: "⇥", 49: "Space", 51: "⌫", 117: "⌦", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑", 115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15",
    ]

    /// Returns nil when the key should not be shown (plain typing in shortcuts-only mode).
    public static func format(flags: UInt64, keyCode: UInt16, characters: String, shortcutsOnly: Bool) -> String? {
        let hasCommandLike = flags & (control | option | command) != 0
        let name = named[keyCode]
        // Space and ⇥ alone are typing too.
        let isTextLike = name == nil || keyCode == 49
        if shortcutsOnly && !hasCommandLike && isTextLike { return nil }
        let key = name ?? characters.uppercased()
        guard !key.isEmpty, key.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else { return nil }
        var s = ""
        if flags & control != 0 { s += "⌃" }
        if flags & option != 0 { s += "⌥" }
        if flags & shift != 0 { s += "⇧" }
        if flags & command != 0 { s += "⌘" }
        return s + key
    }
}

/// Recent keystrokes shown by the HUD; repeats collapse into "×n".
public struct KeystrokeHistory: Sendable {
    public struct Entry: Identifiable, Equatable, Sendable {
        public let id: Int
        public var text: String
        public var count: Int
        public var time: TimeInterval
        public var label: String { count > 1 ? "\(text) ×\(count)" : text }
    }

    public private(set) var entries: [Entry] = []
    public var maxEntries = 4
    public var repeatWindow: TimeInterval = 1.0
    private var nextID = 0

    public init() {}

    public mutating func add(_ text: String, at time: TimeInterval) {
        if var last = entries.last, last.text == text, time - last.time < repeatWindow {
            last.count += 1; last.time = time
            entries[entries.count - 1] = last
        } else {
            entries.append(Entry(id: nextID, text: text, count: 1, time: time))
            nextID += 1
            if entries.count > maxEntries { entries.removeFirst(entries.count - maxEntries) }
        }
    }

    /// Drops entries older than `duration`. Returns true if anything changed.
    @discardableResult
    public mutating func expire(now: TimeInterval, duration: TimeInterval) -> Bool {
        let before = entries.count
        entries.removeAll { now - $0.time > duration }
        return entries.count != before
    }
}

/// Geometry of the live zoom and the loupe, in Cocoa screen coordinates (origin bottom-left).
public enum MagnifierGeometry {
    /// Area of `screen` shown when zoomed by `factor`, chosen so the point under the pointer stays put.
    public static func zoomSource(pointer p: CGPoint, screen s: CGRect, factor: Double) -> CGRect {
        let f = max(factor, 1)
        let x = s.minX + (p.x - s.minX) * (1 - 1 / f)
        let y = s.minY + (p.y - s.minY) * (1 - 1 / f)
        return CGRect(x: x, y: y, width: s.width / f, height: s.height / f)
    }

    /// Frame, in a view of `viewSize` placed over `screen`, of the full-screen image so that `source` fills the view.
    public static func imageFrame(source: CGRect, screen s: CGRect, viewSize: CGSize) -> CGRect {
        let scaleX = viewSize.width / source.width, scaleY = viewSize.height / source.height
        return CGRect(x: -(source.minX - s.minX) * scaleX, y: -(source.minY - s.minY) * scaleY,
                      width: s.width * scaleX, height: s.height * scaleY)
    }

    /// Area shown inside a loupe of `size` centered on the pointer.
    public static func loupeSource(pointer p: CGPoint, size: Double, factor: Double) -> CGRect {
        let side = size / max(factor, 1)
        return CGRect(x: p.x - side / 2, y: p.y - side / 2, width: side, height: side)
    }
}

/// A window as listed by the window server (top-left origin, front to back).
public struct WindowInfo: Equatable, Sendable {
    public var pid: Int32
    public var layer: Int
    public var bounds: CGRect
    public var alpha: Double
    public init(pid: Int32, layer: Int, bounds: CGRect, alpha: Double = 1) {
        self.pid = pid; self.layer = layer; self.bounds = bounds; self.alpha = alpha
    }
}

public enum FocusSelector {
    /// Topmost normal window of the frontmost app, in Cocoa coordinates.
    public static func focusRect(windows: [WindowInfo], frontmostPID: Int32, primaryScreenHeight: Double) -> CGRect? {
        guard let w = windows.first(where: {
            $0.pid == frontmostPID && $0.layer == 0 && $0.alpha > 0 && $0.bounds.width > 40 && $0.bounds.height > 40
        }) else { return nil }
        return CGRect(x: w.bounds.minX, y: primaryScreenHeight - w.bounds.maxY, width: w.bounds.width, height: w.bounds.height)
    }
}

public enum CaptionText {
    /// End of `transcript` that fits in `maxChars`, cut at a word boundary.
    public static func tail(of transcript: String, maxChars: Int) -> String {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxChars else { return trimmed }
        let suffix = trimmed.suffix(maxChars)
        if let space = suffix.firstIndex(of: " ") { return String(suffix[suffix.index(after: space)...]) }
        return String(suffix)
    }

    /// Rough capacity of the caption bar.
    public static func capacity(lines: Int, charactersPerLine: Int = 46) -> Int { max(1, lines) * charactersPerLine }
}

public enum RecordingNaming {
    public static func fileName(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        func two(_ v: Int?) -> String { String(format: "%02d", v ?? 0) }
        return "Mickey Recording \(c.year ?? 0)-\(two(c.month))-\(two(c.day)) at \(two(c.hour)).\(two(c.minute)).\(two(c.second)).mov"
    }

    /// "1:05" style elapsed time.
    public static func elapsed(_ seconds: TimeInterval) -> String {
        let s = Int(max(0, seconds))
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
    }
}

public enum AutoModeRule {
    /// True when any watched app is running.
    public static func shouldActivate(running: Set<String>, watched: [String]) -> Bool {
        !running.isDisjoint(with: watched)
    }

    /// The preset for the running apps: the first watched app that runs decides, with its own preset if it has one.
    public static func preset(running: Set<String>, settings a: AutoModeSettings) -> Preset {
        guard let first = a.bundleIDs.first(where: running.contains) else { return a.preset }
        return a.appPresets[first] ?? a.preset
    }
}

/// Applies the Automatic Mode preset while a watched app runs, and gives the user's own settings back afterwards
/// unless they changed something in the meantime. Editing Automatic Mode itself does not count as a change.
public struct AutoModeSession: Sendable {
    /// The user's settings before the preset, and the settings the preset produced.
    public private(set) var snapshot: (before: Settings, applied: Settings)?
    private var appliedPreset = Preset.presentation

    public init() {}

    public var isApplied: Bool { snapshot != nil }

    /// Settings to switch to after `settings` or the running apps changed, if any.
    public mutating func update(settings s: Settings, running: Set<String>) -> Settings? {
        let active = s.autoMode.enabled && AutoModeRule.shouldActivate(running: running, watched: s.autoMode.bundleIDs)
        let wanted = AutoModeRule.preset(running: running, settings: s.autoMode)
        guard let current = snapshot else {
            guard active else { return nil }
            let applied = wanted.apply(to: s)
            snapshot = (s, applied)
            appliedPreset = wanted
            return applied
        }
        let untouched = Self.ignoringAutoMode(s) == Self.ignoringAutoMode(current.applied)
        var before = current.before
        before.autoMode = s.autoMode
        if !active {
            snapshot = nil
            return untouched ? before : nil
        }
        if untouched && wanted != appliedPreset {
            let applied = wanted.apply(to: before)
            snapshot = (before, applied)
            appliedPreset = wanted
            return applied
        }
        return nil
    }

    /// Settings worth saving on quit: the user's own while the preset is still in place, so it never sticks.
    public func settingsToPersist(_ s: Settings) -> Settings {
        guard let current = snapshot, Self.ignoringAutoMode(s) == Self.ignoringAutoMode(current.applied) else { return s }
        var before = current.before
        before.autoMode = s.autoMode
        return before
    }

    static func ignoringAutoMode(_ s: Settings) -> Settings {
        var c = s
        c.autoMode = AutoModeSettings()
        return c
    }
}
