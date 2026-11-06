import SwiftUI
import MickeyDomain

struct AnnotationsPage: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "Annotations", subtitle: "Draw arrows, shapes and freehand notes on top of everything.")
            FeatureCard(title: "Screen Annotation", symbol: "pencil.tip.crop.circle",
                        subtitle: "Hold Fn (🌐) to draw, or use the Toggle Annotation Mode hotkey, or Start Drawing in the menu bar.",
                        isOn: model.binding(\.annotations.enabled)) {
                HStack {
                    Button(model.isDrawing ? "Stop Drawing" : "Start Drawing") { model.actions?.toggleDrawing() }
                        .help(model.tooltip(.toggleAnnotationMode, title: model.isDrawing ? "Stop drawing" : "Start drawing"))
                    Spacer()
                }
                ToggleRow(title: "Also hold Right Option (⌥) to draw",
                          detail: "Adds Right Option as a second hold-to-draw key. Off by default.",
                          isOn: model.binding(\.annotations.rightOptionTrigger))
                if model.settings.annotations.rightOptionTrigger &&
                    (model.settings.spotlight.holdKey == .rightOption || model.settings.click.tapKey == .rightOption) {
                    NoteView(text: "Right Option is also used by a spotlight or click-effect trigger.", warning: true)
                }
                PickerRow(title: "Default Tool", selection: model.binding(\.annotations.defaultTool), options: AnnotationTool.allCases) {
                    Label($0.title, systemImage: $0.symbolName)
                }
                ColorRow(title: "Color", color: model.binding(\.annotations.color))
                SliderRow(title: "Stroke Width", value: model.binding(\.annotations.strokeWidth), range: AnnotationSettings.strokeWidthRange)
                ColorRow(title: "Highlighter Color", color: model.binding(\.annotations.highlighterColor))
                SliderRow(title: "Highlighter Size", value: model.binding(\.annotations.highlighterSize), range: AnnotationSettings.highlighterSizeRange)
                SliderRow(title: "Text & Callout Size", value: model.binding(\.annotations.calloutSize), range: AnnotationSettings.calloutSizeRange)
                ToggleRow(title: "Auto-Fade", detail: "Each annotation disappears after a delay.", isOn: model.binding(\.annotations.autoFade))
                if model.settings.annotations.autoFade {
                    SliderRow(title: "Fade After", value: model.binding(\.annotations.autoFadeDelay),
                              range: AnnotationSettings.autoFadeDelayRange, step: 0.5, format: seconds)
                }
                ToggleRow(title: "Clear on Exit", detail: "Erase everything when leaving draw mode.", isOn: model.binding(\.annotations.clearOnExit))
                NoteView(text: "While drawing: F freehand · A arrow · R rectangle · C circle · L line · H highlighter · T text · N callout · ⌘Z undo · ⇧⌘Z redo · ⌘⌫ clear · Esc stop.")
            }
        }
    }
}

