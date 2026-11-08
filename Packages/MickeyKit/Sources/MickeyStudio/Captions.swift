import AppKit
import AVFoundation
import Observation
import Speech
import SwiftUI
import MickeyDomain
import MickeyEffects
import MickeySystem

@Observable
final class CaptionModel {
    var text = ""
    var settings = CaptionSettings()
}

struct CaptionView: View {
    let model: CaptionModel

    var body: some View {
        let s = model.settings
        Group {
            if !model.text.isEmpty {
                Text(model.text)
                    .font(.system(size: s.fontSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(s.maxLines)
                    .padding(.horizontal, s.fontSize * 0.7)
                    .padding(.vertical, s.fontSize * 0.35)
                    .background(.black.opacity(s.backgroundOpacity), in: RoundedRectangle(cornerRadius: 12))
                    .frame(maxWidth: s.fontSize * 30)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: hudAlignment(s.position))
    }
}

/// Current recognition request, swapped on restarts and read from the audio thread.
nonisolated final class RequestBox: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?

    func set(_ r: SFSpeechAudioBufferRecognitionRequest?) { lock.withLock { request = r } }
    func append(_ buffer: AVAudioPCMBuffer) { lock.withLock { request }?.append(buffer) }
}

/// Live subtitles: microphone → speech recognizer (on device when supported) → caption bar.
final class Captions {
    var onError: ((String) -> Void)?

    private let model = CaptionModel()
    private let panel = StudioPanel(level: OverlayLevel.toolbar)
    private let engine = AVAudioEngine()
    private let box = RequestBox()
    private var recognizer: SFSpeechRecognizer?
    private var task: SFSpeechRecognitionTask?
    private var restartTimer: Timer?
    private var committed = ""
    private var running = false

    init() {
        let host = NSHostingView(rootView: CaptionView(model: model))
        host.frame = panel.contentView!.bounds
        host.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(host)
    }

    func apply(_ s: CaptionSettings) {
        let languageChanged = s.language != model.settings.language
        model.settings = s
        if s.enabled {
            if running && languageChanged { stop() }
            if !running { start() }
            layout()
        } else {
            stop()
        }
    }

    /// Retries after the user grants a permission.
    func retry() { if model.settings.enabled && !running { start() } }

    private func layout() {
        guard let screen = NSScreen.containing(NSEvent.mouseLocation) else { return }
        let s = model.settings
        let height = s.fontSize * 1.35 * Double(s.maxLines) + s.fontSize + 16
        panel.setFrame(hudFrame(on: screen, position: s.position, height: height), display: false)
    }

    private func start() {
        guard Permissions.status(.microphone) == .granted, Permissions.status(.speechRecognition) == .granted else {
            onError?(tr("Captions need Microphone and Speech recognition access."))
            return
        }
        let locale = model.settings.language.isEmpty ? Locale.current : Locale(identifier: model.settings.language)
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            onError?(trf("Speech recognition is not available for %@.", locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier))
            return
        }
        self.recognizer = recognizer
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        // Without a microphone the format is empty, and installing a tap with it raises an exception.
        guard format.sampleRate > 0, format.channelCount > 0 else {
            onError?(tr("No microphone was found."))
            return
        }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format, block: Self.tap(into: box))
        engine.prepare()
        do { try engine.start() } catch {
            input.removeTap(onBus: 0)
            onError?(trf("The microphone could not start: %@", error.localizedDescription))
            return
        }
        running = true
        committed = ""
        model.text = ""
        beginTask()
        layout()
        panel.orderFrontRegardless()
        // Recognition tasks are limited in length; a fresh one every 50 s keeps captions flowing.
        let t = Timer(timeInterval: 50, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.restartTask() } }
        RunLoop.main.add(t, forMode: .common)
        restartTimer = t
    }

    private func stop() {
        guard running else { panel.orderOut(nil); return }
        running = false
        restartTimer?.invalidate(); restartTimer = nil
        task?.cancel(); task = nil
        box.set(nil)
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        model.text = ""
        panel.orderOut(nil)
    }

    private func beginTask() {
        guard let recognizer else { return }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        box.set(request)
        task = recognizer.recognitionTask(with: request, resultHandler: Self.resultHandler(for: self))
    }

    private func restartTask() {
        guard running else { return }
        committed = model.text
        task?.finish()
        task = nil
        beginTask()
    }

    fileprivate func received(text: String?, isFinal: Bool, error: String?) {
        guard running else { return }
        let capacity = CaptionText.capacity(lines: model.settings.maxLines)
        if let text {
            model.text = CaptionText.tail(of: committed.isEmpty ? text : committed + " " + text, maxChars: capacity)
        }
        if isFinal || error != nil {
            committed = model.text
            // The recognizer ends a task after silence or an error; start listening again.
            DispatchQueue.main.asyncAfter(deadline: .now() + (error == nil ? 0 : 1)) { [weak self] in
                MainActor.assumeIsolated { self?.restartTask() }
            }
        }
    }

    // Callbacks run on audio and recognition threads, so they are built outside the main actor.

    nonisolated private static func tap(into box: RequestBox) -> AVAudioNodeTapBlock {
        { buffer, _ in box.append(buffer) }
    }

    nonisolated private static func resultHandler(for owner: Captions) -> @Sendable (SFSpeechRecognitionResult?, Error?) -> Void {
        { [weak owner] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let message = error.map { ($0 as NSError).localizedDescription }
            DispatchQueue.main.async {
                MainActor.assumeIsolated { owner?.received(text: text, isFinal: isFinal, error: message) }
            }
        }
    }
}
