import Carbon
import Testing
import MickeyDomain
@testable import MickeyUI

/// The shortcuts are tied to physical keys while their letters depend on the keyboard layout. These tests read the
/// real layouts that macOS ships (no layout is switched, nothing about the user's setup is touched).
@Suite("Real keyboard layouts") @MainActor
struct RealKeyboardLayoutTests {
    private func layout(_ name: String) throws -> (labels: [UInt32: String], codes: [Character: UInt32]) {
        try #require(KeyboardLayout.table(forLayoutID: "com.apple.keylayout.\(name)"), "layout \(name) is not installed")
    }

    /// Hotkeys the way the app builds them for a layout: the key printing the letter, else the US key.
    private func defaults(_ name: String) throws -> [HotkeyAction: KeyCombo] {
        let l = try layout(name)
        return HotkeyAction.defaultHotkeys(keyCode: { l.codes[$0] })
    }

    @Test func onUSTheDefaultsAreTheUSKeys() throws {
        let us = try layout("US")
        #expect(us.codes["m"] == 46 && us.codes["a"] == 0 && us.codes["z"] == 6)
        #expect(try defaults("US") == HotkeyAction.defaultHotkeys)
    }

    @Test func onAZERTYTheDefaultIsTheKeyPrintingTheLetter() throws {
        let french = try layout("French")
        #expect(french.codes["a"] == 12, "A sits where Q is on QWERTY")
        #expect(french.codes["z"] == 13 && french.codes["q"] == 0 && french.codes["w"] == 6)
        #expect(french.codes["m"] == 41, "M sits on the US ; key")
        let d = try defaults("French")
        #expect(d[.toggleMaster]?.keyCode == 41)
        #expect(d[.toggleCaptions]?.keyCode == 12)
        #expect(d[.toggleLiveZoom]?.keyCode == 13)
        #expect(d[.toggleFocus]?.keyCode == 6)
    }

    @Test(arguments: ["French", "French-numerical", "Belgian", "German", "Spanish", "Dvorak", "US", "ABC-QWERTZ"])
    func everyDefaultLandsOnAKeyPrintingItsLetter(name: String) throws {
        let l = try layout(name)
        let d = try defaults(name)
        for action in HotkeyAction.allCases {
            let letter = String(action.defaultLetter)
            let code = try #require(d[action]?.keyCode)
            #expect(l.labels[code] == letter, "\(name): \(action) should sit on the key printing \(letter), got \(l.labels[code] ?? "nothing")")
        }
    }

    @Test(arguments: ["French", "French-numerical", "Belgian", "German", "Spanish", "Dvorak", "US"])
    func noTwoDefaultsShareAKey(name: String) throws {
        let d = try defaults(name)
        #expect(Set(d.values).count == HotkeyAction.allCases.count)
    }

    @Test func theLabelFollowsTheKeyOnEachLayout() throws {
        // The same physical key (code 12) is Q on QWERTY, A on AZERTY, ' on Dvorak.
        #expect(try layout("US").labels[12] == "Q")
        #expect(try layout("French").labels[12] == "A")
        #expect(try layout("Dvorak").labels[12] == "'")
        // QWERTZ swaps Y and Z.
        #expect(try layout("German").labels[16] == "Z")
        #expect(try layout("US").labels[16] == "Y")
    }

    @Test func aLayoutWithoutLatinLettersFallsBackToTheUSKeys() throws {
        let russian = try layout("Russian")
        #expect(russian.codes["m"] == nil, "no Latin M on a Cyrillic layout")
        let d = try defaults("Russian")
        #expect(d == HotkeyAction.defaultHotkeys, "falls back to the US positions")
        #expect(Set(d.values).count == HotkeyAction.allCases.count)
    }

    @Test func whatTheRealCurrentLayoutReportsIsConsistent() {
        // Whatever layout this Mac uses, the default hotkeys exist, are distinct and print their own letter.
        let d = HotkeyAction.defaultHotkeys(keyCode: KeyboardLayout.keyCode(for:))
        #expect(Set(d.values).count == HotkeyAction.allCases.count)
        for (action, combo) in d where KeyboardLayout.keyCode(for: Character(action.defaultLetter.lowercased())) != nil {
            #expect(KeyboardLayout.label(for: combo.keyCode) == String(action.defaultLetter), "\(action)")
        }
    }

    /// What pressing a key does while drawing, on real layouts: the characters are what the layout prints for the key.
    @Test(arguments: ["US", "French", "French-numerical", "Belgian", "German", "Spanish", "Dvorak", "Russian", "Greek", "Arabic"])
    func everyDrawingToolIsReachableOnEveryLayout(name: String) throws {
        let l = try layout(name)
        let usCode: [Character: UInt16] = ["f": 3, "a": 0, "r": 15, "c": 8, "l": 37, "h": 4, "t": 17, "n": 45]
        for tool in AnnotationTool.allCases {
            guard let letter = tool.shortcutKey, let usKey = usCode[letter] else { continue }
            // Latin layouts: the user presses the key that prints the letter. Others: the key at its US place.
            let code = l.codes[letter].map(UInt16.init) ?? usKey
            let printed = l.labels[UInt32(code)]?.lowercased()
            #expect(AnnotationTool.forKey(characters: printed, keyCode: code) == tool,
                    "\(name): \(tool) should answer to the key printing \(printed ?? "?") (code \(code))")
        }
    }

    @Test func undoAndCopyAreReachableOnEveryLayout() throws {
        for name in ["US", "French", "German", "Dvorak", "Russian", "Greek", "Arabic"] {
            let l = try layout(name)
            for (letter, usKey) in [("z" as Character, UInt16(6)), ("c", UInt16(8))] {
                let code = l.codes[letter].map(UInt16.init) ?? usKey
                let printed = l.labels[UInt32(code)]?.lowercased()
                #expect(ShortcutKey.letter(characters: printed, keyCode: code) == letter, "\(name): \(letter)")
            }
        }
    }
}
