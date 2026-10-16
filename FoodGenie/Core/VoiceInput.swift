/// Ask by voice with Apple's speech recognition, on the iPhone itself when the device supports it.
/// Words arrive while the shopper speaks (onText); after a short pause, or a tap on stop,
/// onFinal gets the whole question. Nothing is sent to our server except the final text,
/// like a typed question.

import AVFoundation
import Foundation
import Speech

@MainActor
@Observable
final class VoiceInput {
    enum State { case idle, listening, denied, unavailable }

    private(set) var state: State
    private(set) var error: String?

    @ObservationIgnored var onText: (String) -> Void = { _ in }
    @ObservationIgnored var onFinal: (String) -> Void = { _ in }

    // Words speech recognition tends to miss in food questions.
    private static let foodWords = ["Nutri-Score", "seed oils", "protein bar", "gluten-free", "keto", "avocado oil",
                                    "Kroger", "Harris Teeter", "granola", "kombucha", "electrolytes", "monk fruit",
                                    "erythritol"]
    private static let pause: Duration = .seconds(1.6)
    private static let longest: Duration = .seconds(30)

    @ObservationIgnored private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var silence: Task<Void, Never>?
    @ObservationIgnored private var cap: Task<Void, Never>?
    @ObservationIgnored private var latest = ""
    @ObservationIgnored private var finished = true

    init() {
        state = recognizer == nil ? .unavailable : .idle
    }

    func toggle() {
        if state == .listening { finish() } else { Task { await start() } }
    }

    func start() async {
        guard let recognizer, state != .listening else { return }
        error = nil
        guard await Self.speechAllowed(), await AVAudioApplication.requestRecordPermission() else {
            state = .denied
            return
        }
        guard recognizer.isAvailable else {
            error = "Voice isn’t available right now. Please type your question."
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.contextualStrings = Self.foodWords
        request.taskHint = .search
        request.addsPunctuation = false

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let input = engine.inputNode
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
                request.append(buffer)
            }
            engine.prepare()
            try engine.start()
        } catch {
            teardown()
            self.error = "Couldn’t use the microphone. Please try again."
            return
        }

        self.request = request
        latest = ""
        finished = false
        state = .listening
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor in self?.handle(text: text, isFinal: isFinal, failed: failed) }
        }
        cap = Task { [weak self] in
            try? await Task.sleep(for: Self.longest)
            if !Task.isCancelled { self?.finish() }
        }
    }

    private func handle(text: String?, isFinal: Bool, failed: Bool) {
        guard !finished else { return }
        if let text, !text.isEmpty {
            latest = text
            onText(text)
            // iOS keeps listening through silence; a pause ends the question.
            silence?.cancel()
            silence = Task { [weak self] in
                try? await Task.sleep(for: Self.pause)
                if !Task.isCancelled { self?.finish() }
            }
        }
        if isFinal || failed { finish() }
    }

    /// Stops listening and asks with what was heard; silence or nothing heard just stops.
    func finish() {
        guard !finished else { return }
        finished = true
        teardown()
        state = .idle
        let question = latest.trimmingCharacters(in: .whitespacesAndNewlines)
        if !question.isEmpty { onFinal(question) }
    }

    private func teardown() {
        silence?.cancel()
        cap?.cancel()
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func speechAllowed() async -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status != .notDetermined { return status == .authorized }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
    }
}
