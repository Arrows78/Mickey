import Foundation

/// Where a heads-up display sits on the screen.
public enum HUDPosition: String, CaseIterable, Codable, Sendable {
    case bottomCenter, bottomLeft, bottomRight, topCenter

    public var title: String {
        switch self {
        case .bottomCenter: "Bottom Center"
        case .bottomLeft: "Bottom Left"
        case .bottomRight: "Bottom Right"
        case .topCenter: "Top Center"
        }
    }
}

public enum ScreenCorner: String, CaseIterable, Codable, Sendable {
    case bottomRight, bottomLeft, topRight, topLeft

    public var title: String {
        switch self {
        case .bottomRight: "Bottom Right"
        case .bottomLeft: "Bottom Left"
        case .topRight: "Top Right"
        case .topLeft: "Top Left"
        }
    }
}

public enum BubbleShape: String, CaseIterable, Codable, Sendable {
    case circle, roundedSquare

    public var title: String {
        switch self {
        case .circle: "Circle"
        case .roundedSquare: "Rounded Square"
        }
    }
}

/// On-screen display of typed shortcuts.
public struct KeystrokeSettings: Codable, Equatable, Sendable {
    public var enabled = false
    /// Only combinations with ⌘, ⌃ or ⌥ and special keys are shown, never plain typing.
    public var shortcutsOnly = true
    public var position = HUDPosition.bottomCenter
    public var fontSize = 28.0
    public var duration = 1.5
    public init() {}

    public static let fontSizeRange = 16.0...64.0
    public static let durationRange = 0.5...5.0
}

/// Full-screen magnification that keeps the point under the pointer in place.
public struct ZoomSettings: Codable, Equatable, Sendable {
    public var enabled = false
    public var factor = 2.0
    public init() {}

    public static let factorRange = 1.25...6.0
}

/// Magnifying glass that follows the pointer.
public struct LoupeSettings: Codable, Equatable, Sendable {
    public var enabled = false
    public var size = 240.0
    public var factor = 2.5
    public var shape = BubbleShape.circle
    public var borderColor = RGBAColor.white
    public init() {}

    public static let sizeRange = 100.0...500.0
    public static let factorRange = 1.5...8.0
}

/// Dims everything except the frontmost window.
public struct FocusSettings: Codable, Equatable, Sendable {
    public var enabled = false
    public var dimOpacity = 0.55
    public var cornerRadius = 10.0
    public var padding = 6.0
    public init() {}

    public static let dimOpacityRange = 0.1...0.95
    public static let cornerRadiusRange = 0.0...30.0
    public static let paddingRange = 0.0...40.0
}

/// Floating webcam bubble.
public struct CameraSettings: Codable, Equatable, Sendable {
    public var enabled = false
    public var size = 200.0
    public var shape = BubbleShape.circle
    public var corner = ScreenCorner.bottomRight
    public var mirrored = true
    public var borderColor = RGBAColor.white
    public init() {}

    public static let sizeRange = 100.0...480.0
}

/// Live subtitles from the microphone.
public struct CaptionSettings: Codable, Equatable, Sendable {
    public var enabled = false
    public var fontSize = 30.0
    public var position = HUDPosition.bottomCenter
    public var backgroundOpacity = 0.65
    public var maxLines = 2
    /// BCP-47 identifier; empty means the system language.
    public var language = ""
    public init() {}

    public static let fontSizeRange = 16.0...64.0
    public static let maxLinesRange = 1...4
}

/// Screen recording to a movie file.
public struct RecorderSettings: Codable, Equatable, Sendable {
    public var showCursor = true
    public var captureSystemAudio = true
    public var countdown = 3
    public init() {}

    public static let countdownRange = 0...10
}

/// Turns Mickey on with a preset while presentation or meeting apps run.
public struct AutoModeSettings: Codable, Equatable, Sendable {
    public var enabled = false
    public var preset = Preset.presentation
    public var bundleIDs = AutoModeSettings.defaultBundleIDs
    public init() {}

    public static let defaultBundleIDs = [
        "us.zoom.xos", "com.microsoft.teams2", "com.microsoft.teams", "com.apple.FaceTime",
        "com.apple.Keynote", "com.microsoft.Powerpoint", "com.apple.QuickTimePlayerX",
        "com.obsproject.obs-studio", "com.loom.desktop", "com.cisco.webexmeetingsapp", "com.hnc.Discord",
    ]
}

/// Privacy permissions the presenter tools rely on.
public enum Permission: String, CaseIterable, Sendable, Identifiable {
    case inputMonitoring, screenRecording, camera, microphone, speechRecognition

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .inputMonitoring: "Input Monitoring"
        case .screenRecording: "Screen Recording"
        case .camera: "Camera"
        case .microphone: "Microphone"
        case .speechRecognition: "Speech Recognition"
        }
    }

    public var reason: String {
        switch self {
        case .inputMonitoring: "Needed to read which shortcuts you type. Mickey never records text."
        case .screenRecording: "Needed to magnify the screen and to record it."
        case .camera: "Needed to show your webcam in the bubble."
        case .microphone: "Needed to hear you for live captions."
        case .speechRecognition: "Needed to turn your voice into captions, on your Mac when supported."
        }
    }
}

public enum PermissionStatus: Equatable, Sendable {
    case granted, notDetermined, denied
}
