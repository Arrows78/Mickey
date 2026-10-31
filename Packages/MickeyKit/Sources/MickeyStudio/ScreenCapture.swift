import AppKit
import CoreMedia
import ScreenCaptureKit

/// IOSurface handed from the capture queue to the main thread.
nonisolated struct SurfaceBox: @unchecked Sendable { let surface: IOSurfaceRef }

/// Shared ScreenCaptureKit plumbing.
enum ScreenCapture {
    /// The display matching `screen`, plus Mickey itself so it can be excluded from what is captured.
    static func target(for screen: NSScreen) async throws -> (SCDisplay, [SCRunningApplication]) {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == screen.displayIDValue }) else {
            throw CaptureError.displayNotFound
        }
        let me = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        return (display, me)
    }

    static func configuration(for screen: NSScreen, showsCursor: Bool) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.width = Int(screen.frame.width * screen.backingScaleFactor)
        config.height = Int(screen.frame.height * screen.backingScaleFactor)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = showsCursor
        config.queueDepth = 5
        return config
    }

    /// True for sample buffers that carry a new, complete frame.
    nonisolated static func isCompleteFrame(_ sample: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let raw = attachments.first?[.status] as? Int, let status = SCFrameStatus(rawValue: raw)
        else { return false }
        return status == .complete
    }
}

enum CaptureError: LocalizedError {
    case displayNotFound

    var errorDescription: String? { "The screen to capture could not be found." }
}

extension NSScreen {
    var displayIDValue: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }

    /// Screen under `point`, in Cocoa coordinates.
    static func containing(_ point: CGPoint) -> NSScreen? {
        screens.first { $0.frame.contains(point) } ?? main
    }
}

/// Live frames of one display, without Mickey's own windows (so the magnifiers never see themselves).
final class ScreenFrameSource: NSObject, SCStreamOutput, SCStreamDelegate {
    var onFrame: ((IOSurfaceRef) -> Void)?
    var onError: ((String) -> Void)?

    private var stream: SCStream?
    private(set) var screenFrame: CGRect?
    private var starting = false
    private let queue = DispatchQueue(label: "dev.local.mickey.magnifier-frames")

    /// Starts (or switches) capture to `screen`. Does nothing if that screen is already captured.
    func capture(_ screen: NSScreen) {
        guard screenFrame != screen.frame, !starting else { return }
        starting = true
        let frame = screen.frame
        Task {
            defer { starting = false }
            await stopStream()
            do {
                let (display, me) = try await ScreenCapture.target(for: screen)
                let filter = SCContentFilter(display: display, excludingApplications: me, exceptingWindows: [])
                let stream = SCStream(filter: filter, configuration: ScreenCapture.configuration(for: screen, showsCursor: false), delegate: self)
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
                try await stream.startCapture()
                self.stream = stream
                screenFrame = frame
            } catch {
                onError?(error.localizedDescription)
            }
        }
    }

    func stop() {
        screenFrame = nil
        Task { await stopStream() }
    }

    private func stopStream() async {
        guard let stream else { return }
        self.stream = nil
        try? await stream.stopCapture()
    }

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sample: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, ScreenCapture.isCompleteFrame(sample), let buffer = sample.imageBuffer,
              let surface = CVPixelBufferGetIOSurface(buffer)?.takeUnretainedValue() else { return }
        let box = SurfaceBox(surface: surface)
        DispatchQueue.main.async { MainActor.assumeIsolated { self.onFrame?(box.surface) } }
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        let message = error.localizedDescription
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                self.stream = nil
                self.screenFrame = nil
                self.onError?(message)
            }
        }
    }
}
