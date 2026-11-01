# Product specification

Mickey is a macOS menu-bar utility (macOS 14+) that makes the pointer easy to follow during presentations, lessons, meetings and screen recordings, and adds presenter tools on top. Everything runs locally: no account, no network access, no analytics.

## 1. Principles

- **Master switch** (*Enable Mickey*, on by default): no cursor effect is drawn while it is off.
- **No dead toggles**: turning a cursor effect on while the master switch is off turns the master switch on.
- **Presenter tools are independent**: keystrokes, live zoom, loupe, focus, camera bubble, captions and the recorder work whatever the master switch says.
- **Immediate persistence**: every change is saved (debounced) and restored at launch.
- **Always reachable**: the menu-bar icon and the Dock icon cannot both be off.
- **Ask only what is used**: cursor effects, annotations and focus need no permission; each presenter tool requests only its own.

## 2. Lifecycle

| Situation | Behaviour |
| --- | --- |
| First launch | Onboarding window. |
| User launch, onboarding done | Settings window. |
| Launch as a login item | Menu-bar icon only, no window. |
| Dock icon click / reopening the app | Settings window brought to front. |
| Quit | Stops a running recording, saves settings, removes overlays, shows the pointer again, unregisters hotkeys. |

## 3. Screens

### 3.1 Onboarding

Four steps: welcome, spotlight (with a toggle), ring (with a toggle), "lives in the menu bar" with a completion mark. *Skip* or *Get Started* sets `hasCompletedOnboarding`.

### 3.2 Settings window

A 940 × 720 pt panel that does not hide when the app deactivates and closes with Esc. A sidebar lists:

- **Cursor Effects**, **Annotations**;
- *Presenter tools*: **Keystrokes**, **Live Zoom**, **Loupe**, **Focus**, **Recorder & Camera**, **Captions**;
- *Settings*: **Hotkeys**, **General**, **Advanced**, **Help**, **Support**.

A bottom bar shows the master switch state. Problems reported by presenter tools appear in a dismissible banner above the page.

#### Cursor Effects

| Card | Controls (default) |
| --- | --- |
| Enable Mickey | master switch (on) |
| Spotlight | toggle (off); shape circle / horizontal bar / vertical bar (circle); size 150; bar thickness 60; background darkness 0.6; spotlight clarity 1.0; hide cursor (off); **Hold a Key to Show**: none, Left Control, Right Command, Right Option, Right Shift, Right Control (none) with hold delay 0.5 s; **Turn Off When Moving** (off) with distance 40 pt |
| Ring | toggle (off); size 50; thickness 3; color blue; neon glow (off); animate (off) with speed 1.0 |
| Click Feedback | toggle (off); effect single ring / ripple / ring burst / color flash / particle burst / glow pulse / scale bounce (single ring) with Preview; color white; size 100; speed 1.0; line width 3; **Show on Mouse Clicks** (on); **Show With a Key Tap** (none) |
| Click Sounds | toggle (off); volume 0.5; default click or a chosen audio file |
| Trail | toggle (off); style solid / dots / dashed / particles / glow / stars / hearts (solid); length 30; width 5; opacity 0.8; color white; fade speed 1.0; spacing 4 for discrete styles |
| Shake to Locate | toggle (**on**); sensitivity 0.95; animation enlarged pointer / shrinking ring (enlarged pointer) |

Contextual notes:

- A key used both to hold the spotlight and to tap the click effect: a quick tap flashes, a hold shows the spotlight.
- Right Option chosen while Right Option also triggers drawing: conflict warning.
- Right Shift: Sticky Keys / Slow Keys caveat. Left Control: Control-click and Mission Control caveat. Right Control: missing from Apple keyboards.
- Show on Mouse Clicks off with no tap key and no Show Click Effect hotkey: "the effect will never appear".
- Hold a Key to Show and Turn Off When Moving are mutually exclusive; the latest change wins.

#### Annotations

Toggle (off); Start/Stop Drawing; also hold Right Option (off); default tool (freehand); color (red); stroke width 4; highlighter color (yellow) and size 32; text & callout size 26; auto-fade (off) after 5 s; clear on exit (off).

#### Presenter tools

| Page | Controls (default) |
| --- | --- |
| Keystrokes | toggle (off); permission row; Shortcuts Only (on); position bottom center / bottom left / bottom right / top center; text size 28; display time 1.5 s |
| Live Zoom | toggle (off); permission row; magnification 2× (1.25–6×) |
| Loupe | toggle (off); permission row; shape circle / rounded square; size 240 pt; magnification 2.5× (1.5–8×); border color white |
| Focus | toggle (off); dim amount 0.55; corner radius 10; margin 6 pt |
| Recorder & Camera | start/stop with elapsed time; show recordings; show pointer (on); record system audio (on); countdown 3 s · camera bubble toggle (off); shape; corner bottom right; size 200 pt; mirror (on); border color white |
| Captions | toggle (off); microphone and speech permission rows; language (system); position bottom / top; text size 30; lines 2; background 0.65 |

