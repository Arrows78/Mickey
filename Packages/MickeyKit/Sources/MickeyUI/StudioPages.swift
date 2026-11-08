import SwiftUI
import MickeyDomain

/// Permission state with a button to grant it.
struct PermissionRow: View {
    @Bindable var model: AppModel
    let permission: Permission

    var body: some View {
        let status = model.permissions[permission] ?? .notDetermined
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: status == .granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(status == .granted ? .green : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(permission.title)
                Text(permission.reason).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if status != .granted {
                Button(tr(status == .denied ? "Open System Settings" : "Allow…")) { model.actions?.request(permission) }
            }
        }
    }
}

struct StudioMessage: View {
    @Bindable var model: AppModel

    var body: some View {
        if let message = model.studioMessage {
            HStack {
                NoteView(text: message, warning: true)
                Spacer()
                Button { model.studioMessage = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                    .help("Dismiss").accessibilityLabel("Dismiss")
            }
            .padding(10)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct KeystrokesPage: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "Keystrokes", subtitle: "Show the shortcuts you press, so viewers can follow along.")
            FeatureCard(title: "Show keystrokes", symbol: "command.square",
                        subtitle: "Combinations appear in a bar on the screen under the pointer, then fade.",
                        isOn: model.binding(\.keystrokes.enabled), help: model.tooltip(.toggleKeystrokes)) {
                PermissionRow(model: model, permission: .inputMonitoring)
                Divider()
                ToggleRow(title: "Shortcuts only", detail: "Show only combinations with ⌘, ⌃ or ⌥ and keys like ↩ or ⎋ — never what you type.",
                          isOn: model.binding(\.keystrokes.shortcutsOnly))
                if !model.settings.keystrokes.shortcutsOnly {
                    NoteView(text: "Every key is shown, including passwords you type. Turn Shortcuts only back on when you're done.", warning: true)
                }
                PickerRow(title: "Style", selection: model.binding(\.keystrokes.style), options: KeystrokeStyle.allCases) { Text($0.title) }
                if model.settings.keystrokes.style.usesAccent {
                    ColorRow(title: "Accent color", color: model.binding(\.keystrokes.accentColor))
                }
                PickerRow(title: "Position", selection: model.binding(\.keystrokes.position), options: HUDPosition.allCases) { Text($0.title) }
                SliderRow(title: "Text size", value: model.binding(\.keystrokes.fontSize), range: KeystrokeSettings.fontSizeRange)
                SliderRow(title: "Display time", value: model.binding(\.keystrokes.duration), range: KeystrokeSettings.durationRange,
                          step: 0.25, format: seconds)
            }
        }
    }
}

struct ZoomPage: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "Live zoom", subtitle: "Magnify the whole screen; the spot under the pointer stays where it is.")
            FeatureCard(title: "Live zoom", symbol: "plus.magnifyingglass",
                        subtitle: "Toggle it with its hotkey while presenting; move the pointer to pan.",
                        isOn: model.binding(\.zoom.enabled), help: model.tooltip(.toggleLiveZoom)) {
                PermissionRow(model: model, permission: .screenRecording)
                Divider()
                PickerRow(title: "Zoom", selection: model.binding(\.zoom.trigger), options: ZoomTrigger.allCases) { Text($0.title) }
                if model.settings.zoom.trigger == .onClick {
                    NoteView(text: "Zooms in around each click, then back out. The screen is captured while it waits, which uses some power.")
                }
                SliderRow(title: "Magnification", value: model.binding(\.zoom.factor), range: ZoomSettings.factorRange,
                          step: 0.25, format: { String(format: "%.2g×", $0) })
                SliderRow(title: "Animation duration", value: model.binding(\.zoom.animationDuration),
                          range: ZoomSettings.animationDurationRange, step: 0.05, format: seconds)
                if model.settings.zoom.trigger == .onClick {
                    SliderRow(title: "Stay zoomed for", value: model.binding(\.zoom.holdDuration),
                              range: ZoomSettings.holdDurationRange, step: 0.1, format: seconds)
                }
                NoteView(text: "Clicks go to what is really under the pointer, which is the magnified spot.")
            }
        }
    }
}

