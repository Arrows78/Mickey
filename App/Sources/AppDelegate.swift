import AppKit
import MickeyAnnotations
import MickeyDomain
import MickeyEffects
import MickeyPersistence
import MickeyStudio
import MickeySystem
import MickeyUI

/// Composition root: owns every subsystem and routes input, hotkeys and settings changes between them.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = UserDefaultsSettingsStore(keyCode: KeyboardLayout.keyCode(for:))
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
    private let studio = StudioCoordinator()
    private let appWatcher = AppWatcher()
    private var autoMode = AutoModeSession()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let launchedAsLoginItem = Self.isLaunchingAsLoginItem()
        ToolTips.shortenDelay()
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
        windows.onSettingsBecameKey = { [weak self] in self?.considerReview(); self?.refreshPermissions() }
        statusItem = StatusItemController(model: model)
        wireStudio()

        // The login item may have been changed in System Settings since the last run.
        model.loginItemState = loginItems.state
        model.update { $0.general.launchAtLogin = self.loginItems.state == .enabled }

        apply(model.settings, old: nil)
        input.start()
        checkMenuBarIcon()
        review.start(isActive: { [weak self] in self?.model.settings.general.masterEnabled ?? false })
        if !model.settings.general.hasCompletedOnboarding {
            windows.showOnboarding(model: model)
        } else if !launchedAsLoginItem {
            // Started at login: stay in the menu bar. Started by the user: show Settings.
            windows.showSettings(model: model)
        }
    }

    /// True when macOS opened the app as a login item rather than the user launching it.
    /// Only meaningful while the launch Apple Event is being handled.
    private static func isLaunchingAsLoginItem() -> Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventID == kAEOpenApplication else { return false }
        return event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    /// A running recording is finished before quitting, otherwise the movie file would be unreadable.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard studio.isRecording else { return .terminateNow }
        let reply = TerminationReply()
        studio.stopRecording { reply.send() }
        // Never block quitting for long if writing hangs.
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { MainActor.assumeIsolated { reply.send() } }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Automatic Mode's preset is not saved as the user's settings.
        model.set(autoMode.settingsToPersist(model.settings))
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
        // Turning Mickey off stops everything: drawing and its annotations, and a running recording (saved).
        if old?.general.masterEnabled != s.general.masterEnabled {
            annotations.setSuspended(!s.general.masterEnabled)
            if !s.general.masterEnabled && studio.isRecording { studio.stopRecording {} }
        }
        if (old == nil || old?.hotkeys != s.hotkeys) && !recordingHotkey { registerHotkeys() }
        annotations.apply(s.annotations)
        if old == nil || old?.click.customSound != s.click.customSound, !sound.configure(custom: s.click.customSound) {
            // A moved or deleted file falls back to the default sound and the choice is cleared.
            model.customSoundError = true
            model.update { $0.click.customSound = nil }
        }
        if old == nil || old?.general.showInDock != s.general.showInDock {
            NSApp.setActivationPolicy(s.general.showInDock ? .regular : .accessory)
        }
        if statusItem?.isVisible != s.general.showInMenuBar {
            statusItem?.isVisible = s.general.showInMenuBar
            if old != nil { checkMenuBarIcon() }
        }
        statusItem?.isDimmed = !s.general.masterEnabled
        let toggle = s.hotkeys[.toggleMaster].map { " — " + trf(s.general.masterEnabled ? "%@ to turn off" : "%@ to turn on", KeyboardLayout.displayString($0)) } ?? ""
        statusItem?.toolTip = tr(s.general.masterEnabled ? "Mickey is on" : "Mickey is off") + toggle
        studio.apply(s, old: old)
        if old?.autoMode != s.autoMode {
            if s.autoMode.enabled { appWatcher.start() } else { appWatcher.stop() }
            updateAutoMode(running: appWatcher.running)
        }
    }

    // MARK: Presenter tools

    private func wireStudio() {
        studio.onMessage = { [weak self] message in self?.model.studioMessage = message }
        studio.onRecordingChanged = { [weak self] recording, start in
            self?.model.recordingClock = recording ? start.map { RecordingClock(startedAt: $0) } : nil
            self?.statusItem?.isRecording = recording
        }
        studio.onRecordingPauseChanged = { [weak self] paused in
            guard let self else { return }
            if paused { model.recordingClock?.pause(at: Date()) } else { model.recordingClock?.resume(at: Date()) }
            statusItem?.isPaused = paused
        }
        studio.onRecordingSaved = { [weak self] url in
            self?.model.lastRecordingURL = url
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
        appWatcher.onChange = { [weak self] running in self?.updateAutoMode(running: running) }
        refreshPermissions()
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPermissions() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.studio.screensChanged() }
        }
    }

    /// Re-reads permission states; tools waiting for one retry once it is granted.
    private func refreshPermissions() {
        let fresh = Dictionary(uniqueKeysWithValues: Permission.allCases.map { ($0, Permissions.status($0)) })
        let newlyGranted = fresh.contains { $0.value == .granted && model.permissions[$0.key] != .granted }
        model.permissions = fresh
        if newlyGranted {
            model.studioMessage = nil
            studio.permissionsChanged()
        }
    }

    /// Applies the Automatic Mode preset while a watched app runs, and restores the previous settings
    /// afterwards unless the user changed something in the meantime.
    private func updateAutoMode(running: Set<String>) {
        if let next = autoMode.update(settings: model.settings, running: running) { model.set(next) }
    }

    /// The menu bar takes a moment to lay out new items, so the check runs shortly after launch.
    private func checkMenuBarIcon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, let statusItem = self.statusItem else { return }
                self.model.menuBarIconHidden = statusItem.isHiddenBySystem
            }
        }
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
        studio.tick(pointer: snapshot.position)
        cursor.set(hidden: interaction.shouldHideCursor(s))
    }

    private func mouseDown(at point: CGPoint) {
        let commands = interaction.mouseDown(at: point, settings: model.settings)
        // Clicks on the drawing canvas are strokes, not clicks to highlight.
        guard !annotations.isDrawing else { return }
        studio.registerClick()
        commands.forEach(run)
    }

    private func run(_ command: InteractionCommand) {
        let s = model.settings
        switch command {
        case .clickEffect(let p): effects?.spawnClick(at: p, settings: s.click)
        case .clickSound: sound.play(volume: s.click.soundVolume)
        case .locate(let p): effects?.playLocator(at: p, color: s.ring.color, style: s.shake.style)
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
        case .toggleRecording:
            toggleRecording()
        case .togglePauseRecording:
            togglePauseRecording()
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

/// Answers a `.terminateLater` exactly once, after it was returned.
private final class TerminationReply {
    private var sent = false

    func send() {
        guard !sent else { return }
        sent = true
        DispatchQueue.main.async { MainActor.assumeIsolated { NSApp.reply(toApplicationShouldTerminate: true) } }
    }
}

extension AppDelegate: AppActions {
    func chooseCustomSound() -> SoundReference? { SoundPlayer.chooseCustomSound() }

    func setLaunchAtLogin(_ enabled: Bool) -> LoginItemState { loginItems.setEnabled(enabled) }

    func openLoginItemsSettings() { loginItems.openSystemSettings() }

    func toggleDrawing() {
        statusItem?.closePopover()
        handle(.toggleAnnotationMode)
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

    func request(_ permission: Permission) {
        Permissions.request(permission) { [weak self] _ in self?.refreshPermissions() }
    }

    func toggleRecording() {
        statusItem?.closePopover()
        // Like every other tool, starting a recording turns Mickey on.
        if !studio.isRecording && !model.settings.general.masterEnabled { model.update { $0.general.masterEnabled = true } }
        studio.toggleRecording(settings: model.settings.recorder)
    }

    func togglePauseRecording() {
        studio.togglePause()
    }

    func revealRecordings() {
        let folder = StudioCoordinator.recordingsFolder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let last = model.lastRecordingURL { NSWorkspace.shared.activateFileViewerSelecting([last]) } else { NSWorkspace.shared.open(folder) }
    }

    func chooseSettingsExportURL() -> URL? {
        let panel = NSSavePanel()
        panel.title = tr("Export Mickey Settings")
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Mickey Settings.json"
        NSApp.activate(ignoringOtherApps: true)
        return panel.runModal() == .OK ? panel.url : nil
    }

    func chooseSettingsImportURL() -> URL? {
        let panel = NSOpenPanel()
        panel.title = tr("Import Mickey Settings")
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Registered hotkeys would swallow the combination being recorded, so they pause meanwhile.
    func setHotkeyRecording(_ recording: Bool) {
        recordingHotkey = recording
        if recording { hotkeys.unregisterAll() } else { registerHotkeys() }
    }
}
