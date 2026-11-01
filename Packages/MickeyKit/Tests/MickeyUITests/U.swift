import Testing
import MickeyDomain
@testable import MickeyUI

@Suite("Hotkey conflicts") @MainActor
struct HotkeyConflictTests {
    @Test func parsesStoredKeyEquivalents() {
        #expect(HotkeyConflict.parse("@~^k") == .init(code: 40, modifiers: [.command, .option, .control]))
        #expect(HotkeyConflict.parse("@$t") == .init(code: 17, modifiers: [.command, .shift]))
        #expect(HotkeyConflict.parse("@") == nil)
        #expect(HotkeyConflict.parse("@F5") == nil)
    }

    @Test func duplicatesOfAnotherActionAreRefused() {
        let combo = HotkeyAction.toggleRing.defaultHotkey
        let conflict = HotkeyConflict.check(combo, otherActions: [.toggleRing: combo])
        #expect(conflict == .action("Toggle Ring"))
        #expect(conflict?.blocks == true)
    }

    @Test func commonAppShortcutsOnlyWarn() {
        let reopenTab = KeyCombo(keyCode: 17, modifiers: [.command, .shift], keyLabel: "T")
        guard case .commonAppShortcut? = HotkeyConflict.check(reopenTab) else {
            Issue.record("⌘⇧T should be flagged as a common app shortcut"); return
        }
        #expect(HotkeyConflict.check(reopenTab)?.blocks == false)
    }

    @Test func defaultsAvoidCommonAppShortcuts() {
        for action in HotkeyAction.allCases {
            if case .commonAppShortcut? = HotkeyConflict.check(action.defaultHotkey) { Issue.record("\(action) default is a common app shortcut") }
        }
    }
}

@Suite("Keyboard layout") @MainActor struct KeyboardLayoutTests {
    /// S sits on the same key in QWERTY, AZERTY and QWERTZ.
    @Test func lettersRoundTrip() {
        #expect(KeyboardLayout.keyCode(for: "s") == 1)
        #expect(KeyboardLayout.label(for: 1) == "S")
        #expect(KeyboardLayout.displayString(HotkeyAction.toggleSpotlight.defaultHotkey) == "⌃⌥⌘S")
    }

    @Test func layoutDefaultsHaveNoConflicts() {
        let defaults = HotkeyAction.allCases.map(KeyboardLayout.defaultHotkey)
        #expect(Set(defaults).count == defaults.count)
        for combo in defaults { #expect(HotkeyConflict.check(combo)?.blocks != true) }
    }
}