#### Hotkeys

One row per action with a recorder, a conflict line when relevant and a restore-default button. *Reset to Defaults* restores every default; *Clear All* removes every shortcut; both ask for confirmation. A *How Hotkeys Work* card explains the rules.

#### General

Launch at login (with approval and failure states); show in menu bar; show in Dock; hidden-icon warning; presets; menu-bar contents (one checkbox per toggle, all on); version; reset all settings (confirmation, onboarding state kept).

#### Advanced

Update rate 60 Hz (30–120); automatic mode (off) with its preset.

#### Help

Search (⌘F, clear button, "No matches for …"), a *Jump to a feature* row, groups Overview, Cursor Effects, Annotations, Presenter Tools, Hotkeys, Menu bar, Troubleshooting, with links to the related settings page.

#### Support

About, *Copy Diagnostics* (version, macOS, permissions, settings without the custom sound bookmark), *Show Recordings*, permission states.

### 3.3 Menu-bar popover

Master switch; the toggles selected in General, each with its shortcut; Start/Stop Drawing when annotations are enabled; Record Screen / Stop Recording; Presets menu; latest tool message; Settings…; Quit. The icon is dimmed while Mickey is off and turns into a red record symbol while recording.

## 4. Behaviour

### 4.1 Spotlight

- Dims the screen under the pointer except a circle (radius = size) or a full-width / full-height band (thickness) centred on the pointer; other screens are not dimmed.
- Spotlight clarity below 1 lets some of the darkness into the hole.
- *Hold a Key to Show*: shown once the key has been held alone for the delay, hidden on release. A click or scroll cancels a pending hold.
- *Turn Off When Moving*: when the spotlight is switched on, an anchor is taken (re-anchored during the first 0.25 s); moving farther than the distance switches the spotlight off.
- *Hide Cursor*: hides the system pointer while the spotlight is visible; macOS honours this only while Mickey is the active app. The pointer is always restored.

### 4.2 Ring

A ring of the chosen size, thickness and color follows the pointer; neon adds a glow, animation a pulse whose period shrinks as speed grows.

### 4.3 Click feedback and sounds

- On a left, right or other mouse click (if *Show on Mouse Clicks*): an effect at the click; duration is the effect's base duration divided by speed.
- *Tap key*: a lone, short press (≤ 0.35 s) of the chosen modifier with no other key, click or scroll during the press flashes the effect at the pointer. A press that revealed the spotlight is not a tap.
- *Show Click Effect* hotkey: flashes the effect at the pointer.
- Clicks while drawing are strokes: no effect, no sound.
- Sound: the built-in click or the chosen file (read-only security-scoped bookmark) at the chosen volume; system alert sound if playback fails. A file that can no longer be read falls back to the default sound, clears the choice and shows a warning.

### 4.4 Trail

Keeps the last *length* positions; continuous styles keep every distinct sample, discrete styles space items `spacing × 4` points apart. Each point fades with age (one second at fade speed 1) and position along the trail.

### 4.5 Shake to locate

Pointer history over 0.5 s (at most 30 samples, identical positions ignored). With at least 5 samples and more than 1.5 s since the last detection:

- `threshold = (1.1 − sensitivity) × 5`;
- count sign reversals of Δx and of Δy between consecutive steps whose absolute values both exceed `threshold`;
- detect when `reversals ≥ Int(6 − 3 × sensitivity)` **and** the first-to-last distance is under 200 pt;
- then play the locator animation, clear the history and start the cooldown.

The enlarged-pointer animation flashes a pointer five times larger that shrinks back over one second; the ring animation closes a large ring onto the pointer.

### 4.6 Annotations

- Enter draw mode by holding Fn (≥ 0.25 s; releasing ends it), holding Right Option when enabled (same rule), the Toggle Annotation Mode hotkey, or Start Drawing.
- The canvas covers the screen under the pointer; a toolbar at the top offers the eight tools, preset colors, stroke width, undo, clear all and stop.
- Shortcuts while drawing, including while Fn is held: F freehand, A arrow, R rectangle, C circle, L line, H highlighter, T text, N callout, ⌘Z undo, ⌘⌫ clear all, Esc stop.
- Text: a click opens an inline editor; callouts are numbered automatically. Two-point shapes smaller than 2 pt are ignored.
- Auto-fade removes each annotation after the delay; clear on exit erases everything when leaving draw mode. Undo keeps up to 100 steps.

### 4.7 Hotkeys

