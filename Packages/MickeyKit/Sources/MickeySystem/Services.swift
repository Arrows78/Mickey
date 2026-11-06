import AppKit
import AVFoundation
import AudioToolbox
import MickeyDomain
import ServiceManagement
import UniformTypeIdentifiers

/// "Launch at login" through the system login item service.
public final class LoginItemService {
    public init() {}

    public var state: LoginItemState {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        default: .disabled
        }
    }

    public func setEnabled(_ enabled: Bool) -> LoginItemState {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return state
        } catch {
            let message = enabled
                ? tr("macOS could not add Mickey to your login items. You can add it in System Settings › General › Login Items.")
                : tr("macOS could not remove Mickey from your login items. You can remove it in System Settings › General › Login Items.")
            return state == .requiresApproval ? .requiresApproval : .failed(message)
        }
    }

    public func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}

/// Click sound playback with a system-sound fallback.
public final class SoundPlayer {
    private var player: AVAudioPlayer?
    private var loadedURL: URL?
    private var scopedURL: URL?
    private let defaultURL: URL?

    public init(defaultSoundURL: URL?) { defaultURL = defaultSoundURL }

    /// Prepares the sound for the given settings. Returns false if a custom sound could not be loaded.
    @discardableResult
    public func configure(custom: SoundReference?) -> Bool {
        var ok = true
        var url = defaultURL
        if let custom {
            if let resolved = Self.resolve(custom) { url = resolved } else { ok = false }
        }
        guard url != loadedURL else { return ok }
        scopedURL?.stopAccessingSecurityScopedResource(); scopedURL = nil
        if let url, custom != nil, url.startAccessingSecurityScopedResource() { scopedURL = url }
        loadedURL = url
        player = url.flatMap { try? AVAudioPlayer(contentsOf: $0) }
        player?.prepareToPlay()
        if custom != nil && player == nil { ok = false; player = defaultURL.flatMap { try? AVAudioPlayer(contentsOf: $0) } }
        return ok
    }

    public func play(volume: Double) {
        guard let player else { NSSound.beep(); return }
        player.volume = Float(volume)
        player.currentTime = 0
        if !player.play() { AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_UserPreferredAlert)) }
    }

    /// Shows an open panel and returns a bookmark for the chosen audio file.
    public static func chooseCustomSound() -> SoundReference? {
        let panel = NSOpenPanel()
        panel.title = tr("Choose a Click Sound")
        panel.message = tr("Pick an audio file to play on each click.")
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                                               includingResourceValuesForKeys: nil, relativeTo: nil)
        else { return nil }
        return SoundReference(bookmark: data, displayName: url.lastPathComponent)
    }

    static func resolve(_ ref: SoundReference) -> URL? {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: ref.bookmark, options: .withSecurityScope,
                                 relativeTo: nil, bookmarkDataIsStale: &stale),
              FileManager.default.fileExists(atPath: url.path) || url.startAccessingSecurityScopedResource()
        else { return nil }
        return url
    }
}

/// Balanced hide/unhide of the system cursor.
///
/// macOS only honours cursor hiding for the active application, so this takes effect while Mickey
/// is frontmost.
public final class CursorVisibility {
    private var hidden = false
    public init() {}

    public func set(hidden shouldHide: Bool) {
        guard shouldHide != hidden else { return }
        hidden = shouldHide
        if shouldHide { CGDisplayHideCursor(CGMainDisplayID()) } else { CGDisplayShowCursor(CGMainDisplayID()) }
    }
}
