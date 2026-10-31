import Carbon.HIToolbox
import Foundation
import MickeyDomain

/// Registers system-wide hotkeys with the Carbon event manager.
public final class HotkeyRegistry {
    public var onHotkey: ((HotkeyAction) -> Void)?

    private var refs: [HotkeyAction: EventHotKeyRef] = [:]
    private var handler: EventHandlerRef?
    private static let signature: OSType = 0x4D_4B_59_31 // "MKY1"
    nonisolated(unsafe) private static var current: HotkeyRegistry?

    public init() {}

    /// Replaces every registration. Returns actions whose combination the system refused.
    @discardableResult
    public func register(_ hotkeys: [HotkeyAction: KeyCombo]) -> [HotkeyAction] {
        unregisterAll()
        installHandlerIfNeeded()
        var failed: [HotkeyAction] = []
        for (index, action) in HotkeyAction.allCases.enumerated() {
            guard let combo = hotkeys[action] else { continue }
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: Self.signature, id: UInt32(index))
            let status = RegisterEventHotKey(combo.keyCode, Self.carbonModifiers(combo.modifiers), id,
                                             GetEventDispatcherTarget(), 0, &ref)
            if status == noErr, let ref { refs[action] = ref } else { failed.append(action) }
        }
        return failed
    }

    public func unregisterAll() {
        refs.values.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
    }

    static func carbonModifiers(_ m: KeyCombo.Modifiers) -> UInt32 {
        var r: UInt32 = 0
        if m.contains(.command) { r |= UInt32(cmdKey) }
        if m.contains(.option) { r |= UInt32(optionKey) }
        if m.contains(.control) { r |= UInt32(controlKey) }
        if m.contains(.shift) { r |= UInt32(shiftKey) }
        return r
    }

    private func installHandlerIfNeeded() {
        Self.current = self
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, _ in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            let index = Int(id.id)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard HotkeyAction.allCases.indices.contains(index) else { return }
                    HotkeyRegistry.current?.onHotkey?(HotkeyAction.allCases[index])
                }
            }
            return noErr
        }, 1, &spec, nil, &handler)
    }
}
