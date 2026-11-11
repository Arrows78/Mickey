import SwiftUI
import MickeyDomain

struct AnnotationsPage: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "Annotations", subtitle: "Draw arrows, shapes and freehand notes on top of everything.")
            FeatureCard(title: "Screen annotation", symbol: "pencil.tip.crop.circle",
                        subtitle: "Use the Toggle annotation mode hotkey, or Start drawing in the menu bar.",
                        isOn: model.binding(\.annotations.enabled)) {
                HStack {
                    Button(tr(model.isDrawing ? "Stop drawing" : "Start drawing")) { model.actions?.toggleDrawing() }
                        .help(model.tooltip(.toggleAnnotationMode, title: model.isDrawing ? "Stop drawing" : "Start drawing"))
                    Spacer()
                }
                PickerRow(title: "Default tool", selection: model.binding(\.annotations.defaultTool), options: AnnotationTool.allCases) {
                    Label($0.title, systemImage: $0.symbolName)
                }
                ColorRow(title: "Color", color: model.binding(\.annotations.color))
                SliderRow(title: "Stroke width", value: model.binding(\.annotations.strokeWidth), range: AnnotationSettings.strokeWidthRange)
                ColorRow(title: "Highlighter color", color: model.binding(\.annotations.highlighterColor))
                SliderRow(title: "Highlighter size", value: model.binding(\.annotations.highlighterSize), range: AnnotationSettings.highlighterSizeRange)
                SliderRow(title: "Text & callout size", value: model.binding(\.annotations.calloutSize), range: AnnotationSettings.calloutSizeRange)
                ToggleRow(title: "Auto-Fade", detail: "Each annotation disappears after a delay.", isOn: model.binding(\.annotations.autoFade))
                if model.settings.annotations.autoFade {
                    SliderRow(title: "Fade after", value: model.binding(\.annotations.autoFadeDelay),
                              range: AnnotationSettings.autoFadeDelayRange, step: 0.5, format: seconds)
                }
                ToggleRow(title: "Clear on exit", detail: "Erase everything when leaving draw mode.", isOn: model.binding(\.annotations.clearOnExit))
                NoteView(text: "While drawing: F freehand · A arrow · R rectangle · C circle · L line · H highlighter · T text · N callout · ⌘Z undo · ⇧⌘Z redo · ⌘C copy image · ⌘⌫ clear · Esc stop.")
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
            PageHeader(title: "Shortcuts", subtitle: "Global shortcuts that work from any app. Each defaults to ⌃⌥⌘ plus a letter.")
            FeatureCard(title: "Keyboard shortcuts", symbol: "keyboard") {
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
            FeatureCard(title: "How shortcuts work", symbol: "info.circle") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("• Click a field, then press the combination. Esc cancels, Delete clears, ↺ restores the default.")
                    Text("• Use Control, or Command or Option with another modifier. F-keys work alone.")
                    Text("• Letters follow your keyboard layout: ⌃⌥⌘M is the key marked M, on AZERTY too.")
                    Text("• Combinations already used by macOS or by another action are refused; common app shortcuts get a warning.")
                    Text("• Shortcuts set by other apps (Raycast, Rectangle…) can't be detected: if one stops working, pick another.")
                    Text("• A shortcut set here is taken from every other app, so avoid ones you use elsewhere.")
                }
                .font(.callout).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Clear all") { confirmClear = true }.help("Remove every shortcut")
                Button("Reset to defaults") { confirmReset = true }.help("Give every action its ⌃⌥⌘ default back")
            }
        }
        .confirmationDialog("Restore the default shortcuts?", isPresented: $confirmReset) {
            Button("Reset to defaults", role: .destructive) { model.resetHotkeys() }
        } message: {
            Text("Every action gets its ⌃⌥⌘ default back; your custom shortcuts are replaced.")
        }
        .confirmationDialog("Clear all shortcuts?", isPresented: $confirmClear) {
            Button("Clear all shortcuts", role: .destructive) { model.clearHotkeys() }
        } message: {
            Text("No action will have a shortcut. Reset to defaults brings them back.")
        }
    }
}

