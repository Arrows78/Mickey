import Foundation
import MickeyDomain

public protocol SettingsStore: AnyObject {
    func loadSettings() -> Settings
    func saveSettings(_ settings: Settings)
    func loadReviewState() -> ReviewState
    func saveReviewState(_ state: ReviewState)
    func reset()
}

/// Stores each value as one JSON document in UserDefaults.
public final class UserDefaultsSettingsStore: SettingsStore, @unchecked Sendable {
    public static let settingsKey = "mickey.settings.v1"
    public static let reviewKey = "mickey.review.v1"

    private let defaults: UserDefaults
    private let keyCode: SettingsCodec.KeyCodeLookup?

    /// `keyCode` maps a letter to the key typing it in the current keyboard layout, so default hotkeys follow the layout.
    public init(defaults: UserDefaults = .standard, keyCode: SettingsCodec.KeyCodeLookup? = nil) {
        self.defaults = defaults
        self.keyCode = keyCode
    }

    public func loadSettings() -> Settings {
        guard let data = defaults.data(forKey: Self.settingsKey) else {
            return keyCode.map { Settings.defaults.localizingDefaultHotkeys(keyCode: $0) } ?? .defaults
        }
        return SettingsCodec.decode(data, keyCode: keyCode)
    }

    public func saveSettings(_ settings: Settings) {
        defaults.set(SettingsCodec.encode(settings), forKey: Self.settingsKey)
    }

    public func loadReviewState() -> ReviewState {
        guard let data = defaults.data(forKey: Self.reviewKey) else { return ReviewState() }
        return (try? JSONDecoder().decode(ReviewState.self, from: data)) ?? ReviewState()
    }

    public func saveReviewState(_ state: ReviewState) {
        defaults.set(try? JSONEncoder().encode(state), forKey: Self.reviewKey)
    }

    public func reset() {
        defaults.removeObject(forKey: Self.settingsKey)
    }
}

public final class InMemorySettingsStore: SettingsStore, @unchecked Sendable {
    public var settings: Settings
    public var review = ReviewState()
    public private(set) var saveCount = 0

    public init(settings: Settings = .defaults) { self.settings = settings }

    public func loadSettings() -> Settings { settings }
    public func saveSettings(_ settings: Settings) { self.settings = settings; saveCount += 1 }
    public func loadReviewState() -> ReviewState { review }
    public func saveReviewState(_ state: ReviewState) { review = state }
    public func reset() { settings = .defaults }
}

/// JSON codec that tolerates missing, unknown or invalid fields: each bad leaf falls back to its default.
public enum SettingsCodec {
    public typealias KeyCodeLookup = (Character) -> UInt32?

    public static func encode(_ s: Settings) -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return (try? e.encode(s)) ?? Data()
    }

    public static func decode(_ data: Data, keyCode: KeyCodeLookup? = nil) -> Settings {
        if let s = try? JSONDecoder().decode(Settings.self, from: data) { return migrate(s, keyCode: keyCode).clamped() }
        guard let stored = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let base = try? JSONSerialization.jsonObject(with: encode(.defaults)) as? [String: Any]
        else { return .defaults }

        var merged = base
        merge(stored, into: &merged, path: [])
        let result = (try? decodeObject(merged)) ?? .defaults
        return migrate(result, keyCode: keyCode).clamped()
    }

    /// Copies stored leaves into `root` one at a time, keeping each only if the whole document still decodes.
    private static func merge(_ stored: [String: Any], into root: inout [String: Any], path: [String]) {
        for (key, storedValue) in stored {
            let keyPath = path + [key]
            var value = storedValue
            // A newer version may know actions this one does not: dropping them keeps every other shortcut.
            if keyPath == ["hotkeys"], let known = value as? [String: Any] {
                value = known.filter { HotkeyAction(rawValue: $0.key) != nil }
            }
            if let sub = value as? [String: Any], lookup(keyPath, in: root) is [String: Any],
               !isDictionaryLeaf(keyPath) {
                merge(sub, into: &root, path: keyPath)
                continue
            }
            var candidate = root
            set(value, at: keyPath, in: &candidate)
            if (try? decodeObject(candidate)) != nil { root = candidate }
        }
    }

    /// Dictionaries whose keys are data (not fields) are merged as a whole.
    private static func isDictionaryLeaf(_ path: [String]) -> Bool { path == ["hotkeys"] }

    private static func decodeObject(_ object: [String: Any]) throws -> Settings {
        let data = try JSONSerialization.data(withJSONObject: object)
        return try JSONDecoder().decode(Settings.self, from: data)
    }

    private static func lookup(_ path: [String], in object: [String: Any]) -> Any? {
        var current: Any? = object
        for k in path { current = (current as? [String: Any])?[k] }
        return current
    }

    private static func set(_ value: Any, at path: [String], in object: inout [String: Any]) {
        guard let first = path.first else { return }
        if path.count == 1 { object[first] = value; return }
        var child = object[first] as? [String: Any] ?? [:]
        set(value, at: Array(path.dropFirst()), in: &child)
        object[first] = child
    }

    /// Upgrades settings saved by an older schema.
    static func migrate(_ s: Settings, keyCode: KeyCodeLookup? = nil) -> Settings {
        var m = s
        // Give actions introduced after the saved version their default, unless unset on purpose
        // since then or the combination is already in use.
        for action in HotkeyAction.allCases where action.introducedInSchema > s.schemaVersion {
            let combo = action.defaultHotkey
            if m.hotkeys[action] == nil && !m.hotkeys.values.contains(combo) { m.hotkeys[action] = combo }
        }
        if s.schemaVersion < 3 {
            // Presenter tools appear in the menu-bar popover like every other toggle.
            m.general.menuBarItems.formUnion([.keystrokes, .liveZoom, .loupe, .focus, .cameraBubble, .captions])
        }
        if s.schemaVersion < 4, let keyCode {
            // Defaults used to sit on US key positions: ⌃⌥⌘M was ⌃⌥⌘, on an AZERTY keyboard.
            m = m.localizingDefaultHotkeys(keyCode: keyCode)
        }
        m.schemaVersion = Settings.currentSchemaVersion
        return m
    }
}
