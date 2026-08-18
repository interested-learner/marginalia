import Foundation
import Observation
import os

/// The recording flow, exactly as the prototype has it:
/// `[●]` → live waveform and elapsed timer → `■ stop` → `[↻] transcribing…` →
/// the text lands in the field, **editable before saving**.
///
/// Owns the state the capture bar and the capture sheet both draw from, so the
/// two can't diverge. The audio itself belongs to `SpeechTranscription`.
@MainActor
@Observable
final class VoiceCapture {
    enum Phase: Equatable { case idle, recording, transcribing }

    private(set) var phase: Phase = .idle
    private(set) var levels: [Int]
    private(set) var elapsed: TimeInterval = 0

    /// What went wrong, in the app's own words. Shown in place of the row and
    /// cleared the moment the reader does anything else.
    private(set) var problem: String?

    /// 18 bars in the capture bar, 22 in the full sheet.
    let width: Int

    @ObservationIgnored private let speech = SpeechTranscription()
    @ObservationIgnored private var clock: Task<Void, Never>?
    @ObservationIgnored private var startedAt: Date?

    /// Guards the window between the first tap and `phase` becoming
    /// `.recording`, which is two permission prompts long on the one launch
    /// where both appear.
    ///
    /// **`phase` cannot do this job.** It is still `.idle` for the whole of
    /// that window, so a second tap on the record button walks past its guard,
    /// reaches `SpeechTranscription.start` again, and installs a second tap on
    /// the same audio bus — which AVAudioEngine answers with an Objective-C
    /// exception rather than a Swift error, so nothing in this file can catch
    /// it. See `docs/issues.md` §22.
    @ObservationIgnored private var starting = false

    /// Written from the audio thread, read by the clock. The waveform redraws
    /// every 200ms while buffers arrive four times as often, so this holds the
    /// loudest sample in between — a peak reads truer than whichever sample
    /// happened to land on the tick.
    @ObservationIgnored private let peak = OSAllocatedUnfairLock<Float>(initialState: -160)

    init(width: Int = 18) {
        self.width = width
        self.levels = AudioLevels.silence(width: width)
    }

    func clearProblem() { problem = nil }

    func record() async {
        guard phase == .idle, !starting else { return }
        starting = true
        defer { starting = false }

        problem = nil
        levels = AudioLevels.silence(width: width)
        elapsed = 0

        do {
            try await speech.start { [peak] power in
                peak.withLock { $0 = max($0, power) }
            }
        } catch {
            problem = error.message
            return
        }

        startedAt = .now
        phase = .recording
        tick()
    }

    /// Stops, transcribes, and hands back text to edit before saving. Empty
    /// when nothing was heard or the reader stopped immediately.
    func stop() async -> String {
        guard phase == .recording else { return "" }
        clock?.cancel()
        clock = nil
        phase = .transcribing

        let text = await speech.finish()
        phase = .idle
        elapsed = 0
        levels = AudioLevels.silence(width: width)

        if text.isEmpty { problem = "nothing came through — try again, or type it" }
        return text
    }

    /// Throws the recording away. Used when the sheet is dismissed mid-take.
    func cancel() {
        clock?.cancel()
        clock = nil
        speech.cancel()
        phase = .idle
        elapsed = 0
        levels = AudioLevels.silence(width: width)
    }

    /// 200ms, which is what the design system specifies for the waveform and
    /// is fine for a timer that only shows whole seconds.
    private func tick() {
        clock = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self, !Task.isCancelled else { return }
                self.advance()
            }
        }
    }

    private func advance() {
        let power = peak.withLock { held -> Float in
            let value = held
            held = -160
            return value
        }
        levels = AudioLevels.scrolling(levels, adding: AudioLevels.bar(power: power), width: width)
        if let startedAt { elapsed = Date.now.timeIntervalSince(startedAt) }
    }
}

/// The recording states, stood up without a microphone.
///
/// The simulator has none, so the only way to see the waveform or the
/// transcribing row — let alone screenshot them in both appearances — is to
/// draw them from fixed values. Reached by `-captureBar recording`, the same
/// device `-startTab` and `-openNote` are.
extension VoiceCapture {
    static func demo(_ phase: Phase, width: Int = 18) -> VoiceCapture {
        let capture = VoiceCapture(width: width)
        capture.phase = phase
        capture.elapsed = 7
        let shape = [1, 3, 2, 5, 4, 6, 3, 2, 4, 1, 5, 3]   // reads like speech, not a sine
        capture.levels = (0..<width).map { shape[$0 % shape.count] }
        return capture
    }

    /// `-captureBar recording|transcribing`
    static var launchArgument: Phase? {
        switch UserDefaults.standard.string(forKey: "captureBar") {
        case "recording": .recording
        case "transcribing": .transcribing
        default: nil
        }
    }
}
