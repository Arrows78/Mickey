import AppKit

/// macOS waits about two seconds before showing a tooltip, which is far too long for a settings window made of
/// icon buttons and toggles. AppKit's tooltip manager has no public setting for it (`NSInitialToolTipDelay` is
/// ignored for SwiftUI's `.help`), so the delay is set on the manager itself.
///
/// This relies on a private AppKit class: every step is checked and a missing class or selector leaves the
/// system delay in place.
enum ToolTips {
    /// Delay before a tooltip appears, in seconds.
    static let delay: TimeInterval = 0.35

    static func shortenDelay() {
        let setter = Selector(("setInitialToolTipDelay:"))
        guard let type = NSClassFromString("NSToolTipManager") as? NSObject.Type,
              type.responds(to: Selector(("sharedToolTipManager"))),
              let manager = type.perform(Selector(("sharedToolTipManager")))?.takeUnretainedValue() as? NSObject,
              manager.responds(to: setter)
        else { return }
        manager.setValue(delay, forKey: "initialToolTipDelay")
    }
}
