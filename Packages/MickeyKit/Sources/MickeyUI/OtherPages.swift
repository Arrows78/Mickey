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
                NoteView(text: "While drawing: F freehand · A arrow · R rectangle · C circle · L line · H highlighter · T text · N callout · ⌘Z undo · ⌘⌫ clear · Esc stop.")
            }
        }
    }
}

struct HotkeysPage: View {
    @Bindable var model: AppModel
    @State private var confirmReset = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "Hotkeys", subtitle: "Global shortcuts that work from any app. None are set by default.")
            FeatureCard(title: "Keyboard Shortcuts", symbol: "keyboard") {
                ForEach(HotkeyAction.allCases) { action in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.title)
                            Text(action.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if model.failedHotkeys.contains(action) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                                .help("macOS refused this shortcut. It may be used by another app.")
                        }
                        HotkeyRecorder(combo: model.binding(\.hotkeys[action]), onRecording: { model.actions?.setHotkeyRecording($0) })
                    }
                    if action != HotkeyAction.allCases.last { Divider() }
                }
            }
            FeatureCard(title: "How Hotkeys Work", symbol: "info.circle") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("• Click a field, then press the combination. Esc cancels, Delete clears.")
                    Text("• Use at least Control or Option, or Command with another modifier. F-keys work alone.")
                    Text("• A shortcut set here is taken from every other app, so avoid ones you use elsewhere.")
                    Text("• Annotations also work without a hotkey: hold Fn (🌐).")
                }
                .font(.callout).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Reset to Defaults") { confirmReset = true }
            }
        }
        .confirmationDialog("Clear all shortcuts?", isPresented: $confirmReset) {
            Button("Clear All Shortcuts", role: .destructive) { model.resetHotkeys() }
        } message: {
            Text("Every custom keyboard shortcut will be removed.")
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
            }
            FeatureCard(title: "Menu Bar Contents", symbol: "menubar.rectangle",
                        subtitle: "Choose which quick toggles appear when you click the menu-bar icon.") {
                ForEach(MenuBarItem.allCases) { item in
                    Toggle(item.title, isOn: Binding(
                        get: { model.settings.general.menuBarItems.contains(item) },
                        set: { on in model.update { if on { $0.general.menuBarItems.insert(item) } else { $0.general.menuBarItems.remove(item) } } }))
                }
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
        }
    }
}

struct SupportPage: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "Support", subtitle: "About this build.")
            FeatureCard(title: "About", symbol: "info.circle") {
                Text("Mickey — cursor highlighter & presentation toolkit.")
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev")")
                    .foregroundStyle(.secondary)
                Text("Runs entirely on your Mac: no account, no network access, no data collection.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}
