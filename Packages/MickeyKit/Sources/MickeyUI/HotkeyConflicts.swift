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
        case .system: tr("Already used by macOS (System Settings › Keyboard › Keyboard shortcuts).")
        case .action(let name): trf("Already used by %@.", name)
        case .userAppShortcut(let item): trf("Also your app shortcut for “%@”; Mickey will take it from every app.", item)
        case .commonAppShortcut(let use): trf("Often used by apps (%@); Mickey will take it from every app.", tr(use))
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
        guard rest.count == 1, let c = rest.first, let code = keyCode(for: c) else { return nil }
        return Key(code: code, modifiers: mods)
    }

    /// Key typing `c` in the current layout, or its US position when the layout has none.
    static func keyCode(for c: Character) -> UInt32? {
        KeyboardLayout.keyCode(for: c) ?? usKeyCodes[String(c).lowercased()]
    }

    struct Key: Hashable {
        let code: UInt32
        let modifiers: KeyCombo.Modifiers
        init(code: UInt32, modifiers: KeyCombo.Modifiers) { self.code = code; self.modifiers = modifiers }
        init(_ c: KeyCombo) { self.init(code: c.keyCode, modifiers: c.modifiers) }
    }

    /// ANSI key codes of printable keys, used when the current layout has no key for a character.
    private static let usKeyCodes: [String: UInt32] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12,
        "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23,
        "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34,
        "p": 35, "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44, "n": 45, "m": 46,
        ".": 47, "`": 50,
    ]

    private static func common(_ mods: KeyCombo.Modifiers, _ key: String, _ use: String) -> (Key, String) {
        (Key(code: keyCode(for: Character(key))!, modifiers: mods), use)
    }

    /// Widely used app shortcuts that a global hotkey would take away, on the keys of the current layout.
    private static var commonShortcuts: [Key: String] {
        Dictionary([
            common([.command, .shift], "t", "reopen closed tab"),
            common([.command, .shift], "n", "new private window, new folder"),
            common([.command, .shift], "z", "redo"),
            common([.command, .shift], "s", "save as"),
            common([.command, .shift], "g", "go to folder"),
            common([.command, .shift], "a", "Finder applications"),
            common([.command, .shift], "d", "Finder desktop"),
            common([.command, .shift], "o", "Finder documents"),
            common([.command, .shift], "h", "Finder home"),
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
            // Text fields move the caret with these everywhere in macOS.
            common([.control], "a", "text editing: line start"),
            common([.control], "e", "text editing: line end"),
            common([.control], "k", "text editing: delete to line end"),
            common([.control], "b", "text editing: back one character"),
            common([.control], "f", "text editing: forward one character"),
            common([.control], "n", "text editing: next line"),
            common([.control], "p", "text editing: previous line"),
            common([.control], "d", "text editing: delete forward"),
            common([.control], "h", "text editing: delete backward"),
            common([.control], "o", "text editing: open line"),
            common([.control], "t", "text editing: transpose"),
            common([.control], "y", "text editing: yank"),
        ], uniquingKeysWith: { first, _ in first })
    }
}
