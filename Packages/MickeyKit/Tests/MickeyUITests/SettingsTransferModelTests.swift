import Foundation
import Testing
import MickeyDomain
import MickeyPersistence
@testable import MickeyUI

/// Stand-in for the app: answers the file panels with a chosen URL and ignores everything else.
@MainActor
final class StubActions: AppActions {
    var exportURL: URL?
    var importURL: URL?
    func chooseCustomSound() -> SoundReference? { nil }
    func setLaunchAtLogin(_ enabled: Bool) -> LoginItemState { .disabled }
    func openLoginItemsSettings() {}
    func toggleDrawing() {}
    func showSettings(_ section: SettingsSection?) {}
    func previewClickEffect() {}
    func quit() {}
    func open(_ url: URL) {}
    func setHotkeyRecording(_ recording: Bool) {}
    func request(_ permission: Permission) {}
    func toggleRecording() {}
    func togglePauseRecording() {}
    func revealRecordings() {}
    func chooseSettingsExportURL() -> URL? { exportURL }
    func chooseSettingsImportURL() -> URL? { importURL }
}

@Suite("Settings export and import") @MainActor
final class SettingsTransferModelTests {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("mickey-tests-\(UUID().uuidString)")
    let actions = StubActions()

    init() throws { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }

    deinit { try? FileManager.default.removeItem(at: folder) }

    private func model(_ settings: MickeyDomain.Settings = .defaults) -> AppModel {
        let model = AppModel(store: InMemorySettingsStore(settings: settings))
        model.actions = actions
        return model
    }

    @Test func exportWritesAFileThatImportsBack() throws {
        var source = MickeyDomain.Settings.defaults
        source.ring.enabled = true
        source.ring.radius = 90
        let a = model(source)
        actions.exportURL = folder.appendingPathComponent("a.json")
        a.exportSettings()
        #expect(FileManager.default.fileExists(atPath: actions.exportURL!.path))

        let b = model()
        actions.importURL = actions.exportURL
        b.importSettings()
        #expect(b.settings.ring.enabled && b.settings.ring.radius == 90)
        #expect(b.transferMessage?.contains("a.json") == true)
    }

    @Test func cancellingThePanelChangesNothing() {
        let m = model()
        let before = m.settings
        actions.exportURL = nil
        actions.importURL = nil
        m.exportSettings()
        m.importSettings()
        #expect(m.transferMessage == nil)
        #expect(m.settings == before)
    }

    @Test func aFileThatIsNotAnExportIsRefusedAndKeepsTheSettings() throws {
        let m = model()
        m.update { $0.ring.enabled = true }
        let url = folder.appendingPathComponent("other.json")
        try Data(#"{"hello": "world"}"#.utf8).write(to: url)
        actions.importURL = url
        m.importSettings()
        #expect(m.settings.ring.enabled)
        #expect(m.transferMessage == "This file is not a Mickey settings export.")
    }

    @Test func importKeepsWhatBelongsToThisMac() throws {
        var mine = MickeyDomain.Settings.defaults
        mine.general.hasCompletedOnboarding = true
        mine.click.customSound = SoundReference(bookmark: Data([7]), displayName: "mine.aiff")
        let m = model(mine)
        let url = folder.appendingPathComponent("theirs.json")
        try SettingsTransfer.export(.defaults).write(to: url)
        actions.importURL = url
        m.importSettings()
        #expect(m.settings.general.hasCompletedOnboarding)
        #expect(m.settings.click.customSound?.displayName == "mine.aiff")
    }
}
