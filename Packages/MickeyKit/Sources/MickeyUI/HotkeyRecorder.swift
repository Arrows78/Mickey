import AppKit
import Carbon.HIToolbox
import SwiftUI
import MickeyDomain

/// Click-to-record shortcut field. Esc cancels, Delete clears.
struct HotkeyRecorder: View {
    @Binding var combo: KeyCombo?
    var onRecording: (Bool) -> Void = { _ in }
    /// Shortcuts of the other actions, to refuse duplicates.
    var otherActions: [HotkeyAction: KeyCombo] = [:]

    @State private var recording = false
    @State private var monitor: Any?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 4) {
                Button { recording ? stop() : start() } label: {
                    Text(recording ? "Press shortcut…" : (combo?.displayString ?? "Record Shortcut"))
                        .frame(minWidth: 130)
                        .foregroundStyle(combo == nil && !recording ? .secondary : .primary)
                }
                if combo != nil && !recording {
                    Button { combo = nil } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Clear shortcut")
                }
            }
            if let error { Text(error).font(.caption2).foregroundStyle(.orange) }
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        error = nil
        recording = true
        onRecording(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if recording { onRecording(false) }
        recording = false
    }

    private func handle(_ event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_Escape: stop(); return
        case kVK_Delete, kVK_ForwardDelete: combo = nil; stop(); return
        default: break
        }
        let flags = event.modifierFlags
        var mods: KeyCombo.Modifiers = []
        if flags.contains(.control) { mods.insert(.control) }
        if flags.contains(.option) { mods.insert(.option) }
        if flags.contains(.shift) { mods.insert(.shift) }
        if flags.contains(.command) { mods.insert(.command) }
        let candidate = KeyCombo(keyCode: UInt32(event.keyCode), modifiers: mods, keyLabel: Self.label(for: event))
        switch candidate.validate() {
        case .needsModifier?: error = "Add Control, Option or Command."
        case .commandOnlyReserved?: error = "⌘ + key alone is reserved by macOS; add another modifier."
        case .shiftOnly?: error = "Shift alone is not enough; add another modifier."
        case nil:
            // Refuse combinations that could never fire; softer conflicts are shown next to the row.
            if let conflict = HotkeyConflict.check(candidate, otherActions: otherActions), conflict.blocks {
                error = conflict.message
            } else {
                combo = candidate
                stop()
            }
        }
    }

    static func label(for event: NSEvent) -> String {
        let named: [Int: String] = [kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_LeftArrow: "←", kVK_RightArrow: "→",
                                    kVK_UpArrow: "↑", kVK_DownArrow: "↓", kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
                                    kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7",
                                    kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12", kVK_F13: "F13",
                                    kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20"]
        if let n = named[Int(event.keyCode)] { return n }
        return (event.charactersIgnoringModifiers ?? "?").uppercased()
    }
}
