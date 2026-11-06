import AppKit
import SwiftUI
import MickeyDomain
import MickeyUI

/// Titled panel that closes on Escape and survives app deactivation.
final class EscapeClosingPanel: NSPanel {
    override func cancelOperation(_ sender: Any?) { performClose(sender) }
}

/// Creates and reuses the settings and onboarding windows.
final class WindowCoordinator: NSObject, NSWindowDelegate {
    var onSettingsBecameKey: (() -> Void)?

    private var settingsPanel: NSPanel?
    private var onboardingPanel: NSPanel?

    var isSettingsKey: Bool { settingsPanel?.isKeyWindow ?? false }
    var settingsViewController: NSViewController? { settingsPanel?.contentViewController }

    func showSettings(model: AppModel) {
        let panel = settingsPanel ?? makeSettingsPanel(model: model)
        settingsPanel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func showOnboarding(model: AppModel) {
        guard onboardingPanel == nil else { onboardingPanel?.makeKeyAndOrderFront(nil); return }
        let view = OnboardingView(model: model) { [weak self] in
            self?.onboardingPanel?.close()
            self?.onboardingPanel = nil
        }
        let panel = makePanel(title: "Welcome to Mickey", styleMask: [.titled, .closable, .fullSizeContentView])
        panel.titlebarAppearsTransparent = true
        panel.contentViewController = NSHostingController(rootView: view)
        panel.center()
        onboardingPanel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func makeSettingsPanel(model: AppModel) -> NSPanel {
        let panel = makePanel(title: tr("Mickey Settings"), styleMask: [.titled, .closable, .miniaturizable, .resizable])
        panel.contentViewController = NSHostingController(rootView: SettingsRootView(model: model))
        panel.setContentSize(NSSize(width: 940, height: 720))
        panel.setFrameAutosaveName("MickeySettings")
        panel.center()
        panel.delegate = self
        return panel
    }

    private func makePanel(title: String, styleMask: NSWindow.StyleMask) -> NSPanel {
        let panel = EscapeClosingPanel(contentRect: .zero, styleMask: styleMask, backing: .buffered, defer: false)
        panel.title = title
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        return panel
    }

    func windowDidBecomeKey(_ notification: Notification) {
        guard notification.object as? NSPanel === settingsPanel else { return }
        // Let the window settle before anything else is presented over it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            MainActor.assumeIsolated { if self?.isSettingsKey == true { self?.onSettingsBecameKey?() } }
        }
    }
}
