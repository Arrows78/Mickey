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
        #expect(s.hotkeys.count == HotkeyAction.allCases.filter { $0.introducedInSchema > 2 }.count)
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

@Suite("Layout migration") struct LayoutMigrationTests {
    let azerty: (Character) -> UInt32? = { c in
        let codes: [Character: UInt32] = ["a": 12, "q": 0, "z": 13, "w": 6, "m": 41]
        return codes[c] ?? HotkeyAction.allCases.first { Character($0.defaultLetter.lowercased()) == c }?.defaultHotkey.keyCode
    }

    @Test func version3DefaultsMoveToTheLayoutKeys() {
        var v3 = Settings.defaults
        v3.schemaVersion = 3
        let s = SettingsCodec.decode(SettingsCodec.encode(v3), keyCode: azerty)
        #expect(s.schemaVersion == Settings.currentSchemaVersion)
        #expect(s.hotkeys[.toggleMaster]?.keyCode == 41)
        #expect(s.hotkeys[.toggleCaptions]?.keyCode == 12)
    }

    @Test func version4IsLeftAlone() {
        let s = SettingsCodec.decode(SettingsCodec.encode(.defaults), keyCode: azerty)
        #expect(s.hotkeys == HotkeyAction.defaultHotkeys)
    }

    @Test func firstLaunchUsesTheLayout() {
        let defaults = UserDefaults(suiteName: "mickey.test.\(UUID())")!
        let store = UserDefaultsSettingsStore(defaults: defaults, keyCode: azerty)
        #expect(store.loadSettings().hotkeys[.toggleMaster]?.keyCode == 41)
    }
}

@Suite("Settings transfer") struct SettingsTransferTests {
    @Test func exportThenImportKeepsSettings() throws {
        var s = Settings.defaults
        s.ring.enabled = true
        s.ring.radius = 80
        s.hotkeys[.toggleRing] = KeyCombo(keyCode: 15, modifiers: [.control, .option], keyLabel: "R")
        let imported = try #require(SettingsTransfer.import(SettingsTransfer.export(s)))
        #expect(imported.ring.enabled && imported.ring.radius == 80)
        #expect(imported.hotkeys[.toggleRing] == s.hotkeys[.toggleRing])
    }

    @Test func exportLeavesTheCustomSoundOut() throws {
        var s = Settings.defaults
        s.click.customSound = SoundReference(bookmark: Data([1, 2, 3]), displayName: "pop.aiff")
        let imported = try #require(SettingsTransfer.import(SettingsTransfer.export(s)))
        #expect(imported.click.customSound == nil)
    }

    @Test func rejectsFilesThatAreNotMickeySettings() {
        #expect(SettingsTransfer.import(Data("not json".utf8)) == nil)
        #expect(SettingsTransfer.import(Data("[1, 2]".utf8)) == nil)
        #expect(SettingsTransfer.import(Data(#"{"name": "other app"}"#.utf8)) == nil)
    }

    @Test func importRepairsOutOfRangeValues() throws {
        let json = #"{"schemaVersion": 4, "ring": {"radius": 100000}}"#
        let imported = try #require(SettingsTransfer.import(Data(json.utf8)))
        #expect(imported.ring.radius == RingSettings.radiusRange.upperBound)
    }

    @Test func applyingKeepsWhatBelongsToThisMac() {
        var current = Settings.defaults
        current.click.customSound = SoundReference(bookmark: Data([9]), displayName: "mine.aiff")
        current.general.launchAtLogin = true
        current.general.hasCompletedOnboarding = true
        var imported = Settings.defaults
        imported.ring.enabled = true
        let result = SettingsTransfer.applying(imported, to: current)
        #expect(result.ring.enabled)
        #expect(result.click.customSound?.displayName == "mine.aiff")
        #expect(result.general.launchAtLogin && result.general.hasCompletedOnboarding)
    }
}

@Suite("Settings saved before the recorder options") struct RecorderMigrationTests {
    @Test func missingRecorderOptionsFallBackToTheirDefaults() {
        let json = #"{"schemaVersion": 4, "recorder": {"countdown": 5, "showCursor": false}}"#
        let s = SettingsCodec.decode(Data(json.utf8))
        #expect(s.recorder.countdown == 5 && !s.recorder.showCursor)
        #expect(s.recorder.quality == .uhd && s.recorder.frameRate == 60)
    }
}