struct LoupePage: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "Loupe", subtitle: "A magnifying glass that follows the pointer.")
            FeatureCard(title: "Loupe", symbol: "magnifyingglass.circle", isOn: model.binding(\.loupe.enabled), help: model.tooltip(.toggleLoupe)) {
                PermissionRow(model: model, permission: .screenRecording)
                Divider()
                PickerRow(title: "Shape", selection: model.binding(\.loupe.shape), options: BubbleShape.allCases) { Text($0.title) }
                SliderRow(title: "Size", value: model.binding(\.loupe.size), range: LoupeSettings.sizeRange, format: { "\(Int($0)) pt" })
                SliderRow(title: "Magnification", value: model.binding(\.loupe.factor), range: LoupeSettings.factorRange,
                          step: 0.25, format: { String(format: "%.2g×", $0) })
                ColorRow(title: "Border color", color: model.binding(\.loupe.borderColor))
            }
        }
    }
}

struct FocusPage: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "Focus", subtitle: "Dim everything except the window you're working in.")
            FeatureCard(title: "Focus on front window", symbol: "macwindow.on.rectangle",
                        subtitle: "Follows the frontmost window as you switch apps. No permission needed.",
                        isOn: model.binding(\.focus.enabled), help: model.tooltip(.toggleFocus)) {
                SliderRow(title: "Dim amount", value: model.binding(\.focus.dimOpacity), range: FocusSettings.dimOpacityRange, format: percent)
                SliderRow(title: "Corner radius", value: model.binding(\.focus.cornerRadius), range: FocusSettings.cornerRadiusRange)
                SliderRow(title: "Margin", value: model.binding(\.focus.padding), range: FocusSettings.paddingRange, format: { "\(Int($0)) pt" })
            }
        }
    }
}

struct RecorderPage: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "Recorder & camera", subtitle: "Record the screen with every effect, and add your face in a bubble.")
            FeatureCard(title: "Screen recording", symbol: "record.circle",
                        subtitle: "Records the screen under the pointer to Movies › Mickey, effects and annotations included.") {
                PermissionRow(model: model, permission: .screenRecording)
                Divider()
                HStack {
                    Button(tr(model.isRecording ? "Stop recording" : "Start recording")) { model.actions?.toggleRecording() }
                        .keyboardShortcut(.defaultAction)
                        .help(model.tooltip(.toggleRecording, title: model.isRecording ? "Stop recording" : "Start recording after the countdown"))
                    if model.isRecording {
                        Button(tr(model.isRecordingPaused ? "Resume" : "Pause")) { model.actions?.togglePauseRecording() }
                            .help(model.tooltip(.togglePauseRecording, title: model.isRecordingPaused ? "Resume recording" : "Pause recording"))
                    }
                    if let clock = model.recordingClock {
                        TimelineView(.periodic(from: clock.startedAt, by: 1)) { context in
                            Label(RecordingNaming.elapsed(clock.elapsed(at: context.date)),
                                  systemImage: clock.isPaused ? "pause.circle.fill" : "record.circle.fill")
                                .foregroundStyle(clock.isPaused ? .orange : .red).monospacedDigit()
                        }
                    }
                    Spacer()
                    Button("Show recordings") { model.actions?.revealRecordings() }
                }
                ToggleRow(title: "Show pointer", isOn: model.binding(\.recorder.showCursor))
                ToggleRow(title: "Record system audio", detail: "Sound played by your Mac, including click sounds.",
                          isOn: model.binding(\.recorder.captureSystemAudio))
                IntSliderRow(title: "Countdown", value: model.binding(\.recorder.countdown), range: RecorderSettings.countdownRange)
                PickerRow(title: "Area", selection: model.binding(\.recorder.area), options: RecordingArea.allCases) { Text($0.title) }
                if model.settings.recorder.area == .region {
                    NoteView(text: "With Selected region, you drag the area to record each time you start.")
                }
                PickerRow(title: "Quality", selection: model.binding(\.recorder.quality), options: RecordingQuality.allCases) { Text($0.title) }
                PickerRow(title: "Frame rate", selection: model.binding(\.recorder.frameRate), options: RecorderSettings.frameRates) { Text("\($0) fps") }
                NoteView(text: "Screens wider than the chosen quality are scaled down. 30 fps and lower quality make smaller files.")
            }
            FeatureCard(title: "Camera bubble", symbol: "person.crop.circle", subtitle: "Drag the bubble anywhere on the screen.",
                        isOn: model.binding(\.camera.enabled), help: model.tooltip(.toggleCameraBubble)) {
                PermissionRow(model: model, permission: .camera)
                Divider()
                PickerRow(title: "Shape", selection: model.binding(\.camera.shape), options: BubbleShape.allCases) { Text($0.title) }
                PickerRow(title: "Corner", selection: model.binding(\.camera.corner), options: ScreenCorner.allCases) { Text($0.title) }
                SliderRow(title: "Size", value: model.binding(\.camera.size), range: CameraSettings.sizeRange, format: { "\(Int($0)) pt" })
                ToggleRow(title: "Mirror", isOn: model.binding(\.camera.mirrored))
                ColorRow(title: "Border color", color: model.binding(\.camera.borderColor))
            }
        }
    }
}

