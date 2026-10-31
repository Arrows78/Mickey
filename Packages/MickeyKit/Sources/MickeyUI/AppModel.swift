import Foundation
import Observation
import SwiftUI
import MickeyDomain
import MickeyPersistence

/// Side effects the UI can request; implemented by the app's composition root.
public protocol AppActions: AnyObject {
    func chooseCustomSound() -> SoundReference?
    func setLaunchAtLogin(_ enabled: Bool) -> LoginItemState
    func openLoginItemsSettings()
    func toggleDrawing()
    func showSettings(_ section: SettingsSection?)
    func previewClickEffect()
    func quit()
    func open(_ url: URL)
    func setHotkeyRecording(_ recording: Bool)
}

/// Single source of truth for the UI. Every change goes through `update`, which applies the
/// cross-field rules and persists the result.
@Observable
public final class AppModel {
    public private(set) var settings: MickeyDomain.Settings
    public var loginItemState: LoginItemState = .disabled
    public var isDrawing = false
    public var selectedSection: SettingsSection = .effects
    public var helpQuery = ""
    public var failedHotkeys: Set<HotkeyAction> = []
    public var customSoundError = false
    /// The menu-bar icon is enabled but macOS is not showing it.
    public var menuBarIconHidden = false

    @ObservationIgnored public weak var actions: AppActions?
    /// Called after every change with (old, new).
    @ObservationIgnored public var onChange: ((MickeyDomain.Settings, MickeyDomain.Settings) -> Void)?

    @ObservationIgnored private let store: SettingsStore
    @ObservationIgnored private var pendingSave: DispatchWorkItem?

    public init(store: SettingsStore) {
        self.store = store
        settings = store.loadSettings()
        // Persist right away so settings migrated or repaired while loading are written back.
        store.saveSettings(settings)
    }

    public func update(_ transform: (inout MickeyDomain.Settings) -> Void) {
        var next = settings
        transform(&next)
        set(SettingsRules.normalize(old: settings, new: next))
    }

    /// Replaces settings after rules were applied elsewhere (e.g. hotkeys).
    public func set(_ next: MickeyDomain.Settings) {
        let old = settings
        guard next != old else { return }
        settings = next
        scheduleSave()
        onChange?(old, next)
    }

    public func binding<T>(_ keyPath: WritableKeyPath<MickeyDomain.Settings, T>) -> Binding<T> {
        Binding(get: { self.settings[keyPath: keyPath] }, set: { v in self.update { $0[keyPath: keyPath] = v } })
    }

    public func binding(_ item: MenuBarItem) -> Binding<Bool> {
        Binding(get: { SettingsRules.isOn(item, in: self.settings) },
                set: { v in self.set(SettingsRules.setting(item, to: v, in: self.settings)) })
    }

    public func perform(_ action: HotkeyAction) { set(SettingsRules.applying(action, to: settings)) }

    public func resetAllSettings() {
        let keepOnboarding = settings.general.hasCompletedOnboarding
        var fresh = MickeyDomain.Settings.defaults
        fresh.general.hasCompletedOnboarding = keepOnboarding
        set(fresh)
        flush()
    }

    public func resetHotkeys() { update { $0.hotkeys = HotkeyAction.defaultHotkeys } }
    public func clearHotkeys() { update { $0.hotkeys.removeAll() } }
    public func resetHotkey(_ action: HotkeyAction) {
        update { s in
            // The default may now belong to another action: free it first.
            for (other, combo) in s.hotkeys where other != action && combo == action.defaultHotkey { s.hotkeys[other] = nil }
            s.hotkeys[action] = action.defaultHotkey
        }
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        guard let actions else { return }
        loginItemState = actions.setLaunchAtLogin(enabled)
        update { $0.general.launchAtLogin = loginItemState == .enabled }
    }

    public func chooseCustomSound() {
        guard let ref = actions?.chooseCustomSound() else { return }
        customSoundError = false
        update { $0.click.customSound = ref }
    }

    public func flush() {
        pendingSave?.cancel()
        pendingSave = nil
        store.saveSettings(settings)
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        let item = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.flush() } }
        pendingSave = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
    }
}