@Suite("Pause hotkey migration") struct PauseHotkeyMigrationTests {
    private func version4(_ transform: (inout Settings) -> Void) throws -> Settings {
        var old = Settings()
        old.schemaVersion = 4
        old.hotkeys[.togglePauseRecording] = nil // version 4 did not know this action
        transform(&old)
        return SettingsCodec.decode(SettingsCodec.encode(old))
    }

    @Test func aVersion4DocumentGainsThePauseHotkey() throws {
        let s = try version4 { _ in }
        #expect(s.hotkeys[.togglePauseRecording] == HotkeyAction.togglePauseRecording.defaultHotkey)
        #expect(s.schemaVersion == Settings.currentSchemaVersion)
    }

    @Test func hotkeysClearedOnPurposeStayCleared() throws {
        let s = try version4 { $0.hotkeys[.toggleRing] = nil }
        #expect(s.hotkeys[.toggleRing] == nil)
        #expect(s.hotkeys[.togglePauseRecording] != nil)
    }

    @Test func theCombinationIsNotTakenWhenAnotherActionUsesIt() throws {
        let mine = HotkeyAction.togglePauseRecording.defaultHotkey
        let s = try version4 { $0.hotkeys[.toggleRing] = mine }
        #expect(s.hotkeys[.toggleRing] == mine)
        #expect(s.hotkeys[.togglePauseRecording] == nil)
    }
}

@Suite("Settings written by a newer version") struct NewerDocumentTests {
    @Test func anUnknownHotkeyActionDoesNotCostTheOtherShortcuts() throws {
        var s = Settings()
        s.ring.enabled = true
        s.hotkeys[.toggleRing] = KeyCombo(keyCode: 1, modifiers: [.control], keyLabel: "X")
        var json = try #require(JSONSerialization.jsonObject(with: SettingsCodec.encode(s)) as? [String: Any])
        var hotkeys = try #require(json["hotkeys"] as? [String: Any])
        hotkeys["actionFromTheFuture"] = ["keyCode": 35, "keyLabel": "P", "modifiers": 11]
        json["hotkeys"] = hotkeys
        let loaded = SettingsCodec.decode(try JSONSerialization.data(withJSONObject: json))
        #expect(loaded.ring.enabled)
        #expect(loaded.hotkeys[.toggleRing]?.keyLabel == "X")
        #expect(loaded.hotkeys.count == s.hotkeys.count)
    }

    @Test func anUnknownEnumValueOnlyResetsThatField() throws {
        var json = try #require(JSONSerialization.jsonObject(with: SettingsCodec.encode(Settings())) as? [String: Any])
        var recorder = try #require(json["recorder"] as? [String: Any])
        recorder["quality"] = "8k"   // a value this version does not know
        recorder["countdown"] = 7
        json["recorder"] = recorder
        let loaded = SettingsCodec.decode(try JSONSerialization.data(withJSONObject: json))
        #expect(loaded.recorder.quality == RecorderSettings().quality)
        #expect(loaded.recorder.countdown == 7)
    }
}

@Suite("Recording area") struct RecordingAreaTests {
    @Test func anUnknownAreaFallsBackToTheWholeScreen() throws {
        var json = try #require(JSONSerialization.jsonObject(with: SettingsCodec.encode(Settings())) as? [String: Any])
        var recorder = try #require(json["recorder"] as? [String: Any])
        recorder["area"] = "windowPicker"
        recorder["countdown"] = 4
        json["recorder"] = recorder
        let loaded = SettingsCodec.decode(try JSONSerialization.data(withJSONObject: json))
        #expect(loaded.recorder.area == .screen && loaded.recorder.countdown == 4)
    }

    @Test func theChosenAreaIsKept() throws {
        var s = Settings()
        s.recorder.area = .region
        #expect(SettingsCodec.decode(SettingsCodec.encode(s)).recorder.area == .region)
    }
}
