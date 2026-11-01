import SwiftUI
import MickeyDomain

/// Settings window content: sidebar, page, bottom status bar.
public struct SettingsRootView: View {
    @Bindable var model: AppModel

    public init(model: AppModel) { self.model = model }

    public var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        StudioMessage(model: model)
                        page
                    }
                    .padding(24).frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity)
                }
                Divider()
                statusBar
            }
        }
        .frame(minWidth: 820, minHeight: 560)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Image(systemName: "cursorarrow.rays").font(.title2).foregroundStyle(.tint)
                VStack(alignment: .leading) {
                    Text("Mickey").font(.title3.bold())
                    Text("Cursor toolkit").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 16)
            ForEach(SettingsSection.allCases) { section in
                if section == .keystrokes || section == .hotkeys {
                    Text(section == .keystrokes ? "PRESENTER TOOLS" : "SETTINGS")
                        .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                        .padding(.horizontal, 20).padding(.top, 10)
                }
                Button { model.selectedSection = section } label: {
                    Label(section.title, systemImage: section.symbolName)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(model.selectedSection == section ? Color.accentColor.opacity(0.18) : .clear,
                                    in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .help(section.title)
            }
            Spacer()
        }
        .frame(width: 210)
        .background(.background.secondary)
    }

    @ViewBuilder private var page: some View {
        switch model.selectedSection {
        case .effects: EffectsPage(model: model)
        case .annotations: AnnotationsPage(model: model)
        case .keystrokes: KeystrokesPage(model: model)
        case .zoom: ZoomPage(model: model)
        case .loupe: LoupePage(model: model)
        case .focus: FocusPage(model: model)
        case .recorder: RecorderPage(model: model)
        case .captions: CaptionsPage(model: model)
        case .hotkeys: HotkeysPage(model: model)
        case .general: GeneralPage(model: model)
        case .advanced: AdvancedPage(model: model)
        case .help: HelpPage(model: model)
        case .support: SupportPage(model: model)
        }
    }

    private var statusBar: some View {
        HStack {
            Circle().fill(model.settings.general.masterEnabled ? Color.green : Color.secondary).frame(width: 8, height: 8)
            Text(model.settings.general.masterEnabled ? "Mickey is on — cursor effects are active." : "Mickey is off.")
                .font(.callout)
            Spacer()
            Toggle("Enable", isOn: model.binding(\.general.masterEnabled)).toggleStyle(.switch).controlSize(.small)
                .help(model.tooltip(.toggleMaster))
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }
}

/// Menu-bar popover with quick toggles.
public struct StatusPopoverView: View {
    @Bindable var model: AppModel

    public init(model: AppModel) { self.model = model }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Mickey", systemImage: "cursorarrow.rays").font(.headline)
                Spacer()
                Toggle("", isOn: model.binding(\.general.masterEnabled)).toggleStyle(.switch).labelsHidden()
                    .accessibilityLabel("Enable Mickey")
                    .help(model.tooltip(.toggleMaster))
            }
            Divider()
            let items = MenuBarItem.allCases.filter { model.settings.general.menuBarItems.contains($0) }
            ForEach(items) { item in
                Toggle(isOn: model.binding(item)) {
                    HStack {
                        Text(item.title)
                        Spacer()
                        if let combo = item.hotkeyAction.flatMap({ model.settings.hotkeys[$0] }) {
                            Text(KeyboardLayout.displayString(combo)).font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                    }
                }
                .help(item.hotkeyAction.map { model.tooltip($0) } ?? "Turn \(item.title) on or off")
            }
            if items.isEmpty {
                Text("No quick toggles selected. Choose them in Settings › General.").font(.caption).foregroundStyle(.secondary)
            }
            if model.settings.annotations.enabled {
                Divider()
                HStack {
                    Button(model.isDrawing ? "Stop Drawing" : "Start Drawing") { model.actions?.toggleDrawing() }
                        .help(model.tooltip(.toggleAnnotationMode, title: model.isDrawing ? "Stop drawing" : "Start drawing"))
                    Spacer()
                    if let combo = model.settings.hotkeys[.toggleAnnotationMode] {
                        Text(KeyboardLayout.displayString(combo)).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                }
                Text("or hold Fn (🌐) to draw").font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            HStack {
                Button { model.actions?.toggleRecording() } label: {
                    Label(model.isRecording ? "Stop Recording" : "Record Screen",
                          systemImage: model.isRecording ? "stop.circle.fill" : "record.circle")
                }
                .foregroundStyle(model.isRecording ? .red : .primary)
                .help(model.tooltip(.toggleRecording, title: model.isRecording ? "Stop recording" : "Record the screen under the pointer"))
                Spacer()
                Menu("Presets") {
                    ForEach(Preset.allCases) { preset in Button(preset.title) { model.apply(preset) }.help(preset.detail) }
                }
                .fixedSize()
                .help("Switch several effects at once")
            }
            if let message = model.studioMessage {
                Text(message).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            HStack {
                Button("Settings…") { model.actions?.showSettings(nil) }.help("Open Mickey Settings")
                Spacer()
                Button("Quit Mickey") { model.actions?.quit() }.help("Quit Mickey and restore the pointer")
            }
        }
        .toggleStyle(.switch)
        .padding(14)
        .frame(width: 280)
    }
}

/// First-launch walkthrough.
public struct OnboardingView: View {
    @Bindable var model: AppModel
    let onFinish: () -> Void
    @State private var step = 0

    public init(model: AppModel, onFinish: @escaping () -> Void) { self.model = model; self.onFinish = onFinish }

    private let steps: [(String, String, String)] = [
        ("cursorarrow.rays", "Welcome to Mickey", "Effects that make your pointer easy to follow across your whole Mac."),
        ("circle.dashed", "Spotlight", "Dim everything except the area around the pointer to guide attention."),
        ("circle", "Ring", "A ring around the pointer keeps it visible during presentations."),
        ("menubar.rectangle", "Lives in the menu bar", "Click the pointer icon in the menu bar for quick toggles and settings."),
    ]

    public var body: some View {
        VStack(spacing: 20) {
            let s = steps[step]
            Image(systemName: s.0).font(.system(size: 56)).foregroundStyle(.tint).frame(height: 70)
                .overlay(alignment: .bottomTrailing) {
                    if step == steps.count - 1 {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 24)).foregroundStyle(.green)
                            .background(Circle().fill(.background)).offset(x: 10, y: 4)
                    }
                }
            Text(s.1).font(.title.bold())
            Text(s.2).multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 380)
            switch step {
            case 1: Toggle("Turn on Spotlight", isOn: model.binding(\.spotlight.enabled)).toggleStyle(.switch)
            case 2: Toggle("Turn on Ring", isOn: model.binding(\.ring.enabled)).toggleStyle(.switch)
            default: EmptyView()
            }
            HStack(spacing: 6) {
                ForEach(steps.indices, id: \.self) { i in
                    Circle().fill(i == step ? Color.accentColor : Color.secondary.opacity(0.3)).frame(width: 7, height: 7)
                }
            }
            HStack {
                if step < steps.count - 1 { Button("Skip") { finish() } }
                Spacer()
                Button(step == steps.count - 1 ? "Get Started" : "Continue") {
                    if step == steps.count - 1 { finish() } else { withAnimation { step += 1 } }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 520, height: 400)
    }

    private func finish() {
        model.update { $0.general.hasCompletedOnboarding = true }
        model.flush()
        onFinish()
    }
}