Toggles invert the matching setting (cursor effects also turn the master switch on). Defaults are ⌃⌥⌘ plus a letter: M Mickey, S spotlight, R ring, T trail, C click feedback, K click sounds, F flash click effect, L shake to locate, D drawing, Y keystrokes, Z live zoom, O loupe, W focus, E camera bubble, A captions, V recording. The letters follow the keyboard layout (on AZERTY, A is the key marked A).

Recording rules: at least one of ⌃, ⌥, ⌘ (F-keys may be used alone); ⌘ alone and ⇧ alone are refused. Conflicts:

| Conflict | Result |
| --- | --- |
| Enabled macOS shortcut | refused |
| Another Mickey action | refused |
| The user's *All Applications* app shortcut | warning |
| Widely used app shortcut (reopen tab, developer tools, full screen…) | warning |
| Shortcut registered by another app | cannot be detected; documented |

Registered hotkeys pause while a shortcut is being recorded.

### 4.8 Presenter tools

| Tool | Behaviour | Permission |
| --- | --- | --- |
| Keystrokes | Listen-only event tap. Shows ⌃⌥⇧⌘ + key; repeats within 1 s collapse into `×n`; at most 4 items; each fades after the display time. Shortcuts Only hides plain typing (no ⌃/⌥/⌘, including Space and ⇧ + letter) but shows ↩, ⇥, ⌫, ⎋, arrows and F-keys. | Input Monitoring |
| Live Zoom | Captures the screen under the pointer (without Mickey's windows) and shows the area `[s.min + (p − s.min)(1 − 1/f), size s/f]`, so the point under the pointer stays in place. | Screen Recording |
| Loupe | Shows an area of `size / magnification` around the pointer in a bubble; combined with live zoom it magnifies the zoomed area. | Screen Recording |
| Focus | Ten times a second, finds the frontmost app's topmost normal window in the window list and dims every screen except a rounded hole around it. | — |
| Camera bubble | Default camera in a draggable, always-on-top bubble; placed in the chosen corner, kept where dragged until size or corner change. | Camera |
| Captions | Microphone → speech recogniser (on device when supported), partial results; a new task every 50 s or after silence; shows the end of the transcript at a word boundary within the line capacity. | Microphone, Speech Recognition |
| Recorder | Countdown, then records the screen under the pointer, Mickey's effects included, as HEVC (at most 3840 px wide) with optional system audio to `~/Movies/Mickey/Mickey Recording <date> at <time>.mov`; the file is revealed in Finder. | Screen Recording |

Each page shows its permission state with *Allow…* (system prompt) or *Open System Settings* (when previously refused). Tools waiting for a permission retry once it is granted.

### 4.9 Presets and automatic mode

| Preset | Effects |
| --- | --- |
| Presentation | ring, click feedback on clicks, spotlight on a held key (Left Control unless one is set), shake to locate |
| Tutorial Video | ring, click feedback, click sounds, keystrokes, shake to locate |
| Discreet | click flash on a tap key only (Left Control unless one is set), shake to locate |

Presets turn Mickey on and keep colors, sizes and hotkeys. Automatic mode applies its preset while one of the watched apps runs (Zoom, Microsoft Teams, FaceTime, Keynote, PowerPoint, QuickTime Player, OBS, Loom, Webex, Discord) and restores the previous settings when they quit, unless the settings were changed meanwhile. Turning Automatic mode off or changing its preset counts as no change: the previous settings come back, or the new preset applies. Quitting while the preset applies saves the previous settings, not the preset.

### 4.10 Launch at login

Uses the system login-item service. States: enabled, disabled, waiting for approval (message and button to System Settings), failed (message inviting the user to add or remove it manually).

### 4.11 Review prompt

Asked at most once per session, when Mickey has been launched at least 5 times with 30 active minutes (minutes with the master switch on), the session is at least 5 minutes old, onboarding is done, the settings window is frontmost, no spotlight is visible, nothing is being drawn, and no request happened in the last 120 days.

## 5. Edge cases

| Case | Behaviour |
| --- | --- |
| Screen added or removed | Overlays rebuilt for the current screens. |
| Menu-bar icon hidden by macOS | Warning in General suggesting Show in Dock. |
| Menu bar and Dock both unchecked | The other one is turned back on. |
| Quit with the pointer hidden | Pointer shown again. |
| Corrupted or partial settings | Each invalid field falls back to its default; the rest is kept. |
| Permission missing | The tool stays off and explains which permission to grant. |
| Offline | No impact: no network dependency. |

## 6. Known limitations

- macOS only hides the system pointer for the active app.
- Global hotkeys registered by other apps cannot be detected.
- Live zoom and loupe show the screen without Mickey's own windows, which are drawn above them.
