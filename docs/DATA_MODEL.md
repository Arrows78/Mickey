# Data model

All settings live in one `Settings` value (`Codable`, `Equatable`, `Sendable`), stored as JSON.

## 1. Enums

All are `String`-backed, `CaseIterable` and `Codable`; the first case is the default unless stated.

| Enum | Cases |
| --- | --- |
| `SpotlightShape` | `circle`, `horizontalBar`, `verticalBar` |
| `TriggerKey` (hold and tap) | `leftControl`, `rightCommand`, `rightOption`, `rightShift`, `rightControl` (optional: `nil` = none, the default) |
| `ClickEffectType` | `singleRing`, `ripple`, `ringBurst`, `colorFlash`, `particleBurst`, `glowPulse`, `scaleBounce` |
| `TrailStyle` | `solid`, `dots`, `dashed`, `particles`, `glow`, `stars`, `image` (hearts) |
| `LocatorStyle` | `enlargedPointer`, `ring` |
| `AnnotationTool` | `freehand`, `arrow`, `rectangle`, `circle`, `line`, `highlighter`, `text`, `callout` |
| `HUDPosition` | `bottomCenter`, `bottomLeft`, `bottomRight`, `topCenter` |
| `ScreenCorner` | `bottomRight`, `bottomLeft`, `topRight`, `topLeft` |
| `BubbleShape` | `circle`, `roundedSquare` |
| `Preset` | `presentation`, `tutorial`, `discreet` |
| `MenuBarItem` | `spotlight`, `ring`, `clickFeedback`, `clickSound`, `trail`, `shake`, `annotations`, `keystrokes`, `liveZoom`, `loupe`, `focus`, `cameraBubble`, `captions` |
| `HotkeyAction` | `toggleMaster`, `toggleSpotlight`, `toggleRing`, `toggleTrail`, `toggleClickFeedback`, `toggleClickSound`, `showClickEffect`, `toggleShakeToLocate`, `toggleAnnotationMode`, `toggleKeystrokes`, `toggleLiveZoom`, `toggleLoupe`, `toggleFocus`, `toggleCameraBubble`, `toggleCaptions`, `toggleRecording` |
| `SettingsSection` | `effects`, `annotations`, `keystrokes`, `zoom`, `loupe`, `focus`, `recorder`, `captions`, `hotkeys`, `general`, `advanced`, `help`, `support` |

Runtime-only: `LoginItemState` (`enabled`, `disabled`, `requiresApproval`, `failed(message)`), `Permission`, `PermissionStatus` (`granted`, `notDetermined`, `denied`).

## 2. Settings

Values are clamped to their range when decoded and whenever they change.

### General

| Field | Type | Default | Range / rule |
| --- | --- | --- | --- |
| `masterEnabled` | Bool | true | |
| `showInMenuBar` | Bool | true | `showInMenuBar ∨ showInDock` |
| `showInDock` | Bool | false | |
| `launchAtLogin` | Bool | false | mirrors the system state |
| `updateRateHz` | Double | 60 | 30…120 |
| `hasCompletedOnboarding` | Bool | false | |
| `menuBarItems` | Set<MenuBarItem> | all | |

### Cursor effects

| Group | Field (default, range) |
| --- | --- |
| `spotlight` | `enabled` (false) · `radius` (150, 40…500) · `spotOpacity` (1, 0…1) · `backgroundOpacity` (0.6, 0…1) · `shape` (circle) · `barThickness` (60, 20…400) · `hideCursor` (false) · `dismissOnMove` (false) · `dismissDistance` (40, 10…400) · `holdKey` (nil) · `holdDelay` (0.5 s, 0…2) |
| `ring` | `enabled` (false) · `radius` (50, 10…150) · `thickness` (3, 1…20) · `color` (blue) · `animated` (false) · `animationSpeed` (1, 0.25…3) · `neon` (false) · `contrastOutline` (false: black or white edge, whichever contrasts more with `color`) |
| `click` | `feedbackEnabled` (false) · `showOnClicks` (true) · `tapKey` (nil) · `effectType` (singleRing) · `color` (white) · `size` (100, 20…300) · `speed` (1, 0.25…3) · `lineWidth` (3, 1…10) · `soundEnabled` (false) · `soundVolume` (0.5, 0…1) · `customSound` (nil) |
| `trail` | `enabled` (false) · `style` (solid) · `length` (30, 5…100) · `width` (5, 1…30) · `opacity` (0.8, 0…1) · `color` (white) · `fadeSpeed` (1, 0.25…3) · `spawnRate` (4, 1…10) |
| `shake` | `enabled` (true) · `sensitivity` (0.95, 0.1…1) · `style` (enlargedPointer) |

`SoundReference { bookmark: Data, displayName: String }`: read-only security-scoped bookmark of the chosen audio file.

### Annotations

