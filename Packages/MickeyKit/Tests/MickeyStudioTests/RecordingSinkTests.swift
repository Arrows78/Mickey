import AVFoundation
import CoreMedia
import CoreVideo
import ScreenCaptureKit
import Testing
import MickeyDomain
@testable import MickeyStudio

/// Feeds the sink synthetic frames, so pausing is tested on a real movie without the screen or any permission.
@Suite("Recording sink", .serialized)
struct RecordingSinkTests {
    let width = 320, height = 240, fps = 30

    private func frame(at seconds: Double) throws -> CMSampleBuffer {
        var pixels: CVPixelBuffer?
        CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, nil, &pixels)
        let buffer = try #require(pixels)
        CVPixelBufferLockBaseAddress(buffer, [])
        memset(CVPixelBufferGetBaseAddress(buffer), Int32(seconds * 40) & 0xff, CVPixelBufferGetDataSize(buffer))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        var format: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: buffer, formatDescriptionOut: &format)
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: CMTimeScale(fps)),
                                        presentationTimeStamp: CMTime(seconds: seconds, preferredTimescale: 600),
                                        decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(allocator: nil, imageBuffer: buffer, formatDescription: try #require(format),
                                                 sampleTiming: &timing, sampleBufferOut: &sample)
        return try #require(sample)
    }

    private func makeSink() throws -> (RecordingSink, URL) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mickey-sink-\(UUID().uuidString).mov")
        let sink = try RecordingSink(url: url, width: width, height: height, withAudio: false, frameRate: fps, codec: .h264,
                                     isCompleteFrame: { _ in true })
        return (sink, url)
    }

    /// Feeds one frame per 1/fps second from `from` (inclusive) to `to` (exclusive).
    private func feed(_ sink: RecordingSink, from: Double, to: Double) throws {
        var t = from
        while t < to - 0.0001 {
            sink.append(try frame(at: t), type: .screen)
            Thread.sleep(forTimeInterval: 0.004)
            t += 1 / Double(fps)
        }
    }

    private func finish(_ sink: RecordingSink) async -> String? {
        await withCheckedContinuation { c in sink.finish { c.resume(returning: $0) } }
    }

    private func duration(of url: URL) async throws -> Double {
        try await AVURLAsset(url: url).load(.duration).seconds
    }

    @Test func aPauseIsCutFromTheMovie() async throws {
        let (sink, url) = try makeSink()
        defer { try? FileManager.default.removeItem(at: url) }
        try feed(sink, from: 10, to: 11)       // 1 s recorded
        sink.pause()
        try feed(sink, from: 11, to: 14)       // 3 s on screen while paused: dropped
        sink.resume()
        try feed(sink, from: 14, to: 15)       // 1 s recorded
        #expect(await finish(sink) == nil)
        let seconds = try await duration(of: url)
        #expect(seconds > 1.7 && seconds < 2.4, "movie lasts \(seconds) s instead of about 2")
    }

    @Test func withoutAPauseTheMovieKeepsItsLength() async throws {
        let (sink, url) = try makeSink()
        defer { try? FileManager.default.removeItem(at: url) }
        try feed(sink, from: 5, to: 7)
        #expect(await finish(sink) == nil)
        let seconds = try await duration(of: url)
        #expect(seconds > 1.8 && seconds < 2.3, "movie lasts \(seconds) s instead of about 2")
    }

    @Test func severalPausesAddUp() async throws {
        let (sink, url) = try makeSink()
        defer { try? FileManager.default.removeItem(at: url) }
        try feed(sink, from: 0, to: 0.5)
        sink.pause(); try feed(sink, from: 0.5, to: 2.5); sink.resume()
        try feed(sink, from: 2.5, to: 3.0)
        sink.pause(); try feed(sink, from: 3.0, to: 5.0); sink.resume()
        try feed(sink, from: 5.0, to: 5.5)
        #expect(await finish(sink) == nil)
        let seconds = try await duration(of: url)
        #expect(seconds > 1.3 && seconds < 1.8, "movie lasts \(seconds) s instead of about 1.5")
    }

    @Test func pausingBeforeAnyFrameStillRecordsAfterwards() async throws {
        let (sink, url) = try makeSink()
        defer { try? FileManager.default.removeItem(at: url) }
        sink.pause()
        try feed(sink, from: 0, to: 1)
        sink.resume()
        try feed(sink, from: 1, to: 2)
        #expect(await finish(sink) == nil)
        let seconds = try await duration(of: url)
        #expect(seconds > 0.8 && seconds < 1.3, "movie lasts \(seconds) s instead of about 1")
    }

    @Test func aMovieWithoutFramesReportsIt() async throws {
        let (sink, url) = try makeSink()
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(await finish(sink) == "No frame was captured.")
    }
}

@Suite("Recording clock") struct RecordingClockTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 1000)

    @Test func countsTimeWhileRunning() {
        let clock = RecordingClock(startedAt: t0)
        #expect(clock.elapsed(at: t0.addingTimeInterval(65)) == 65)
        #expect(!clock.isPaused)
    }

    @Test func freezesWhilePaused() {
        var clock = RecordingClock(startedAt: t0)
        clock.pause(at: t0.addingTimeInterval(10))
        #expect(clock.isPaused)
        #expect(clock.elapsed(at: t0.addingTimeInterval(500)) == 10)
    }

    @Test func resumingContinuesWithoutTheTimePaused() {
        var clock = RecordingClock(startedAt: t0)
        clock.pause(at: t0.addingTimeInterval(10))
        clock.resume(at: t0.addingTimeInterval(40))
        #expect(clock.elapsed(at: t0.addingTimeInterval(45)) == 15)
    }

    @Test func pausingTwiceOrResumingWhenRunningChangesNothing() {
        var clock = RecordingClock(startedAt: t0)
        clock.resume(at: t0.addingTimeInterval(5))
        clock.pause(at: t0.addingTimeInterval(10))
        clock.pause(at: t0.addingTimeInterval(20))
        #expect(clock.elapsed(at: t0.addingTimeInterval(30)) == 10)
    }

    @Test func elapsedNeverGoesNegative() {
        let clock = RecordingClock(startedAt: t0)
        #expect(clock.elapsed(at: t0.addingTimeInterval(-5)) == 0)
    }
}