struct CaptionsPage: View {
    @Bindable var model: AppModel

    private static let languages: [String] = ["", "en-US", "en-GB", "fr-FR", "de-DE", "es-ES", "it-IT", "pt-BR", "nl-NL", "ja-JP", "zh-CN"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "Captions", subtitle: "Live subtitles of what you say, for talks and recordings.")
            FeatureCard(title: "Live captions", symbol: "captions.bubble",
                        subtitle: "Recognition runs on your Mac when the language supports it.",
                        isOn: model.binding(\.captions.enabled), help: model.tooltip(.toggleCaptions)) {
                PermissionRow(model: model, permission: .microphone)
                PermissionRow(model: model, permission: .speechRecognition)
                Divider()
                PickerRow(title: "Language", selection: model.binding(\.captions.language), options: Self.languages) { id in
                    Text(id.isEmpty ? tr("System language") : Locale.current.localizedString(forIdentifier: id) ?? id)
                }
                PickerRow(title: "Position", selection: model.binding(\.captions.position), options: [HUDPosition.bottomCenter, .topCenter]) {
                    Text($0.title)
                }
                SliderRow(title: "Text size", value: model.binding(\.captions.fontSize), range: CaptionSettings.fontSizeRange)
                IntSliderRow(title: "Lines", value: model.binding(\.captions.maxLines), range: CaptionSettings.maxLinesRange)
                SliderRow(title: "Background", value: model.binding(\.captions.backgroundOpacity), range: 0...1, format: percent)
            }
        }
    }
}

/// One-click presets, shown on the General page.
struct PresetsCard: View {
    @Bindable var model: AppModel

    var body: some View {
        FeatureCard(title: "Presets", symbol: "wand.and.stars", subtitle: "Switch several effects at once. Colors and sizes are kept.") {
            ForEach(Preset.allCases) { preset in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(preset.title)
                        Text(preset.detail).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Apply") { model.apply(preset) }.help(preset.detail)
                }
            }
        }
    }
}

/// Automatic mode, shown on the General page.
struct AutoModeCard: View {
    @Bindable var model: AppModel

    var body: some View {
        FeatureCard(title: "Automatic mode", symbol: "sparkles.tv",
                    subtitle: "Apply a preset while a meeting, presentation or recording app is running, and restore your settings afterwards.",
                    isOn: model.binding(\.autoMode.enabled)) {
            PickerRow(title: "Preset", selection: model.binding(\.autoMode.preset), options: Preset.allCases) { Text($0.title) }
            Divider()
            Text("Preset per app").font(.subheadline.weight(.medium))
            ForEach(model.settings.autoMode.bundleIDs, id: \.self) { id in
                PickerRow(title: AutoModeSettings.appNames[id] ?? id, selection: model.binding(\.autoMode.appPresets[id]),
                          options: [nil] + Preset.allCases.map(Optional.some)) { Text($0?.title ?? tr("Default preset")) }
            }
            NoteView(text: "When several watched apps run, the first one in this list decides.")
        }
    }
}
