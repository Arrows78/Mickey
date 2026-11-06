import AppKit
import AVFoundation
import CoreMedia
import ScreenCaptureKit
import MickeyDomain

/// Writes captured samples to a movie. Used only from the capture queue.
nonisolated final class RecordingSink: @unchecked Sendable {
    private let writer: AVAssetWriter
    private let video: AVAssetWriterInput
    private let audio: AVAssetWriterInput?
    private let frameDuration: CMTime
    private let isCompleteFrame: @Sendable (CMSampleBuffer) -> Bool
    private var started = false
    private var paused = false
    /// Set by `resume()`: the next frame decides how much time the pause removes from the movie.
    private var resumePending = false
    /// Shift applied to the timestamps of the samples written after a pause.
    private var offset = CMTime.zero
    /// Where the last written frame ends, in movie time.
    private var lastVideoEnd: CMTime?
    private let lock = NSLock()

    /// `codec` and `isCompleteFrame` are only changed by tests, which feed the sink synthetic frames.
    init(url: URL, width: Int, height: Int, withAudio: Bool, frameRate: Int = 60, codec: AVVideoCodecType = .hevc,
         isCompleteFrame: @escaping @Sendable (CMSampleBuffer) -> Bool = ScreenCapture.isCompleteFrame) throws {
        self.isCompleteFrame = isCompleteFrame
        frameDuration = CMTime(value: 1, timescale: CMTimeScale(max(frameRate, 1)))
        writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        video = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: codec, AVVideoWidthKey: width, AVVideoHeightKey: height,
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

    /// Stops writing; samples that arrive meanwhile are dropped.
    func pause() { lock.withLock { paused = true } }

    /// Writing continues right after the last frame: the time spent paused is cut from the movie.
    func resume() {
        lock.withLock {
            guard paused else { return }
            paused = false
            resumePending = true
        }
    }

    func append(_ sample: CMSampleBuffer, type: SCStreamOutputType) {
        lock.withLock {
            guard !paused else { return }
            switch type {
            case .screen:
                guard isCompleteFrame(sample), sample.imageBuffer != nil else { return }
                if resumePending {
                    if let end = lastVideoEnd { offset = CMTimeSubtract(sample.presentationTimeStamp, end) }
                    resumePending = false
                }
                guard let shifted = retimed(sample) else { return }
                if !started {
                    guard writer.startWriting() else { return }
                    writer.startSession(atSourceTime: shifted.presentationTimeStamp)
                    started = true
                }
                if video.isReadyForMoreMediaData, video.append(shifted) {
                    lastVideoEnd = CMTimeAdd(shifted.presentationTimeStamp, frameDuration)
                }
            case .audio:
                // Audio waits for the first frame after a pause, which fixes the shift.
                guard started, !resumePending, let audio, audio.isReadyForMoreMediaData, let shifted = retimed(sample) else { return }
                audio.append(shifted)
            default:
                break
            }
        }
    }

    /// `sample` with its timestamps moved back by the time cut from the movie, or as is when nothing was cut.
    private func retimed(_ sample: CMSampleBuffer) -> CMSampleBuffer? {
        guard offset != .zero else { return sample }
        var count: CMItemCount = 0
        CMSampleBufferGetSampleTimingInfoArray(sample, entryCount: 0, arrayToFill: nil, entriesNeededOut: &count)
        var infos = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(), count: count)
        CMSampleBufferGetSampleTimingInfoArray(sample, entryCount: count, arrayToFill: &infos, entriesNeededOut: &count)
        for i in infos.indices {
            infos[i].presentationTimeStamp = CMTimeSubtract(infos[i].presentationTimeStamp, offset)
            if infos[i].decodeTimeStamp.isValid { infos[i].decodeTimeStamp = CMTimeSubtract(infos[i].decodeTimeStamp, offset) }
        }
        var out: CMSampleBuffer?
        let status = CMSampleBufferCreateCopyWithNewTiming(allocator: nil, sampleBuffer: sample, sampleTimingEntryCount: count,
                                                           sampleTimingArray: &infos, sampleBufferOut: &out)
        return status == noErr ? out : nil
    }

    /// Finishes the file; the completion receives an error message, if any.
    func finish(_ completion: @escaping @Sendable (String?) -> Void) {
        lock.withLock {
            guard started else {
                writer.cancelWriting()
                completion(tr("No frame was captured."))
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
    private(set) var isPaused = false

    /// Stops adding to the movie; the capture keeps running so that resuming is instant.
    func pause() {
        guard stream != nil, !isPaused else { return }
        isPaused = true
        box.current?.pause()
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        box.current?.resume()
    }

    static var folder: URL {
        FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0].appendingPathComponent("Mickey", isDirectory: true)
    }

    func start(on screen: NSScreen, settings: RecorderSettings) {
        guard stream == nil, !starting else { return }
        starting = true
        stopRequested = false
        isPaused = false
        Task {
            do {
                let (display, _, _) = try await ScreenCapture.target(for: screen)
                let config = ScreenCapture.configuration(for: screen, showsCursor: settings.showCursor)
                // Keep files and encoding load reasonable on large Retina screens.
                (config.width, config.height) = settings.quality.outputSize(width: config.width, height: config.height)
                config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(settings.frameRate))
                config.capturesAudio = settings.captureSystemAudio
                config.sampleRate = 48_000
                config.channelCount = 2
                try FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
                let url = Self.folder.appendingPathComponent(RecordingNaming.fileName(for: Date()))
                box.set(try RecordingSink(url: url, width: config.width, height: config.height, withAudio: settings.captureSystemAudio,
                                          frameRate: settings.frameRate))
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
        isPaused = false
        let url = self.url
        let box = self.box
        Task { [weak self] in
            try? await stream.stopCapture()
            guard let sink = box.current else {
                self?.onFinished?(nil, tr("Recording failed."))
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
                self.isPaused = false
                self.box.current?.finish { _ in }
                self.box.set(nil)
                self.onFinished?(nil, message)
                self.finishStopping()
            }
        }
    }
}
