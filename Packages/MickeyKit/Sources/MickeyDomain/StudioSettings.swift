import Foundation

/// Where a heads-up display sits on the screen.
public enum HUDPosition: String, CaseIterable, Codable, Sendable {
    case bottomCenter, bottomLeft, bottomRight, topCenter

    public var title: String {
        switch self {
        case .bottomCenter: tr("Bottom Center")
        case .bottomLeft: tr("Bottom Left")
        case .bottomRight: tr("Bottom Right")
        case .topCenter: tr("Top Center")
        }
    }
}

public enum ScreenCorner: String, CaseIterable, Codable, Sendable {
    case bottomRight, bottomLeft, topRight, topLeft

    public var title: String {
        switch self {
        case .bottomRight: tr("Bottom Right")
        case .bottomLeft: tr("Bottom Left")
        case .topRight: tr("Top Right")
        case .topLeft: tr("Top Left")
        }
    }
}

public enum BubbleShape: String, CaseIterable, Codable, Sendable {
    case circle, roundedSquare

    public var title: String {
        switch self {
        case .circle: tr("Circle")
        case .roundedSquare: tr("Rounded Square")
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

/// Largest width of a recorded movie; wider screens are scaled down to keep files and encoding load reasonable.
public enum RecordingQuality: String, CaseIterable, Codable, Sendable, Identifiable {
    case hd, qhd, uhd

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .hd: tr("Full HD (1920 px)")
        case .qhd: tr("QHD (2560 px)")
        case .uhd: tr("4K (3840 px)")
        }
    }

    public var maxWidth: Int {
        switch self {
        case .hd: 1920
        case .qhd: 2560
        case .uhd: 3840
        }
    }

    /// Movie size for a capture of `width` × `height` pixels: scaled down to `maxWidth` if wider, never up,
    /// and always even, as video encoders require.
    public func outputSize(width: Int, height: Int) -> (width: Int, height: Int) {
        let scale = min(1, Double(maxWidth) / Double(max(width, 1)))
        return (max(2, Int(Double(width) * scale) / 2 * 2), max(2, Int(Double(height) * scale) / 2 * 2))
    }
}

/// Screen recording to a movie file.
public struct RecorderSettings: Codable, Equatable, Sendable {
    public var showCursor = true
    public var captureSystemAudio = true
    public var countdown = 3
    public var quality = RecordingQuality.uhd
    public var frameRate = 60
    public init() {}

    public static let countdownRange = 0...10
    public static let frameRates = [30, 60]
}

/// Turns Mickey on with a preset while presentation or meeting apps run.
public struct AutoModeSettings: Codable, Equatable, Sendable {
    public var enabled = false
    public var preset = Preset.presentation
    public var bundleIDs = AutoModeSettings.defaultBundleIDs
    /// Preset to use for a given watched app instead of `preset`.
    public var appPresets: [String: Preset] = [:]
    public init() {}

    /// Names of the apps watched by default, for display.
    public static let appNames = [
        "us.zoom.xos": "Zoom", "com.microsoft.teams2": "Microsoft Teams", "com.microsoft.teams": tr("Microsoft Teams (classic)"),
        "com.apple.FaceTime": "FaceTime", "com.apple.Keynote": "Keynote", "com.microsoft.Powerpoint": "PowerPoint",
        "com.apple.QuickTimePlayerX": "QuickTime Player", "com.obsproject.obs-studio": "OBS", "com.loom.desktop": "Loom",
        "com.cisco.webexmeetingsapp": "Webex", "com.hnc.Discord": "Discord",
    ]

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
        case .inputMonitoring: tr("Input Monitoring")
        case .screenRecording: tr("Screen Recording")
        case .camera: tr("Camera")
        case .microphone: tr("Microphone")
        case .speechRecognition: tr("Speech Recognition")
        }
    }

    public var reason: String {
        switch self {
        case .inputMonitoring: tr("Needed to read which shortcuts you type. Mickey never records text.")
        case .screenRecording: tr("Needed to magnify the screen and to record it.")
        case .camera: tr("Needed to show your webcam in the bubble.")
        case .microphone: tr("Needed to hear you for live captions.")
        case .speechRecognition: tr("Needed to turn your voice into captions, on your Mac when supported.")
        }
    }
}

public enum PermissionStatus: Equatable, Sendable {
    case granted, notDetermined, denied
}