struct HotkeysPage: View {
    @Bindable var model: AppModel
    @State private var confirmReset = false
    @State private var confirmClear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "Hotkeys", subtitle: "Global shortcuts that work from any app. Each defaults to ⌃⌥⌘ plus a letter.")
            FeatureCard(title: "Keyboard Shortcuts", symbol: "keyboard") {
                ForEach(HotkeyAction.allCases) { action in
                    let others = model.settings.hotkeys.filter { $0.key != action }
                    let conflict = model.settings.hotkeys[action].flatMap { HotkeyConflict.check($0, otherActions: others) }
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.title)
                            Text(action.detail).font(.caption).foregroundStyle(.secondary)
                            if let conflict {
                                Label(conflict.message, systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption).foregroundStyle(conflict.blocks ? .red : .orange)
                            } else if model.failedHotkeys.contains(action) {
                                Label("macOS refused this shortcut. Pick another one.", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption).foregroundStyle(.red)
                            }
                        }
                        Spacer()
                        HotkeyRecorder(combo: model.binding(\.hotkeys[action]),
                                       onRecording: { model.actions?.setHotkeyRecording($0) },
                                       otherActions: others)
                        Button { model.resetHotkey(action) } label: { Image(systemName: "arrow.counterclockwise") }
                            .buttonStyle(.plain).foregroundStyle(.secondary)
                            .help("Restore the default (\(KeyboardLayout.displayString(KeyboardLayout.defaultHotkey(action))))")
                            .accessibilityLabel("Restore default shortcut")
                            .opacity(model.settings.hotkeys[action] == KeyboardLayout.defaultHotkey(action) ? 0 : 1)
                            .disabled(model.settings.hotkeys[action] == KeyboardLayout.defaultHotkey(action))
                    }
                    if action != HotkeyAction.allCases.last { Divider() }
                }
            }
            FeatureCard(title: "How Hotkeys Work", symbol: "info.circle") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("• Click a field, then press the combination. Esc cancels, Delete clears, ↺ restores the default.")
                    Text("• Use Control, or Command or Option with another modifier. F-keys work alone.")
                    Text("• Letters follow your keyboard layout: ⌃⌥⌘M is the key marked M, on AZERTY too.")
                    Text("• Combinations already used by macOS or by another action are refused; common app shortcuts get a warning.")
                    Text("• Shortcuts set by other apps (Raycast, Rectangle…) can't be detected: if one stops working, pick another.")
                    Text("• A shortcut set here is taken from every other app, so avoid ones you use elsewhere.")
                    Text("• Annotations also work without a hotkey: hold Fn (🌐).")
                }
                .font(.callout).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Clear All") { confirmClear = true }.help("Remove every shortcut")
                Button("Reset to Defaults") { confirmReset = true }.help("Give every action its ⌃⌥⌘ default back")
            }
        }
        .confirmationDialog("Restore the default shortcuts?", isPresented: $confirmReset) {
            Button("Reset to Defaults", role: .destructive) { model.resetHotkeys() }
        } message: {
            Text("Every action gets its ⌃⌥⌘ default back; your custom shortcuts are replaced.")
        }
        .confirmationDialog("Clear all shortcuts?", isPresented: $confirmClear) {
            Button("Clear All Shortcuts", role: .destructive) { model.clearHotkeys() }
        } message: {
            Text("No action will have a shortcut. Reset to Defaults brings them back.")
        }
    }
}

struct GeneralPage: View {
    @Bindable var model: AppModel
    @State private var confirmReset = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "General", subtitle: "Startup, visibility and menu-bar contents.")
            FeatureCard(title: "Startup & Visibility", symbol: "macwindow") {
                ToggleRow(title: "Launch at Login", detail: "Start Mickey automatically when you log in.",
                          isOn: Binding(get: { model.loginItemState == .enabled || model.loginItemState == .requiresApproval },
                                        set: { model.setLaunchAtLogin($0) }))
                switch model.loginItemState {
                case .requiresApproval:
                    HStack {
                        NoteView(text: "Waiting for your approval in System Settings › General › Login Items.", warning: true)
                        Button("Open System Settings") { model.actions?.openLoginItemsSettings() }
                    }
                case .failed(let message): NoteView(text: message, warning: true)
                default: EmptyView()
                }
                ToggleRow(title: "Show in Menu Bar", detail: "Display the Mickey icon in the menu bar.", isOn: model.binding(\.general.showInMenuBar))
                ToggleRow(title: "Show in Dock", detail: "Display the Mickey icon in the Dock.", isOn: model.binding(\.general.showInDock))
                NoteView(text: "At least one of Menu Bar or Dock stays on so Mickey is always reachable.")
                if model.menuBarIconHidden && !model.settings.general.showInDock {
                    NoteView(text: "macOS is not showing the Mickey icon: the menu bar may be full, hidden behind the camera notch, or managed by another app. Turn on Show in Dock for a second way in.",
                             warning: true)
                }
            }
            PresetsCard(model: model)
            FeatureCard(title: "Menu Bar Contents", symbol: "menubar.rectangle",
                        subtitle: "Choose which quick toggles appear when you click the menu-bar icon.") {
                ForEach(MenuBarItem.allCases) { item in
                    Toggle(item.title, isOn: Binding(
                        get: { model.settings.general.menuBarItems.contains(item) },
                        set: { on in model.update { if on { $0.general.menuBarItems.insert(item) } else { $0.general.menuBarItems.remove(item) } } }))
                }
            }
            FeatureCard(title: "About", symbol: "info.circle") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(appVersion).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
            FeatureCard(title: "Backup", symbol: "square.and.arrow.up.on.square",
                        subtitle: "Save your settings to a file, or load them on another Mac. Your custom click sound stays on this Mac.") {
                HStack {
                    Button("Export Settings…") { model.exportSettings() }.help("Save every setting to a JSON file")
                    Button("Import Settings…") { model.importSettings() }.help("Replace your settings with an exported file")
                    Spacer()
                }
                if let message = model.transferMessage { NoteView(text: message) }
            }
            FeatureCard(title: "Reset", symbol: "arrow.counterclockwise") {
                HStack {
                    Text("Restore every setting to its default value.").foregroundStyle(.secondary)
                    Spacer()
                    Button("Reset All Settings…") { confirmReset = true }
                }
            }
        }
        .confirmationDialog("Reset all settings?", isPresented: $confirmReset) {
            Button("Reset All Settings", role: .destructive) { model.resetAllSettings() }
        } message: {
            Text("All settings, including shortcuts, return to their defaults.")
        }
    }
}

