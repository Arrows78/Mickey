import Carbon.HIToolbox
import Foundation
import MickeyDomain

/// What each key prints in the current keyboard layout, so shortcuts show and use the right letters
/// on AZERTY, QWERTZ, Dvorak…
///
/// Global hotkeys are tied to physical keys (virtual key codes); the letter on a key depends on the layout.
/// Not actor-isolated so settings loading can use it, but only called from the main thread.
nonisolated public enum KeyboardLayout {
    private struct Table {
        let id: String
        var labels: [UInt32: String] = [:]
        var codes: [Character: UInt32] = [:]
    }

    nonisolated(unsafe) private static var table: Table?

    /// Uppercased character printed by `keyCode` without modifiers, or nil for keys that print nothing.
    public static func label(for keyCode: UInt32) -> String? { current().labels[keyCode] }

    /// Key code printing `character` without modifiers, if the layout has one.
    public static func keyCode(for character: Character) -> UInt32? {
        current().codes[Character(character.lowercased())]
    }

    /// `combo` as shown to the user, with the key named after the current layout.
    public static func displayString(_ combo: KeyCombo) -> String {
        combo.displayString(keyName: combo.keyLabel.count == 1 ? label(for: combo.keyCode) : nil)
    }

    /// Default hotkeys on the keys printing their letters in the current layout.
    public static func defaultHotkey(_ action: HotkeyAction) -> KeyCombo { action.defaultHotkey(keyCode: keyCode(for:)) }

    private static func current() -> Table {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let idPointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
              let dataPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return Table(id: "") }
        let id = Unmanaged<CFString>.fromOpaque(idPointer).takeUnretainedValue() as String
        if let table, table.id == id { return table }

        let data = Unmanaged<CFData>.fromOpaque(dataPointer).takeUnretainedValue()
        var built = Table(id: id)
        // Character-producing keys all sit below 0x60 (F-keys, arrows and the keypad come after).
        let keypad: Set<UInt32> = [65, 67, 69, 71, 75, 76, 78, 81, 82, 83, 84, 85, 86, 87, 88, 89, 91, 92]
        CFDataGetBytePtr(data).withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { layout in
            for code in UInt32(0)..<0x60 where !keypad.contains(code) {
                var deadKeys: UInt32 = 0
                var length = 0
                var chars = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(layout, UInt16(code), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                                            OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, chars.count, &length, &chars)
                guard status == noErr, length > 0 else { continue }
                let text = String(utf16CodeUnits: chars, count: length)
                guard let c = text.first, text.count == 1, !c.isWhitespace,
                      c.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else { continue }
                built.labels[code] = text.uppercased()
                // Keep the first key for a character (some layouts repeat one on the ISO key).
                if built.codes[Character(text.lowercased())] == nil { built.codes[Character(text.lowercased())] = code }
            }
        }
        table = built
        return built
    }
}
