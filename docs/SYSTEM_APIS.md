# System APIs

## 1. Network

Mickey makes **no network request**: it has no network entitlement, no backend and no analytics. The only outbound action is opening System Settings panes with `NSWorkspace.open`.

## 2. macOS services

| Component | Responsibility | macOS API | Permission |
| --- | --- | --- | --- |
| `InputMonitor` | pointer position, modifier flags, clicks, scrolls | `NSEvent.mouseLocation`, `CGEventSource.flagsState`, `CGEventSource.secondsSinceLastEventType`, `NSEvent` global and local monitors | none |
| `HotkeyRegistry` | global hotkeys | Carbon `RegisterEventHotKey` | none |
| `HotkeyConflict` | conflict checks | `CopySymbolicHotKeys`, `NSUserKeyEquivalents` (global domain) | none |
| `EffectsEngine` | per-screen overlays | borderless `NSPanel`, Core Animation | none |
| `CursorVisibility` | hide / show the pointer | `CGDisplayHideCursor` / `CGDisplayShowCursor` (balanced) | none |
| `SoundPlayer` | click sound, custom file | `AVAudioPlayer`, `AudioServicesPlaySystemSound`, `NSOpenPanel`, security-scoped bookmarks | user-selected file |
| `LoginItemService` | launch at login | `SMAppService.mainApp` | user approval |
| `ReviewTracker` | review prompt | `AppStore.requestReview(in:)` | — |
| `StatusItemController` | menu-bar icon and popover | `NSStatusItem`, `NSPopover` | — |
| `Permissions` | permission state and requests | `CGPreflightListenEventAccess`, `IOHIDCheckAccess`, `CGPreflightScreenCaptureAccess`, `AVCaptureDevice`, `SFSpeechRecognizer` | — |
| `KeystrokeMonitor` | typed keys | `CGEvent.tapCreate` (listen-only, session tap) | Input Monitoring |
| `FrontWindow` | frontmost window frame | `NSWorkspace.frontmostApplication`, `CGWindowListCopyWindowInfo` (bounds only) | none |
| `AppWatcher` | running apps | `NSWorkspace` launch / terminate notifications | none |
| `ScreenFrameSource` | live frames for zoom and loupe | ScreenCaptureKit `SCStream`, IOSurface layer contents | Screen Recording |
| `ScreenRecorder` | screen recording | `SCStream` + `AVAssetWriter` (HEVC, AAC) | Screen Recording |
| `CameraBubble` | webcam preview | `AVCaptureSession`, `AVCaptureVideoPreviewLayer` | Camera |
| `Captions` | live captions | `AVAudioEngine`, `SFSpeechAudioBufferRecognitionRequest` | Microphone, Speech Recognition |

Screen changes are observed with `NSApplication.didChangeScreenParametersNotification`; permission states are refreshed when Mickey becomes active, when Settings opens and after each request.

## 3. Error handling

| Situation | Handling |
| --- | --- |
| Login item waiting for approval | Message and button to System Settings › General › Login Items |
| Login item registration or removal failed | Message inviting the user to do it manually |
| Custom sound unreadable | Default sound, choice cleared, warning |
| Hotkey refused by macOS at registration | Red line on the hotkey row |
| Hotkey conflict while recording | Refusal or warning, see the product specification |
| Input Monitoring missing | Keystrokes stay off; banner explains how to allow it |
| Screen Recording missing | Recording asks for it; zoom and loupe show the permission row |
| Camera, microphone or speech unavailable | Tool stays off; banner explains why |
| Capture or recording stopped by the system | Message; partial recordings are finished when possible |
| Menu-bar icon hidden by macOS | Warning in General suggesting Show in Dock |

Diagnostics are logged under the subsystem `dev.local.mickey` (categories `input` and `menubar`).
