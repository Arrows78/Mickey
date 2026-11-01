import AppKit
import AVFoundation
import ScreenCaptureKit
import MickeyDomain

/// Writes captured samples to a movie. Used only from the capture queue.
nonisolated final class RecordingSink: @unchecked Sendable {
    private let writer: AVAssetWriter
    private let video: AVAssetWriterInput
    private let audio: AVAssetWriterInput?
    private var started = false
    private let lock = NSLock()

    init(url: URL, width: Int, height: Int, withAudio: Bool) throws {
        writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        video = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.hevc, AVVideoWidthKey: width, AVVideoHeightKey: height,
        ])
        video.expectsMediaDataInRealTime = true
        writer.add(video)
        if withAudio {
            let a = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48_000, AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 160_000,
            ])
            a.expectsMediaDataInRealTime = true
            writer.add(a)
            audio = a
        } else {
            audio = nil
        }
    }

    func append(_ sample: CMSampleBuffer, type: SCStreamOutputType) {
        lock.withLock {
            switch type {
            case .screen:
                guard ScreenCapture.isCompleteFrame(sample), sample.imageBuffer != nil else { return }
                if !started {
                    guard writer.startWriting() else { return }
                    writer.startSession(atSourceTime: sample.presentationTimeStamp)
                    started = true
                }
                if video.isReadyForMoreMediaData { video.append(sample) }
            case .audio:
                if started, let audio, audio.isReadyForMoreMediaData { audio.append(sample) }
            default:
                break
            }
        }
    }

    /// Finishes the file; the completion receives an error message, if any.
    func finish(_ completion: @escaping @Sendable (String?) -> Void) {
        lock.withLock {
            guard started else {
                writer.cancelWriting()
                completion("No frame was captured.")
                return
            }
            video.markAsFinished()
            audio?.markAsFinished()
            nonisolated(unsafe) let writer = self.writer
            writer.finishWriting { completion(writer.error?.localizedDescription) }
        }
    }
}

nonisolated final class SinkBox: @unchecked Sendable {
    private let lock = NSLock()
    private var sink: RecordingSink?
    func set(_ s: RecordingSink?) { lock.withLock { sink = s } }
    var current: RecordingSink? { lock.withLock { sink } }
}

/// Records the screen under the pointer, Mickey's effects included, to ~/Movies/Mickey.
final class ScreenRecorder: NSObject, SCStreamOutput, SCStreamDelegate {
    var onStarted: (() -> Void)?
    var onFinished: ((URL?, String?) -> Void)?

    private var stream: SCStream?
    private var url: URL?
    private let box = SinkBox()
    private let queue = DispatchQueue(label: "dev.local.mickey.recorder")
    /// Capture is being set up: a stop request waits for it instead of being lost.
    private var starting = false
    private var stopRequested = false
    private var stopCompletions: [() -> Void] = []

    var isRecording: Bool { stream != nil || starting }

    static var folder: URL {
        FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0].appendingPathComponent("Mickey", isDirectory: true)
    }

    func start(on screen: NSScreen, settings: RecorderSettings) {
        guard stream == nil, !starting else { return }
        starting = true
        stopRequested = false
        Task {
            do {
                let (display, _) = try await ScreenCapture.target(for: screen)
                let config = ScreenCapture.configuration(for: screen, showsCursor: settings.showCursor)
                // Keep files and encoding load reasonable on large Retina screens.
                let scale = min(1, 3840 / Double(config.width))
                config.width = Int(Double(config.width) * scale) / 2 * 2
                config.height = Int(Double(config.height) * scale) / 2 * 2
                config.capturesAudio = settings.captureSystemAudio
                config.sampleRate = 48_000
                config.channelCount = 2
                try FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
                let url = Self.folder.appendingPathComponent(RecordingNaming.fileName(for: Date()))
                box.set(try RecordingSink(url: url, width: config.width, height: config.height, withAudio: settings.captureSystemAudio))
                let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
                let stream = SCStream(filter: filter, configuration: config, delegate: self)
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
                if settings.captureSystemAudio { try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue) }
                try await stream.startCapture()
                self.stream = stream
                self.url = url
                starting = false
                onStarted?()
                if stopRequested { stop() }
            } catch {
                starting = false
                box.set(nil)
                onFinished?(nil, error.localizedDescription)
                finishStopping()
            }
        }
    }

    /// Stops the recording. `completion` runs once the movie is written, or right away if nothing records.
    func stop(completion: (() -> Void)? = nil) {
        if let completion { stopCompletions.append(completion) }
        if starting { stopRequested = true; return }
        guard let stream else { finishStopping(); return }
        self.stream = nil
        let url = self.url
        let box = self.box
        Task { [weak self] in
            try? await stream.stopCapture()
            guard let sink = box.current else {
                self?.onFinished?(nil, "Recording failed.")
                self?.finishStopping()
                return
            }
            box.set(nil)
            sink.finish { error in
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        self?.onFinished?(error == nil ? url : nil, error)
                        self?.finishStopping()
                    }
                }
            }
        }
    }

    private func finishStopping() {
        let completions = stopCompletions
        stopCompletions.removeAll()
        completions.forEach { $0() }
    }

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sample: CMSampleBuffer, of type: SCStreamOutputType) {
        box.current?.append(sample, type: type)
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        let message = error.localizedDescription
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                guard self.stream != nil else { return }
                self.stream = nil
                self.box.current?.finish { _ in }
                self.box.set(nil)
                self.onFinished?(nil, message)
                self.finishStopping()
            }
        }
    }
}
