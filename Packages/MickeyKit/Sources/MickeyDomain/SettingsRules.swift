import Foundation

/// Cross-field rules applied to every settings change, whatever its origin (UI, popover, hotkey).
public enum SettingsRules {
    /// Returns `new` adjusted so that it is consistent, given the previous value `old`.
    public static func normalize(old: Settings, new: Settings) -> Settings {
        var s = new.clamped()

        // An effect switched on while the master switch is off turns the master switch on.
        if !s.general.masterEnabled && anyEffectTurnedOn(old: old, new: s) {
            s.general.masterEnabled = true
        }

        // "Hold a key to show" and "turn off when moving" are mutually exclusive; the latest change wins.
        if s.spotlight.holdKey != nil && s.spotlight.dismissOnMove {
            if old.spotlight.holdKey != s.spotlight.holdKey {
                s.spotlight.dismissOnMove = false
            } else {
                s.spotlight.holdKey = nil
            }
        }

        // The app must stay reachable from the menu bar or the Dock.
        if !s.general.showInMenuBar && !s.general.showInDock {
            if old.general.showInMenuBar { s.general.showInDock = true } else { s.general.showInMenuBar = true }
        }
        return s
    }

    static func anyEffectTurnedOn(old: Settings, new: Settings) -> Bool {
        let pairs: [(Bool, Bool)] = [
            (old.spotlight.enabled, new.spotlight.enabled),
            (old.ring.enabled, new.ring.enabled),
            (old.click.feedbackEnabled, new.click.feedbackEnabled),
            (old.click.soundEnabled, new.click.soundEnabled),
            (old.trail.enabled, new.trail.enabled),
            (old.shake.enabled, new.shake.enabled),
            (old.annotations.enabled, new.annotations.enabled),
        ]
        return pairs.contains { !$0.0 && $0.1 }
    }

    /// Settings change implied by a hotkey. `showClickEffect`, `toggleRecording` and `toggleAnnotationMode` are
    /// runtime commands and leave settings untouched, except that drawing needs annotations and Mickey on.
    /// Presenter tools (keystrokes, zoom, loupe, focus, camera, captions) do not depend on the master switch.
    public static func applying(_ action: HotkeyAction, to settings: Settings) -> Settings {
        var s = settings
        switch action {
        case .toggleMaster: s.general.masterEnabled.toggle()
        case .toggleSpotlight: s.spotlight.enabled.toggle()
        case .toggleRing: s.ring.enabled.toggle()
        case .toggleTrail: s.trail.enabled.toggle()
        case .toggleClickFeedback: s.click.feedbackEnabled.toggle()
        case .toggleClickSound: s.click.soundEnabled.toggle()
        case .toggleShakeToLocate: s.shake.enabled.toggle()
        case .toggleAnnotationMode: s.annotations.enabled = true; s.general.masterEnabled = true
        case .toggleKeystrokes: s.keystrokes.enabled.toggle()
        case .toggleLiveZoom: s.zoom.enabled.toggle()
        case .toggleLoupe: s.loupe.enabled.toggle()
        case .toggleFocus: s.focus.enabled.toggle()
        case .toggleCameraBubble: s.camera.enabled.toggle()
        case .toggleCaptions: s.captions.enabled.toggle()
        case .showClickEffect, .toggleRecording: break
        }
        return normalize(old: settings, new: s)
    }

    public static func isOn(_ item: MenuBarItem, in s: Settings) -> Bool {
        switch item {
        case .spotlight: s.spotlight.enabled
        case .ring: s.ring.enabled
        case .clickFeedback: s.click.feedbackEnabled
        case .clickSound: s.click.soundEnabled
        case .trail: s.trail.enabled
        case .shake: s.shake.enabled
        case .annotations: s.annotations.enabled
        case .keystrokes: s.keystrokes.enabled
        case .liveZoom: s.zoom.enabled
        case .loupe: s.loupe.enabled
        case .focus: s.focus.enabled
        case .cameraBubble: s.camera.enabled
        case .captions: s.captions.enabled
        }
    }

    public static func setting(_ item: MenuBarItem, to value: Bool, in s: Settings) -> Settings {
        var n = s
        switch item {
        case .spotlight: n.spotlight.enabled = value
        case .ring: n.ring.enabled = value
        case .clickFeedback: n.click.feedbackEnabled = value
        case .clickSound: n.click.soundEnabled = value
        case .trail: n.trail.enabled = value
        case .shake: n.shake.enabled = value
        case .annotations: n.annotations.enabled = value
        case .keystrokes: n.keystrokes.enabled = value
        case .liveZoom: n.zoom.enabled = value
        case .loupe: n.loupe.enabled = value
        case .focus: n.focus.enabled = value
        case .cameraBubble: n.camera.enabled = value
        case .captions: n.captions.enabled = value
        }
        return normalize(old: s, new: n)
    }

    /// Warnings displayed next to trigger-key pickers.
    public static func triggerKeyNotes(for key: TriggerKey?, role: TriggerRole, settings s: Settings) -> [String] {
        guard let key else { return [] }
        var notes: [String] = []
        if let caveat = key.caveat { notes.append(caveat) }
        switch role {
        case .spotlightHold:
            if s.click.tapKey == key {
                notes.append("This key is also the click-effect tap key: a quick tap flashes the effect, holding it shows the spotlight.")
            }
        case .clickTap:
            if s.spotlight.holdKey == key {
                notes.append("This key also reveals the spotlight when held: a quick tap flashes the effect, holding it shows the spotlight.")
            }
        }
        if key == .rightOption && s.annotations.rightOptionTrigger {
            notes.append("Right Option is also the optional annotation trigger. Pick another key if you use both.")
        }
        return notes
    }

    public enum TriggerRole: Sendable { case spotlightHold, clickTap }
}
