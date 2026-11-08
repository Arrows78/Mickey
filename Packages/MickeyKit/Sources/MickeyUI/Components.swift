import SwiftUI
import MickeyDomain
import MickeyEffects

extension Color {
    /// 0xRRGGBB.
    init(rgb: UInt32) {
        self.init(red: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255, blue: Double(rgb & 0xFF) / 255)
    }
}

extension SettingsSection {
    /// Colour of the section's tile in the sidebar, its page header and its cards.
    var tint: Color {
        switch self {
        case .effects: Color(rgb: 0xFF9F0A)
        case .annotations: Color(rgb: 0x9B6BFF)
        case .keystrokes: Color(rgb: 0x30B06A)
        case .zoom: Color(rgb: 0x5B8CFF)
        case .loupe: Color(rgb: 0x2CB1BC)
        case .focus: Color(rgb: 0x64748B)
        case .recorder: Color(rgb: 0xFF5A52)
        case .captions: Color(rgb: 0xFF6B9D)
        case .general: Color(rgb: 0x8E8E93)
        case .hotkeys: Color(rgb: 0xFFB020)
        case .backup: Color(rgb: 0x6B7280)
        case .help: Color(rgb: 0x5B8CFF)
        case .permissions: Color(rgb: 0xE5484D)
        case .about: Color(rgb: 0x0EA5E9)
        }
    }
}

private struct CurrentSectionKey: EnvironmentKey { static let defaultValue: SettingsSection? = nil }

extension EnvironmentValues {
    /// The settings page being drawn, so its header and cards can pick up its colour.
    var currentSection: SettingsSection? {
        get { self[CurrentSectionKey.self] }
        set { self[CurrentSectionKey.self] = newValue }
    }
}

/// A symbol on a rounded, tinted tile: the mark of a section, a card or the app.
struct IconTile: View {
    let symbol: String
    var tint: Color
    var size: CGFloat = 24

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).fill(tint.gradient))
            .accessibilityHidden(true)
    }
}

/// A shortcut drawn as a small keycap.
struct KeyCap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

/// Rounded card grouping one feature's controls, with an optional enable toggle in its header.
struct FeatureCard<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.currentSection) private var section
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
                HStack(spacing: 8) {
                    IconTile(symbol: symbol, tint: section?.tint ?? .accentColor, size: 22)
                    Text(tr(title)).font(.headline)
                }
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
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.5))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: isOn?.wrappedValue)
    }
}

/// Width of the label column of every settings row, wide enough for the longer translations.
let settingsLabelWidth: CGFloat = 190

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double?
    var format: (Double) -> String = { String(format: "%.0f", $0) }

    var body: some View {
        HStack {
            Text(tr(title)).frame(width: settingsLabelWidth, alignment: .leading)
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
            Text(tr(title)).frame(width: settingsLabelWidth, alignment: .leading)
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
            Text(tr(title)).frame(width: settingsLabelWidth, alignment: .leading)
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
    @Environment(\.currentSection) private var section
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let section { IconTile(symbol: section.symbolName, tint: section.tint, size: 38) }
            VStack(alignment: .leading, spacing: 3) {
                Text(tr(title)).font(.largeTitle.bold())
                Text(tr(subtitle)).foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 4)
    }
}

extension AppModel {
    /// "Toggle ring (⌃⌥⌘R)", or just the title when the action has no shortcut.
    func tooltip(_ action: HotkeyAction, title: String? = nil) -> String {
        let text = tr(title ?? action.title)
        guard let combo = settings.hotkeys[action] else { return text }
        return "\(text) (\(KeyboardLayout.displayString(combo)))"
    }
}

func seconds(_ v: Double) -> String { String(format: "%.2f s", v) }
func decimal(_ v: Double) -> String { String(format: "%.2f", v) }
func percent(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }
