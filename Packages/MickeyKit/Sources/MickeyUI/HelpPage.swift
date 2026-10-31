import SwiftUI
import MickeyDomain

/// One searchable help entry. Content is written for this project.
public struct HelpEntry: Identifiable, Sendable {
    public let id: String
    public let group: String
    public let title: String
    public let body: String
    public let section: SettingsSection?

    public init(id: String, group: String, title: String, body: String, section: SettingsSection?) {
        self.id = id; self.group = group; self.title = title; self.body = body; self.section = section
    }
}

public enum HelpContent {
    public static let entries: [HelpEntry] = [
        HelpEntry(id: "start", group: "Overview", title: "Getting started",
                  body: "Turn on Enable Mickey, then switch on the effects you want. Switching on an effect while Mickey is off turns it on for you.",
                  section: .effects),
        HelpEntry(id: "menubar", group: "Menu bar", title: "Quick toggles",
                  body: "Click the pointer icon in the menu bar for quick toggles, Start Drawing, Settings and Quit. Pick which toggles appear in General › Menu Bar Contents.",
                  section: .general),
        HelpEntry(id: "reach", group: "Menu bar", title: "Menu bar or Dock",
                  body: "Show in Menu Bar and Show in Dock can't both be off, so Mickey is always reachable. With the Dock icon shown, clicking it opens Settings.",
                  section: .general),
        HelpEntry(id: "findicon", group: "Menu bar", title: "Can't find the menu bar icon",
                  body: "A crowded menu bar, the camera notch or a menu-bar manager can hide the icon. Open Mickey again from the Applications folder to show Settings, then turn on Show in Dock for a second way in.",
                  section: .general),
        HelpEntry(id: "spotlight", group: "Cursor Effects", title: "Spotlight",
                  body: "Dims the screen except a circle or a bar around the pointer. Hold a Key to Show reveals it only while a modifier is held. Turn Off When Moving clears it once you move away.",
                  section: .effects),
        HelpEntry(id: "ring", group: "Cursor Effects", title: "Ring",
                  body: "Draws a ring around the pointer. Choose size, thickness, color, glow and pulse animation.", section: .effects),
        HelpEntry(id: "clicks", group: "Cursor Effects", title: "Click feedback and sounds",
                  body: "Shows an effect and/or plays a sound on each click. To point without every click rippling, turn off Show on Mouse Clicks and use a tap key or the Show Click Effect hotkey.",
                  section: .effects),
        HelpEntry(id: "trail", group: "Cursor Effects", title: "Trail",
                  body: "Leaves a fading trail behind the pointer: solid, dots, dashed, particles, glow, stars or hearts.", section: .effects),
        HelpEntry(id: "shake", group: "Cursor Effects", title: "Shake to locate",
                  body: "Shake the mouse quickly back and forth to show a large locator around the pointer.", section: .effects),
        HelpEntry(id: "draw", group: "Annotations", title: "Drawing on screen",
                  body: "Enable Annotations, then hold Fn (🌐) to draw, use the Toggle Annotation Mode hotkey, or click Start Drawing. Press Escape to stop.",
                  section: .annotations),
        HelpEntry(id: "tools", group: "Annotations", title: "Tools and shortcuts",
                  body: "F freehand, A arrow, R rectangle, C circle, L line, H highlighter, T text, N numbered callout. ⌘Z undoes, ⌘⌫ clears everything.",
                  section: .annotations),
        HelpEntry(id: "keystrokes", group: "Presenter Tools", title: "Show keystrokes",
                  body: "Displays the shortcuts you press in a bar on screen. Needs Input Monitoring. Shortcuts Only (on by default) never shows plain typing.",
                  section: .keystrokes),
        HelpEntry(id: "zoom", group: "Presenter Tools", title: "Live zoom",
                  body: "Magnifies the whole screen while the point under the pointer stays put; move the pointer to pan. Needs Screen Recording.",
                  section: .zoom),
        HelpEntry(id: "loupe", group: "Presenter Tools", title: "Loupe",
                  body: "A round or square magnifying glass that follows the pointer. Needs Screen Recording.", section: .loupe),
        HelpEntry(id: "focus", group: "Presenter Tools", title: "Focus",
                  body: "Dims everything except the frontmost window and follows it as you switch apps. No permission needed.", section: .focus),
        HelpEntry(id: "record", group: "Presenter Tools", title: "Recording and camera bubble",
                  body: "Records the screen under the pointer to Movies › Mickey with every effect, after a countdown. The camera bubble shows your webcam; drag it anywhere.",
                  section: .recorder),
        HelpEntry(id: "captions", group: "Presenter Tools", title: "Live captions",
                  body: "Subtitles what you say, on your Mac when the language supports it. Needs Microphone and Speech Recognition.",
                  section: .captions),
        HelpEntry(id: "presets", group: "Presenter Tools", title: "Presets and Automatic Mode",
                  body: "Presets switch several effects at once (General, or the menu bar). Automatic Mode applies one while Zoom, Teams, Keynote and similar apps run, then restores your settings.",
                  section: .general),
        HelpEntry(id: "permissions", group: "Troubleshooting", title: "A tool asks for a permission",
                  body: "Click Allow… next to the permission, or open System Settings › Privacy & Security and switch Mickey on. Support lists every permission and its state.",
                  section: .support),
        HelpEntry(id: "hotkeys", group: "Hotkeys", title: "Setting hotkeys",
                  body: "Every action has a default shortcut: ⌃⌥⌘ plus a letter (M Mickey, S spotlight, R ring, T trail, C click feedback, K click sounds, F flash click, L locate, D draw). Change one by clicking its field; ↺ or Reset to Defaults restores them, Clear All removes them.",
                  section: .hotkeys),
        HelpEntry(id: "nothing", group: "Troubleshooting", title: "Nothing appears on screen",
                  body: "Make sure Enable Mickey is on, in the settings window or the menu bar.", section: .effects),
        HelpEntry(id: "dead", group: "Troubleshooting", title: "A toggle does nothing",
                  body: "If an effect needs a trigger (hold key, tap key, hotkey), check that one is set.", section: .effects),
        HelpEntry(id: "nodraw", group: "Troubleshooting", title: "Annotations won't draw",
                  body: "Enable Annotations first. On some keyboards Fn is mapped to the emoji picker; use Right Option or a hotkey instead.",
                  section: .annotations),
        HelpEntry(id: "cursor", group: "Troubleshooting", title: "Pointer stays hidden",
                  body: "Turn off Hide Cursor in the Spotlight settings or quit Mickey: the pointer is always restored on exit.", section: .effects),
    ]

    public static func search(_ query: String) -> [HelpEntry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return entries }
        let terms = q.split(separator: " ").map(String.init)
        return entries.filter { e in
            let hay = "\(e.group) \(e.title) \(e.body)".lowercased()
            return terms.allSatisfy(hay.contains)
        }
    }
}

struct HelpPage: View {
    @Bindable var model: AppModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        let results = HelpContent.search(model.helpQuery)
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "Help", subtitle: "How Mickey works, and fixes for common problems.")
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search help (⌘F)", text: $model.helpQuery).textFieldStyle(.plain).focused($searchFocused)
                if !model.helpQuery.isEmpty {
                    Button { model.helpQuery = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Clear search")
                }
            }
            .padding(8)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
            .background(Button("") { searchFocused = true }.keyboardShortcut("f", modifiers: .command).hidden())

            if model.helpQuery.isEmpty { jumpRow }
            if results.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No matches for “\(model.helpQuery)”").font(.headline)
                    Text("Try a feature name: spotlight, ring, trail, clicks, hotkey…").foregroundStyle(.secondary)
                }
            }
            ForEach(Array(Dictionary(grouping: results, by: \.group).sorted { order($0.key) < order($1.key) }), id: \.key) { group, items in
                FeatureCard(title: group, symbol: "book") {
                    ForEach(items) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.title).font(.subheadline.bold())
                            Text(entry.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            if let section = entry.section {
                                Button("Open \(section.title) ›") { model.selectedSection = section }.buttonStyle(.link).font(.caption)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    /// Shortcuts to the settings page of each feature area.
    private var jumpRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Jump to a feature").font(.headline)
            HStack(spacing: 8) {
                ForEach([SettingsSection.effects, .annotations, .keystrokes, .recorder, .hotkeys, .general], id: \.self) { section in
                    Button { model.selectedSection = section } label: {
                        Label(section.title, systemImage: section.symbolName)
                    }
                }
            }
        }
    }

    private func order(_ group: String) -> Int {
        ["Overview", "Cursor Effects", "Annotations", "Presenter Tools", "Hotkeys", "Menu bar", "Troubleshooting"].firstIndex(of: group) ?? 99
    }
}
