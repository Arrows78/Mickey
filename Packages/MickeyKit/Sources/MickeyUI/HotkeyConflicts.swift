import Carbon.HIToolbox
import Foundation
import MickeyDomain

/// Why a combination may not reach Mickey, or may take a shortcut away from another app.
///
/// Global hotkeys registered by other apps cannot be detected: macOS lets several processes register
/// the same combination without reporting an error.
enum HotkeyConflict: Equatable {
    /// An enabled macOS shortcut (Mission Control, Spotlight, screenshots…) swallows it first.
    case system
    /// Another Mickey action already uses it.
    case action(String)
    /// The user's own "All Applications" shortcut in System Settings.
    case userAppShortcut(String)
    /// A shortcut many apps rely on.
    case commonAppShortcut(String)

    /// Conflicts that make the combination useless are refused; the others are only warnings.
    var blocks: Bool {
        switch self {
        case .system, .action: true
        case .userAppShortcut, .commonAppShortcut: false
        }
    }

    var message: String {
        switch self {
        case .system: "Already used by macOS (System Settings › Keyboard › Keyboard Shortcuts)."
        case .action(let name): "Already used by \(name)."
        case .userAppShortcut(let item): "Also your app shortcut for “\(item)”; Mickey will take it from every app."
        case .commonAppShortcut(let use): "Often used by apps (\(use)); Mickey will take it from every app."
        }
    }

    /// Most severe conflict for `combo`, if any.
    static func check(_ combo: KeyCombo, otherActions: [HotkeyAction: KeyCombo] = [:]) -> HotkeyConflict? {
        if isUsedBySystem(combo) { return .system }
        if let owner = otherActions.first(where: { $0.value == combo })?.key { return .action(owner.title) }
        if let item = userAppShortcut(for: combo) { return .userAppShortcut(item) }
        if let use = commonShortcuts[Key(combo)] { return .commonAppShortcut(use) }
        return nil
    }

    // MARK: Sources

    static func isUsedBySystem(_ c: KeyCombo) -> Bool {
        var unmanaged: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&unmanaged) == noErr,
              let shortcuts = unmanaged?.takeRetainedValue() as? [[String: Any]] else { return false }
        let relevant = cmdKey | optionKey | controlKey | shiftKey
        var mods = 0
        if c.modifiers.contains(.command) { mods |= cmdKey }
        if c.modifiers.contains(.option) { mods |= optionKey }
        if c.modifiers.contains(.control) { mods |= controlKey }
        if c.modifiers.contains(.shift) { mods |= shiftKey }
        return shortcuts.contains { s in
            (s[kHISymbolicHotKeyEnabled as String] as? Bool) == true
                && (s[kHISymbolicHotKeyCode as String] as? Int) == Int(c.keyCode)
                && ((s[kHISymbolicHotKeyModifiers as String] as? Int) ?? -1) & relevant == mods
        }
    }

    /// Menu item of a matching "All Applications" shortcut, stored as e.g. `"@~^k"` in the global domain.
    static func userAppShortcut(for c: KeyCombo) -> String? {
        guard let equivalents = UserDefaults.standard.dictionary(forKey: "NSUserKeyEquivalents") as? [String: String]
        else { return nil }
        return equivalents.first { parse($0.value) == Key(c) }?.key
    }

    static func parse(_ equivalent: String) -> Key? {
        var mods: KeyCombo.Modifiers = []
        var rest = Substring(equivalent)
        while let first = rest.first, "@~^$".contains(first) {
            switch first {
            case "@": mods.insert(.command)
            case "~": mods.insert(.option)
            case "^": mods.insert(.control)
            default: mods.insert(.shift)
            }
            rest = rest.dropFirst()
        }
        guard rest.count == 1, let code = keyCodes[rest.lowercased()] else { return nil }
        return Key(code: code, modifiers: mods)
    }

    struct Key: Hashable {
        let code: UInt32
        let modifiers: KeyCombo.Modifiers
        init(code: UInt32, modifiers: KeyCombo.Modifiers) { self.code = code; self.modifiers = modifiers }
        init(_ c: KeyCombo) { self.init(code: c.keyCode, modifiers: c.modifiers) }
    }

    /// ANSI key codes of printable keys, for parsing stored key equivalents.
    private static let keyCodes: [String: UInt32] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12,
        "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23,
        "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34,
        "p": 35, "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44, "n": 45, "m": 46,
        ".": 47, "`": 50,
    ]

    private static func common(_ mods: KeyCombo.Modifiers, _ key: String, _ use: String) -> (Key, String) {
        (Key(code: keyCodes[key]!, modifiers: mods), use)
    }

    /// Widely used app shortcuts that a global hotkey would take away.
    private static let commonShortcuts: [Key: String] = Dictionary(uniqueKeysWithValues: [
        common([.command, .shift], "t", "reopen closed tab"),
        common([.command, .shift], "n", "new private window, new folder"),
        common([.command, .shift], "z", "redo"),
        common([.command, .shift], "s", "save as"),
        common([.command, .shift], "g", "go to folder"),
        common([.command, .shift], "a", "Finder Applications"),
        common([.command, .shift], "d", "Finder Desktop"),
        common([.command, .shift], "o", "Finder Documents"),
        common([.command, .shift], "h", "Finder Home"),
        common([.command, .shift], "f", "find in files"),
        common([.command, .shift], "p", "command palette"),
        common([.command, .shift], "k", "delete line"),
        common([.command, .shift], "[", "previous tab"),
        common([.command, .shift], "]", "next tab"),
        common([.command, .shift], ".", "show hidden files"),
        common([.command, .option], "i", "developer tools"),
        common([.command, .option], "j", "JavaScript console"),
        common([.command, .option], "h", "hide others"),
        common([.command, .option], "m", "minimize all"),
        common([.command, .option], "w", "close all windows"),
        common([.command, .option], "v", "move item"),
        common([.command, .control], "f", "full screen"),
        common([.command, .control], "q", "lock screen"),
        common([.command, .control], "d", "look up"),
    ])
}
