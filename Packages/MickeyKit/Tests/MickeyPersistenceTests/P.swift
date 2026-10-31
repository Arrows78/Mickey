import Foundation
import Testing
import MickeyDomain
@testable import MickeyPersistence

@Suite("Persistence")
struct PersistenceTests {
    func freshDefaults() -> UserDefaults {
        let name = "mickey.tests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func emptyStoreReturnsDefaults() {
        #expect(UserDefaultsSettingsStore(defaults: freshDefaults()).loadSettings() == .defaults)
    }

    @Test func roundTrip() {
        let store = UserDefaultsSettingsStore(defaults: freshDefaults())
        var s = Settings.defaults
        s.spotlight.enabled = true
        s.spotlight.holdKey = .rightCommand
        s.ring.color = .purple
        s.trail.style = .stars
        s.general.menuBarItems = [.ring, .trail]
        s.hotkeys[.toggleRing] = KeyCombo(keyCode: 15, modifiers: [.control, .option], keyLabel: "R")
        s.click.customSound = SoundReference(bookmark: Data([1, 2, 3]), displayName: "pop.aiff")
        store.saveSettings(s)
        #expect(store.loadSettings() == s)
    }

    @Test func hotkeysEncodeAsObject() throws {
        var s = Settings.defaults
        s.hotkeys[.toggleMaster] = KeyCombo(keyCode: 46, modifiers: [.command, .shift], keyLabel: "M")
        let json = try #require(try JSONSerialization.jsonObject(with: SettingsCodec.encode(s)) as? [String: Any])
        #expect((json["hotkeys"] as? [String: Any])?["toggleMaster"] != nil)
    }

    @Test func invalidFieldsFallBackIndividually() throws {
        let json = """
        {"spotlight": {"radius": 220, "shape": "hexagon", "enabled": "yes"},
         "ring": {"color": {"red": 1, "green": 0, "blue": 0, "alpha": 1}},
         "trail": {"length": 9999},
         "unknownSection": {"x": 1},
         "general": {"menuBarItems": ["ring", "teleport"]}}
        """
        let s = SettingsCodec.decode(Data(json.utf8))
        #expect(s.spotlight.radius == 220)
        #expect(s.spotlight.shape == .circle)
        #expect(!s.spotlight.enabled)
        #expect(s.ring.color == RGBAColor(red: 1, green: 0, blue: 0))
        #expect(s.trail.length == TrailSettings.lengthRange.upperBound)
        #expect(s.general.menuBarItems == Set(MenuBarItem.allCases))
        #expect(s.shake == ShakeSettings())
    }

    @Test func garbageDataReturnsDefaults() {
        #expect(SettingsCodec.decode(Data("not json".utf8)) == .defaults)
        #expect(SettingsCodec.decode(Data("[1,2]".utf8)) == .defaults)
    }

    @Test func resetRemovesSettings() {
        let store = UserDefaultsSettingsStore(defaults: freshDefaults())
        var s = Settings.defaults
        s.ring.enabled = true
        store.saveSettings(s)
        store.reset()
        #expect(store.loadSettings() == .defaults)
    }

    @Test func reviewStateRoundTrip() {
        let store = UserDefaultsSettingsStore(defaults: freshDefaults())
        var r = ReviewState()
        r.launchCount = 3
        r.activeMinutes = 12.5
        r.lastRequest = Date(timeIntervalSince1970: 1_000_000)
        store.saveReviewState(r)
        #expect(store.loadReviewState() == r)
    }
}

@Suite("Migration") struct MigrationTests {
    @Test func version1GainsDefaultHotkeysWithoutOverridingChoices() throws {
        var old = Settings()
        old.schemaVersion = 1
        let custom = KeyCombo(keyCode: 1, modifiers: [.control, .option, .command], keyLabel: "S")
        old.hotkeys = [.toggleRing: custom] // takes the Spotlight default combination
        let s = SettingsCodec.decode(SettingsCodec.encode(old))
        #expect(s.schemaVersion == Settings.currentSchemaVersion)
        #expect(s.hotkeys[.toggleRing] == custom)
        #expect(s.hotkeys[.toggleSpotlight] == nil)
        #expect(s.hotkeys[.toggleMaster] == HotkeyAction.toggleMaster.defaultHotkey)
    }

    @Test func version2DocumentWithoutPresenterToolsLoadsAndGainsOnlyNewDefaults() throws {
        var v2 = Settings()
        v2.schemaVersion = 2
        v2.ring.enabled = true
        v2.hotkeys = [:] // cleared on purpose in version 2
        var json = try #require(JSONSerialization.jsonObject(with: SettingsCodec.encode(v2)) as? [String: Any])
        for key in ["keystrokes", "zoom", "loupe", "focus", "camera", "captions", "recorder", "autoMode"] { json[key] = nil }
        let s = SettingsCodec.decode(try JSONSerialization.data(withJSONObject: json))
        #expect(s.ring.enabled)
        #expect(s.schemaVersion == Settings.currentSchemaVersion)
        #expect(s.loupe == LoupeSettings())
        #expect(s.general.menuBarItems.contains(.loupe))
        #expect(s.hotkeys[.toggleRing] == nil)
        #expect(s.hotkeys[.toggleLoupe] == HotkeyAction.toggleLoupe.defaultHotkey)
        #expect(s.hotkeys.count == HotkeyAction.allCases.filter { $0.introducedInSchema == 3 }.count)
    }

    @Test func clearedHotkeysStayClearedInVersion2() {
        var s = Settings()
        s.hotkeys = [:]
        #expect(SettingsCodec.decode(SettingsCodec.encode(s)).hotkeys.isEmpty)
    }
}

@Suite("Added fields") struct AddedFieldTests {
    @Test func settingsSavedBeforeLocatorStyleKeepEverythingElse() throws {
        var s = Settings()
        s.shake.sensitivity = 0.5
        var json = try #require(JSONSerialization.jsonObject(with: SettingsCodec.encode(s)) as? [String: Any])
        var shake = try #require(json["shake"] as? [String: Any])
        shake["style"] = nil
        json["shake"] = shake
        let decoded = SettingsCodec.decode(try JSONSerialization.data(withJSONObject: json))
        #expect(decoded.shake.sensitivity == 0.5)
        #expect(decoded.shake.style == .enlargedPointer)
    }
}
