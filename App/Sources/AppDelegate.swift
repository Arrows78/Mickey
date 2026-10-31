import AppKit
import MickeyAnnotations
import MickeyDomain
import MickeyEffects
import MickeyPersistence
import MickeySystem
import MickeyUI

/// Composition root: owns every subsystem and routes input, hotkeys and settings changes between them.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = UserDefaultsSettingsStore()
    private lazy var model = AppModel(store: store)
    private let input = InputMonitor()
    private var interaction = InteractionEngine()
    private var effects: EffectsEngine?
    private let annotations = AnnotationController()
    private let hotkeys = HotkeyRegistry()
    private let loginItems = LoginItemService()
    private let cursor = CursorVisibility()
    private let sound = SoundPlayer(defaultSoundURL: Bundle.main.url(forResource: "click", withExtension: "wav"))
    private let windows = WindowCoordinator()
    private lazy var review = ReviewTracker(store: store)
    private var statusItem: StatusItemController?
    private var recordingHotkey = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make()
        effects = EffectsEngine()
        model.actions = self
        model.onChange = { [weak self] old, new in self?.apply(new, old: old) }
        annotations.onDrawingChanged = { [weak self] drawing in self?.model.isDrawing = drawing }
        annotations.onSettingsEdited = { [weak self] edited in self?.model.update { $0.annotations = edited } }
        hotkeys.onHotkey = { [weak self] action in self?.handle(action) }
        input.onTick = { [weak self] snapshot in self?.tick(snapshot) }
        input.onMouseDown = { [weak self] point in self?.mouseDown(at: point) }
        input.onScroll = { [weak self] in self?.interaction.scrolled() }
        windows.onSettingsBecameKey = { [weak self] in self?.considerReview() }
        statusItem = StatusItemController(model: model)

        // The login item may have been changed in System Settings since the last run.
        model.loginItemState = loginItems.state
        model.update { $0.general.launchAtLogin = self.loginItems.state == .enabled }

        apply(model.settings, old: nil)
        input.start()
        review.start(isActive: { [weak self] in self?.model.settings.general.masterEnabled ?? false })
        if !model.settings.general.hasCompletedOnboarding {
            windows.showOnboarding(model: model)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.flush()
        input.stop()
        hotkeys.unregisterAll()
        cursor.set(hidden: false)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings(nil)
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: Settings → subsystems

    private func apply(_ s: MickeyDomain.Settings, old: MickeyDomain.Settings?) {
        input.rateHz = s.general.updateRateHz
        if (old == nil || old?.hotkeys != s.hotkeys) && !recordingHotkey { registerHotkeys() }
        annotations.apply(s.annotations)
        if old == nil || old?.click.customSound != s.click.customSound {
            model.customSoundError = !sound.configure(custom: s.click.customSound)
        }
        if old == nil || old?.general.showInDock != s.general.showInDock {
            NSApp.setActivationPolicy(s.general.showInDock ? .regular : .accessory)
        }
        statusItem?.isVisible = s.general.showInMenuBar
        statusItem?.isDimmed = !s.general.masterEnabled
    }

    private func registerHotkeys() {
        model.failedHotkeys = Set(hotkeys.register(model.settings.hotkeys))
    }

    // MARK: Input

    private func tick(_ snapshot: InputSnapshot) {
        interaction.tick(snapshot, settings: model.settings).forEach(run)
        let s = model.settings
        effects?.render(pointer: snapshot.position, time: snapshot.time, settings: s,
                        spotlightVisible: interaction.spotlightVisible(s))
        cursor.set(hidden: interaction.shouldHideCursor(s))
    }

    private func mouseDown(at point: CGPoint) {
        let commands = interaction.mouseDown(at: point, settings: model.settings)
        // Clicks on the drawing canvas are strokes, not clicks to highlight.
        guard !annotations.isDrawing else { return }
        commands.forEach(run)
    }

    private func run(_ command: InteractionCommand) {
        let s = model.settings
        switch command {
        case .clickEffect(let p): effects?.spawnClick(at: p, settings: s.click)
        case .clickSound: sound.play(volume: s.click.soundVolume)
        case .locate(let p): effects?.playLocator(at: p, color: s.ring.color)
        case .disableSpotlight: model.update { $0.spotlight.enabled = false }
        case .beginMomentaryDrawing: annotations.enter(momentary: true)
        case .endMomentaryDrawing: annotations.endMomentary()
        }
    }

    private func handle(_ action: HotkeyAction) {
        switch action {
        case .showClickEffect:
            interaction.showClickEffect(settings: model.settings).forEach(run)
        case .toggleAnnotationMode:
            model.perform(action)
            annotations.toggle()
        default:
            model.perform(action)
        }
    }

    private func considerReview() {
        let s = model.settings
        review.requestIfAppropriate(onboardingComplete: s.general.hasCompletedOnboarding,
                                    settingsWindowFrontmost: windows.isSettingsKey,
                                    spotlightVisible: interaction.spotlightVisible(s),
                                    drawing: annotations.isDrawing,
                                    presentingFrom: windows.settingsViewController)
    }
}

extension AppDelegate: AppActions {
    func chooseCustomSound() -> SoundReference? { SoundPlayer.chooseCustomSound() }

    func setLaunchAtLogin(_ enabled: Bool) -> LoginItemState { loginItems.setEnabled(enabled) }

    func openLoginItemsSettings() { loginItems.openSystemSettings() }

    func toggleDrawing() {
        statusItem?.closePopover()
        annotations.toggle()
    }

    func showSettings(_ section: SettingsSection?) {
        statusItem?.closePopover()
        if let section { model.selectedSection = section }
        windows.showSettings(model: model)
    }

    func previewClickEffect() {
        effects?.spawnClick(at: NSEvent.mouseLocation, settings: model.settings.click)
    }

    func quit() {
        model.flush()
        NSApp.terminate(nil)
    }

    func open(_ url: URL) { NSWorkspace.shared.open(url) }

    /// Registered hotkeys would swallow the combination being recorded, so they pause meanwhile.
    func setHotkeyRecording(_ recording: Bool) {
        recordingHotkey = recording
        if recording { hotkeys.unregisterAll() } else { registerHotkeys() }
    }
}
