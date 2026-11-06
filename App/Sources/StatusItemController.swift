import AppKit
import SwiftUI
import MickeyDomain
import MickeyUI
import os

/// Menu-bar icon opening the quick-toggle popover.
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()

    init(model: AppModel) {
        super.init()
        item.autosaveName = "MickeyStatusItem"
        popover.behavior = .transient
        let host = NSHostingController(rootView: StatusPopoverView(model: model))
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: "Mickey")
            button.target = self
            button.action = #selector(togglePopover(_:))
        }
    }

    var isVisible: Bool {
        get { item.isVisible }
        set { if item.isVisible != newValue { item.isVisible = newValue } }
    }

    /// Greyed-out icon while the master switch is off.
    var isDimmed: Bool {
        get { item.button?.appearsDisabled ?? false }
        set { item.button?.appearsDisabled = newValue }
    }

    /// True when macOS keeps the icon off screen: crowded menu bar, notch, or a menu-bar manager.
    var isHiddenBySystem: Bool {
        guard item.isVisible, let window = item.button?.window else { return false }
        let onScreen = NSScreen.screens.contains { $0.frame.intersects(window.frame) }
        Self.log.notice("status item frame=\(NSStringFromRect(window.frame), privacy: .public) occlusion=\(window.occlusionState.rawValue, privacy: .public)")
        return !onScreen || !window.occlusionState.contains(.visible)
    }

    private static let log = Logger(subsystem: "dev.local.mickey", category: "menubar")

    var toolTip: String? {
        get { item.button?.toolTip }
        set { item.button?.toolTip = newValue }
    }

    /// Red record icon while a recording runs.
    var isRecording = false {
        didSet {
            item.button?.image = NSImage(systemSymbolName: isRecording ? "record.circle.fill" : "cursorarrow.rays",
                                         accessibilityDescription: isRecording ? tr("Mickey — recording") : "Mickey")
            item.button?.contentTintColor = isRecording ? .systemRed : nil
        }
    }

    func closePopover() { if popover.isShown { popover.performClose(nil) } }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