struct GeneralPage: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "General", subtitle: "Startup, appearance, menu bar, presets and performance.")
            FeatureCard(title: "Startup and visibility", symbol: "macwindow") {
                ToggleRow(title: "Launch at login", detail: "Start Mickey automatically when you log in.",
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
                ToggleRow(title: "Show in menu bar", detail: "Display the Mickey icon in the menu bar.", isOn: model.binding(\.general.showInMenuBar))
                ToggleRow(title: "Show in Dock", detail: "Display the Mickey icon in the Dock.", isOn: model.binding(\.general.showInDock))
                NoteView(text: "At least one of Menu Bar or Dock stays on so Mickey is always reachable.")
                if model.menuBarIconHidden && !model.settings.general.showInDock {
                    NoteView(text: "macOS is not showing the Mickey icon: the menu bar may be full, hidden behind the camera notch, or managed by another app. Turn on Show in Dock for a second way in.",
                             warning: true)
                }
            }
            FeatureCard(title: "Appearance", symbol: "circle.lefthalf.filled",
                        subtitle: "How Mickey's windows look. System follows your Mac's light or dark setting.") {
                PickerRow(title: "Theme", selection: model.binding(\.general.appearance), options: AppearanceMode.allCases) { Text($0.title) }
            }
            FeatureCard(title: "Menu bar contents", symbol: "menubar.rectangle",
                        subtitle: "Choose which quick toggles appear when you click the menu-bar icon.") {
                ForEach(MenuBarGroup.allCases, id: \.self) { group in
                    Text(group.title).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                              alignment: .leading, spacing: 8) {
                        ForEach(group.items) { item in
                            Toggle(item.title, isOn: Binding(
                                get: { model.settings.general.menuBarItems.contains(item) },
                                set: { on in model.update { if on { $0.general.menuBarItems.insert(item) } else { $0.general.menuBarItems.remove(item) } } }))
                        }
                    }
                }
            }
            PresetsCard(model: model)
            AutoModeCard(model: model)
            FeatureCard(title: "Performance", symbol: "speedometer") {
                SliderRow(title: "Update rate", value: model.binding(\.general.updateRateHz), range: GeneralSettings.updateRateRange,
                          step: 10, format: { "\(Int($0)) fps" })
                NoteView(text: "Higher rates make effects smoother but use more CPU.")
            }
        }
    }
}

/// Export, import and restore: everything about keeping settings safe.
struct BackupPage: View {
    @Bindable var model: AppModel
    @State private var confirmReset = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "Backup", subtitle: "Save your settings, move them to another Mac, or start over.")
            FeatureCard(title: "Export and import", symbol: "square.and.arrow.up.on.square",
                        subtitle: "Save your settings to a file, or load them on another Mac. Your custom click sound stays on this Mac.") {
                HStack {
                    Button("Export settings…") { model.exportSettings() }.help("Save every setting to a JSON file")
                    Button("Import settings…") { model.importSettings() }.help("Replace your settings with an exported file")
                    Spacer()
                }
                if let message = model.transferMessage { NoteView(text: message) }
            }
            FeatureCard(title: "Restore defaults", symbol: "arrow.counterclockwise") {
                HStack {
                    Text("Restore every setting to its default value.").foregroundStyle(.secondary)
                    Spacer()
                    Button("Restore defaults…") { confirmReset = true }
                }
            }
        }
        .confirmationDialog("Restore all default settings?", isPresented: $confirmReset) {
            Button("Restore defaults", role: .destructive) { model.resetAllSettings() }
        } message: {
            Text("All settings, including shortcuts, return to their defaults.")
        }
    }
}

struct AboutPage: View {
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

    private let repository = "https://github.com/Arrows78/Mickey"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "About", subtitle: "This build, and how to report a problem.")
            VStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 72, height: 72)
                    .accessibilityHidden(true)
                Text("Mickey").font(.title.bold())
                Text("Version \(appVersion)").foregroundStyle(.secondary).textSelection(.enabled)
                Text("Cursor highlighter & presentation toolkit.").foregroundStyle(.secondary)
                HStack {
                    Button("GitHub") { open(repository) }
                    Button("Releases") { open(repository + "/releases") }
                }
                .padding(.top, 4)
                HStack {
                    Button(tr(copied ? "Copied" : "Copy diagnostics")) { copyDiagnostics() }
                        .help("Copy a summary of your setup (version, macOS, permissions, settings) to paste into a bug report. It contains no personal data.")
                    Button("Show recordings") { model.actions?.revealRecordings() }
                }
                Text("Runs entirely on your Mac: no account, no network access, no data collection.")
                    .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.5))
        }
    }

    private func open(_ url: String) {
        if let url = URL(string: url) { model.actions?.open(url) }
    }
}

/// Every permission Mickey can use, with its state and a button to grant it.
struct PermissionsPage: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "Permissions", subtitle: "What macOS lets Mickey do, and what each tool needs.")
            FeatureCard(title: "Permissions", symbol: "lock.shield") {
                ForEach(Permission.allCases) { PermissionRow(model: model, permission: $0) }
            }
            NoteView(text: "Each permission is only asked for when a tool that needs it is switched on.")
        }
    }
}

/// "0.1.0 (1)" from the app bundle, or "dev" when run outside one.
var appVersion: String {
    let info = Bundle.main.infoDictionary
    guard let short = info?["CFBundleShortVersionString"] as? String else { return "dev" }
    return info?["CFBundleVersion"].map { "\(short) (\($0))" } ?? short
}
