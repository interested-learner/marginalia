import Foundation
import AVFoundation
import Speech

/// Microphone in, text out — entirely on the device.
///
/// `requiresOnDeviceRecognition = true` is the whole privacy story: it works on
/// a plane, and nothing recorded here is ever sent anywhere. It also means the
/// transcript can be wrong in ways a server wouldn't be, which is why every
/// caller shows it in an editable field before saving.
///
/// **The simulator cannot exercise this.** It needs a device.
@MainActor
final class SpeechTranscription {

    /// Everything that can go wrong, phrased the way the app talks: lowercase,
    /// and about what the reader can do rather than about the API.
    enum Failure: Error {
        case microphoneDenied
        case speechDenied
        case unavailable
        case audio(String)

        var message: String {
            switch self {
            case .microphoneDenied: "microphone access is off — turn it on in settings"
            case .speechDenied: "speech recognition is off — turn it on in settings"
            case .unavailable: "on-device transcription isn't ready yet — type it instead"
            case .audio(let detail): "recording failed — \(detail)"
            }
        }
    }

    private let engine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale.current)

    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private var transcript = ""
    private var waiting: CheckedContinuation<String, Never>?
    private var watchdog: Task<Void, Never>?

    var isRunning: Bool { request != nil }

    /// Asks for the microphone and for speech recognition **here**, at first
    /// use of the feature — never at launch.
    ///
    /// `onPower` is called from the audio thread's buffer callback with average
    /// power in dBFS; `AudioLevels` turns that into a bar.
    func start(onPower: @escaping @Sendable (Float) -> Void) async throws(Failure) {
        guard await AVAudioApplication.requestRecordPermission() else { throw .microphoneDenied }
        guard await Self.speechAuthorized() else { throw .speechDenied }
        guard let recognizer, recognizer.isAvailable else { throw .unavailable }

        transcript = ""

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            // The tap runs on the audio thread. It hands the buffer straight to
            // the recognizer and hops the level back to the main actor — no
            // state of this object is touched from there.
            nonisolated(unsafe) let sink = request
            input.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, _ in
                sink.append(buffer)
                onPower(Self.power(of: buffer))
            }

            engine.prepare()
            try engine.start()
        } catch {
            engine.inputNode.removeTap(onBus: 0)
            throw .audio(error.localizedDescription)
        }

        self.request = request
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let done = result?.isFinal ?? false
            Task { @MainActor [weak self] in
                self?.absorb(text: text, done: done || error != nil)
            }
        }
    }

    /// Stops recording and returns the transcript, which the caller must show
    /// in an editable field rather than save outright.
    func finish() async -> String {
        guard isRunning else { return transcript }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        request?.endAudio()

        // The recognizer usually settles in well under a second on device, but
        // it is not obliged to. Losing what it already heard would be worse
        // than handing back a partial transcript to edit.
        let text = await withCheckedContinuation { continuation in
            waiting = continuation
            watchdog = Task { [weak self] in
                try? await Task.sleep(for: .seconds(6))
                await self?.settle()
            }
        }
        teardown()
        return text
    }

    /// Abandons the recording without transcribing it.
    func cancel() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        request?.endAudio()
        transcript = ""
        settle()
        teardown()
    }

    // MARK: Plumbing

    private func absorb(text: String?, done: Bool) {
        if let text, !text.isEmpty { transcript = text }
        if done { settle() }
    }

    /// Hands the transcript to whoever is waiting, once.
    private func settle() {
        watchdog?.cancel()
        watchdog = nil
        waiting?.resume(returning: transcript)
        waiting = nil
    }

    private func teardown() {
        task?.cancel()
        task = nil
        request = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func speechAuthorized() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Average power of a buffer, in dBFS. Runs on the audio thread, so it
    /// touches nothing but its argument.
    nonisolated private static func power(of buffer: AVAudioPCMBuffer) -> Float {
        guard let samples = buffer.floatChannelData?[0] else { return -160 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return -160 }

        var sum: Float = 0
        for index in 0..<count {
            let sample = samples[index]
            sum += sample * sample
        }
        let rms = (sum / Float(count)).squareRoot()
        return rms > 0 ? 20 * log10(rms) : -160
    }
}