`enabled` (false) · `rightOptionTrigger` (false) · `defaultTool` (freehand) · `color` (red) · `strokeWidth` (4, 1…20) · `highlighterColor` (yellow) · `highlighterSize` (32, 8…80) · `calloutSize` (26, 14…60) · `autoFade` (false) · `autoFadeDelay` (5 s, 1…30) · `clearOnExit` (false)

### Presenter tools

| Group | Field (default, range) |
| --- | --- |
| `keystrokes` | `enabled` (false) · `shortcutsOnly` (true) · `position` (bottomCenter) · `fontSize` (28, 16…64) · `duration` (1.5 s, 0.5…5) |
| `zoom` | `enabled` (false) · `factor` (2, 1.25…6) |
| `loupe` | `enabled` (false) · `size` (240, 100…500) · `factor` (2.5, 1.5…8) · `shape` (circle) · `borderColor` (white) |
| `focus` | `enabled` (false) · `dimOpacity` (0.55, 0.1…0.95) · `cornerRadius` (10, 0…30) · `padding` (6, 0…40) |
| `camera` | `enabled` (false) · `size` (200, 100…480) · `shape` (circle) · `corner` (bottomRight) · `mirrored` (true) · `borderColor` (white) |
| `captions` | `enabled` (false) · `fontSize` (30, 16…64) · `position` (bottomCenter) · `backgroundOpacity` (0.65, 0…1) · `maxLines` (2, 1…4) · `language` ("" = system) |
| `recorder` | `showCursor` (true) · `captureSystemAudio` (true) · `countdown` (3 s, 0…10) · `quality` (uhd: hd 1920 px, qhd 2560 px, uhd 3840 px) · `frameRate` (60, one of 30 or 60) |
| `autoMode` | `enabled` (false) · `preset` (presentation) · `bundleIDs` (meeting, presentation and recording apps) · `appPresets` (bundle ID → preset used for that app instead of `preset`, empty) |

### Hotkeys

`hotkeys: [HotkeyAction: KeyCombo]`, defaulting to ⌃⌥⌘ plus a letter for every action. `KeyCombo { keyCode: UInt32, modifiers: {control, option, shift, command}, keyLabel: String }`. Two combos are equal when key code and modifiers match; `keyLabel` only describes the key and the UI shows what the key prints in the current layout. Default hotkeys sit on the key printing their letter in the current layout (`HotkeyAction.defaultHotkey(keyCode:)`); ⌥ and ⌥⇧ alone are refused because they type characters.

## 3. Colors

`RGBAColor { red, green, blue, alpha: Double }` in sRGB, clamped to 0…1; converted to `CGColor`, `NSColor` and SwiftUI `Color` at the edges.

## 4. Storage

- `Settings` is encoded as JSON under `mickey.settings.v1` in the standard user defaults; `ReviewState { launchCount, activeMinutes, lastRequest }` under `mickey.review.v1`.
- Writes are debounced (250 ms), flushed on quit, after a reset and at launch (so migrations persist).
- **Recovery**: when the document does not decode as a whole, stored values are merged into the defaults one leaf at a time, keeping each only if the document still decodes. Unknown, missing or invalid fields fall back to their default; the hotkey dictionary is merged as a whole.
- **Migrations** (`schemaVersion`, currently 5): each `HotkeyAction` records the schema that introduced it; loading an older document adds those actions' defaults when unset and not already used by another action. Version 3 also adds the presenter tools to `menuBarItems`. Version 4 moves hotkeys still on their US-layout default to the key printing the same letter in the current layout (⌃⌥⌘M was ⌃⌥⌘, on AZERTY), leaving custom shortcuts alone. Version 5 adds the pause/resume recording hotkey (⌃⌥⌘P) when it is not already used by another action.

- **Export file**: `SettingsTransfer` writes the same JSON, pretty-printed, without the custom click sound (its bookmark only means something on one Mac). Importing goes through the recovery path above, so out-of-range or invalid values are repaired; the custom sound, the launch-at-login state and the onboarding flag of the current Mac are kept. A file without `schemaVersion` is refused.

## 5. Runtime models

| Type | Content |
| --- | --- |
| `InputSnapshot` | pointer position (global, bottom-left origin), raw modifier flags, another key pressed, time |
| `PointerSample` | position, time |
| `TrailBuffer.Point` | position, birth time |
| `Annotation` | id, tool, points, color, width, text, callout number, creation time |
| `AnnotationSession` | annotations, undo and redo stacks (≤ 100), current stroke, selected tool and color, text being edited |
| `KeystrokeHistory.Entry` | id, text, repeat count, time |
| `WindowInfo` | owner PID, layer, bounds (top-left origin), alpha |

## 6. Cross-field rules

Applied by `SettingsRules.normalize(old:new:)` to every change:

1. Clamp every bounded value.
2. A cursor effect turned on while the master switch is off turns it on (presenter tools excepted).
3. `holdKey ≠ nil` and `dismissOnMove` are exclusive; the field that just changed wins.
4. `showInMenuBar` and `showInDock` cannot both be false; the other one is turned back on.
