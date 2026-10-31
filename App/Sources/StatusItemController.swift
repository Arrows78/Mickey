import AppKit
import SwiftUI
import MickeyUI

/// Menu-bar icon opening the quick-toggle popover.
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()

    init(model: AppModel) {
        super.init()
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