struct AdvancedPage: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "Advanced", subtitle: "Performance tuning.")
            FeatureCard(title: "Performance", symbol: "speedometer") {
                SliderRow(title: "Update Rate", value: model.binding(\.general.updateRateHz), range: GeneralSettings.updateRateRange,
                          step: 10, format: { "\(Int($0)) fps" })
                NoteView(text: "Higher rates make effects smoother but use more CPU.")
            }
            AutoModeCard(model: model)
        }
    }
}

struct SupportPage: View {
    @Bindable var model: AppModel
    @State private var copied = false

    private func copyDiagnostics() {
        let info = ProcessInfo.processInfo
        let permissions = Permission.allCases.map { "\($0.title): \(model.permissions[$0].map { "\($0)" } ?? "unknown")" }
        var settings = model.settings
        settings.click.customSound = nil // a bookmark identifies a file on this Mac
        let json = (try? JSONEncoder().encode(settings)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let report = (["Mickey \(appVersion)", "macOS \(info.operatingSystemVersionString)"] + permissions + ["Settings: \(json)"])
            .joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
        copied = true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "Support", subtitle: "About this build.")
            FeatureCard(title: "About", symbol: "info.circle") {
                Text("Mickey — cursor highlighter & presentation toolkit.")
                Text("Version \(appVersion)")
                    .foregroundStyle(.secondary)
                Text("Runs entirely on your Mac: no account, no network access, no data collection.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            FeatureCard(title: "Report a Problem", symbol: "ladybug") {
                Text("Copy a summary of your setup (version, macOS, permissions, settings) to paste into a bug report. It contains no personal data.")
                    .font(.callout).foregroundStyle(.secondary)
                HStack {
                    Button(copied ? "Copied" : "Copy Diagnostics") { copyDiagnostics() }
                    Button("Show Recordings") { model.actions?.revealRecordings() }
                }
            }
            FeatureCard(title: "Permissions", symbol: "lock.shield") {
                ForEach(Permission.allCases) { PermissionRow(model: model, permission: $0) }
            }
        }
    }
}

/// "0.1.0 (1)" from the app bundle, or "dev" when run outside one.
var appVersion: String {
    let info = Bundle.main.infoDictionary
    guard let short = info?["CFBundleShortVersionString"] as? String else { return "dev" }
    return info?["CFBundleVersion"].map { "\(short) (\($0))" } ?? short
}
