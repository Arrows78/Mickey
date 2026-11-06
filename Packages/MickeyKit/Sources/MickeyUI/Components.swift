import SwiftUI
import MickeyDomain
import MickeyEffects

/// Rounded card grouping one feature's controls, with an optional enable toggle in its header.
struct FeatureCard<Content: View>: View {
    let title: String
    let symbol: String
    var subtitle: String?
    var isOn: Binding<Bool>?
    /// Tooltip of the enable toggle, e.g. with its hotkey.
    var help: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(tr(title), systemImage: symbol).font(.headline)
                Spacer()
                if let isOn {
                    Toggle("", isOn: isOn).toggleStyle(.switch).labelsHidden().accessibilityLabel(tr(title))
                        .help(help ?? (isOn.wrappedValue ? trf("Turn off %@", tr(title)) : trf("Turn on %@", tr(title))))
                }
            }
            if let subtitle { Text(tr(subtitle)).font(.callout).foregroundStyle(.secondary) }
            if isOn?.wrappedValue ?? true {
                content
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.15), value: isOn?.wrappedValue)
    }
}

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double?
    var format: (Double) -> String = { String(format: "%.0f", $0) }

    var body: some View {
        HStack {
            Text(tr(title)).frame(width: 150, alignment: .leading)
            Group {
                if let step { Slider(value: $value, in: range, step: step) } else { Slider(value: $value, in: range) }
            }
            .accessibilityLabel(tr(title))
            .accessibilityValue(format(value))
            Text(format(value)).monospacedDigit().foregroundStyle(.secondary).frame(width: 56, alignment: .trailing)
        }
    }
}

struct IntSliderRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        SliderRow(title: title, value: Binding(get: { Double(value) }, set: { value = Int($0.rounded()) }),
                  range: Double(range.lowerBound)...Double(range.upperBound), step: 1)
    }
}

struct ColorRow: View {
    let title: String
    @Binding var color: RGBAColor

    var body: some View {
        HStack {
            Text(tr(title)).frame(width: 150, alignment: .leading)
            ForEach(RGBAColor.presets, id: \.self) { preset in
                Button { color = preset } label: {
                    Circle().fill(Color(nsColor: preset.nsColor)).frame(width: 18, height: 18)
                        .overlay(Circle().strokeBorder(.primary.opacity(color == preset ? 0.9 : 0.15), lineWidth: color == preset ? 2 : 1))
                }
                .buttonStyle(.plain)
                .help(preset.presetName ?? tr("Color"))
                .accessibilityLabel(preset.presetName ?? tr("Color preset"))
                .accessibilityAddTraits(color == preset ? .isSelected : [])
            }
            ColorPicker("", selection: Binding(get: { Color(nsColor: color.nsColor) },
                                               set: { color = RGBAColor(NSColor($0)) }), supportsOpacity: false)
                .labelsHidden()
                .help("Custom color")
                .accessibilityLabel("Custom color")
        }
    }
}

struct PickerRow<T: Hashable, Label: View>: View {
    let title: String
    @Binding var selection: T
    let options: [T]
    @ViewBuilder let label: (T) -> Label

    var body: some View {
        HStack {
            Text(tr(title)).frame(width: 150, alignment: .leading)
            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { label($0).tag($0) }
            }
            .labelsHidden()
            .accessibilityLabel(tr(title))
            .frame(maxWidth: 260)
            Spacer()
        }
    }
}

struct ToggleRow: View {
    let title: String
    var detail: String?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tr(title))
                if let detail { Text(tr(detail)).font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
}

struct NoteView: View {
    let text: String
    var warning = false

    var body: some View {
        Label(tr(text), systemImage: warning ? "exclamationmark.triangle.fill" : "info.circle")
            .font(.caption)
            .foregroundStyle(warning ? .orange : .secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tr(title)).font(.largeTitle.bold())
            Text(tr(subtitle)).foregroundStyle(.secondary)
        }
        .padding(.bottom, 4)
    }
}

extension AppModel {
    /// "Toggle Ring (⌃⌥⌘R)", or just the title when the action has no shortcut.
    func tooltip(_ action: HotkeyAction, title: String? = nil) -> String {
        let text = tr(title ?? action.title)
        guard let combo = settings.hotkeys[action] else { return text }
        return "\(text) (\(KeyboardLayout.displayString(combo)))"
    }
}

func seconds(_ v: Double) -> String { String(format: "%.2f s", v) }
func decimal(_ v: Double) -> String { String(format: "%.2f", v) }
func percent(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }
