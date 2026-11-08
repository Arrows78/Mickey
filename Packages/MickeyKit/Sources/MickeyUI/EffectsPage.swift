import SwiftUI
import MickeyDomain

struct EffectsPage: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "Cursor effects", subtitle: "Make the pointer easy to follow during demos and recordings.")
            masterCard
            EffectPreview(settings: model.settings)
            spotlightCard
            ringCard
            clickCard
            soundCard
            trailCard
            shakeCard
        }
    }

    private var masterCard: some View {
        FeatureCard(title: "Enable Mickey", symbol: "power",
                    subtitle: "Master switch for every cursor effect. Turning any effect on also turns this on.",
                    isOn: model.binding(\.general.masterEnabled), help: model.tooltip(.toggleMaster)) { EmptyView() }
    }

    private var spotlightCard: some View {
        let s = model.settings.spotlight
        return FeatureCard(title: "Spotlight", symbol: "circle.dashed",
                           subtitle: "Dims the screen except an area around the pointer.",
                           isOn: model.binding(\.spotlight.enabled), help: model.tooltip(.toggleSpotlight)) {
            PickerRow(title: "Shape", selection: model.binding(\.spotlight.shape), options: SpotlightShape.allCases) { Text($0.title) }
            if s.shape == .circle {
                SliderRow(title: "Size", value: model.binding(\.spotlight.radius), range: SpotlightSettings.radiusRange)
            } else {
                SliderRow(title: "Bar thickness", value: model.binding(\.spotlight.barThickness), range: SpotlightSettings.barThicknessRange)
            }
            SliderRow(title: "Background darkness", value: model.binding(\.spotlight.backgroundOpacity), range: 0...1, format: percent)
            SliderRow(title: "Spotlight clarity", value: model.binding(\.spotlight.spotOpacity), range: 0...1, format: percent)
            ToggleRow(title: "Hide cursor", detail: "Hides the system pointer while the spotlight is shown (when Mickey is active).",
                      isOn: model.binding(\.spotlight.hideCursor))
            Divider()
            PickerRow(title: "Hold a key to show", selection: model.binding(\.spotlight.holdKey),
                      options: [nil] + TriggerKey.allCases.map(Optional.some)) { Text($0?.title ?? tr("Always on")) }
            if s.holdKey != nil {
                SliderRow(title: "Hold delay", value: model.binding(\.spotlight.holdDelay), range: SpotlightSettings.holdDelayRange,
                          step: 0.05, format: seconds)
            }
            ForEach(SettingsRules.triggerKeyNotes(for: s.holdKey, role: .spotlightHold, settings: model.settings), id: \.self) {
                NoteView(text: $0, warning: true)
            }
            ToggleRow(title: "Turn off when moving", detail: "Find the pointer, then move away and the spotlight switches itself off.",
                      isOn: model.binding(\.spotlight.dismissOnMove))
            if s.dismissOnMove {
                SliderRow(title: "Movement needed", value: model.binding(\.spotlight.dismissDistance),
                          range: SpotlightSettings.dismissDistanceRange, format: { "\(Int($0)) pt" })
                NoteView(text: "Works best with a Toggle spotlight hotkey. Cannot be combined with Hold a key to show.")
            }
        }
    }

    private var ringCard: some View {
        FeatureCard(title: "Ring", symbol: "circle", subtitle: "A ring that follows the pointer.",
                    isOn: model.binding(\.ring.enabled), help: model.tooltip(.toggleRing)) {
            SliderRow(title: "Ring size", value: model.binding(\.ring.radius), range: RingSettings.radiusRange)
            SliderRow(title: "Thickness", value: model.binding(\.ring.thickness), range: RingSettings.thicknessRange, step: 0.5, format: decimal)
            ColorRow(title: "Ring color", color: model.binding(\.ring.color))
            ToggleRow(title: "Neon glow", isOn: model.binding(\.ring.neon))
            ToggleRow(title: "Contrast outline", detail: "Adds a thin black or white edge so the ring stays visible on any background.",
                      isOn: model.binding(\.ring.contrastOutline))
            ToggleRow(title: "Animate ring", isOn: model.binding(\.ring.animated))
            if model.settings.ring.animated {
                SliderRow(title: "Animation speed", value: model.binding(\.ring.animationSpeed), range: RingSettings.speedRange, format: decimal)
            }
        }
    }

    private var clickCard: some View {
        let c = model.settings.click
        return FeatureCard(title: "Click feedback", symbol: "cursorarrow.click.2",
                           subtitle: "A visual effect at each click.", isOn: model.binding(\.click.feedbackEnabled), help: model.tooltip(.toggleClickFeedback)) {
            HStack {
                PickerRow(title: "Effect type", selection: model.binding(\.click.effectType), options: ClickEffectType.allCases) { Text($0.title) }
                Button("Preview") { model.actions?.previewClickEffect() }
                    .help(model.tooltip(.showClickEffect, title: "Show the effect at the pointer"))
            }
            ColorRow(title: "Effect color", color: model.binding(\.click.color))
            SliderRow(title: "Effect size", value: model.binding(\.click.size), range: ClickSettings.sizeRange)
            SliderRow(title: "Speed", value: model.binding(\.click.speed), range: ClickSettings.speedRange, format: decimal)
            SliderRow(title: "Line width", value: model.binding(\.click.lineWidth), range: ClickSettings.lineWidthRange, step: 0.5, format: decimal)
            Divider()
            ToggleRow(title: "Show on mouse clicks", detail: "Turn off to show the effect only on demand (key tap or hotkey).",
                      isOn: model.binding(\.click.showOnClicks))
            PickerRow(title: "Show with a key tap", selection: model.binding(\.click.tapKey),
                      options: [nil] + TriggerKey.allCases.map(Optional.some)) { Text($0?.title ?? tr("None")) }
            if c.tapKey != nil { NoteView(text: "Tap the key on its own to flash the effect. Taps combined with another key, a click or a scroll are ignored.") }
            ForEach(SettingsRules.triggerKeyNotes(for: c.tapKey, role: .clickTap, settings: model.settings), id: \.self) {
                NoteView(text: $0, warning: true)
            }
            if c.feedbackUnreachable(hasShowEffectHotkey: model.settings.hotkeys[.showClickEffect] != nil) {
                NoteView(text: "Pick a tap key or set a Show click effect hotkey, otherwise the effect will never appear.", warning: true)
            }
        }
    }

    private var soundCard: some View {
        let c = model.settings.click
        return FeatureCard(title: "Click sounds", symbol: "speaker.wave.2", subtitle: "An audible click on each mouse press.",
                           isOn: model.binding(\.click.soundEnabled), help: model.tooltip(.toggleClickSound)) {
            SliderRow(title: "Volume", value: model.binding(\.click.soundVolume), range: 0...1, format: percent)
            HStack {
                Text("Sound").frame(width: settingsLabelWidth, alignment: .leading)
                Text(c.customSound?.displayName ?? tr("Default click")).foregroundStyle(.secondary)
                Spacer()
                Button("Choose sound file…") { model.chooseCustomSound() }
                if c.customSound != nil { Button("Use default") { model.update { $0.click.customSound = nil } } }
            }
            if model.customSoundError { NoteView(text: "The chosen file could not be played. Using the default sound.", warning: true) }
        }
    }

    private var trailCard: some View {
        FeatureCard(title: "Trail", symbol: "scribble.variable", subtitle: "Leaves a fading trail behind the pointer.",
                    isOn: model.binding(\.trail.enabled), help: model.tooltip(.toggleTrail)) {
            PickerRow(title: "Trail style", selection: model.binding(\.trail.style), options: TrailStyle.allCases) { Text($0.title) }
            IntSliderRow(title: "Trail length", value: model.binding(\.trail.length), range: TrailSettings.lengthRange)
            SliderRow(title: "Trail width", value: model.binding(\.trail.width), range: TrailSettings.widthRange)
            SliderRow(title: "Trail opacity", value: model.binding(\.trail.opacity), range: 0...1, format: percent)
            ColorRow(title: "Trail color", color: model.binding(\.trail.color))
            SliderRow(title: "Fade speed", value: model.binding(\.trail.fadeSpeed), range: TrailSettings.fadeSpeedRange, format: decimal)
            if model.settings.trail.style.isDiscrete {
                SliderRow(title: "Spacing", value: model.binding(\.trail.spawnRate), range: TrailSettings.spawnRateRange)
                NoteView(text: "Lower spacing draws more items.")
            }
        }
    }

    private var shakeCard: some View {
        FeatureCard(title: "Shake to locate", symbol: "scope",
                    subtitle: "Shake the mouse quickly to show a large locator around the pointer.",
                    isOn: model.binding(\.shake.enabled), help: model.tooltip(.toggleShakeToLocate)) {
            SliderRow(title: "Sensitivity", value: model.binding(\.shake.sensitivity), range: ShakeSettings.sensitivityRange, format: percent)
            PickerRow(title: "Animation", selection: model.binding(\.shake.style), options: LocatorStyle.allCases) { Text($0.title) }
        }
    }
}
