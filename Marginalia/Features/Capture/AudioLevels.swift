import Foundation

/// The recording waveform, as a pure function of what the microphone heard.
///
/// `AVAudioEngine` hands back average power in dBFS; this turns that into an
/// index into `Glyphs.waveBars` and keeps the last N of them. Pure because the
/// alternative is judging a recording animation by eye, and the simulator has
/// no microphone to drive it with.
nonisolated enum AudioLevels {

    /// Quieter than this is silence. Room tone sits around −60, so a lower
    /// floor would leave the waveform twitching in an empty room.
    private static let floor: Float = -50

    private static var tallest: Int { Glyphs.waveBars.count - 1 }

    /// dBFS → a bar, `0` silent and `6` full scale. Clamped at both ends: a
    /// clipped sample reads above zero and the glyph table has to hold it.
    static func bar(power dB: Float) -> Int {
        let fraction = (dB - floor) / -floor
        let scaled = (fraction * Float(tallest)).rounded()
        return min(max(Int(scaled), 0), tallest)
    }

    static func silence(width: Int) -> [Int] {
        Array(repeating: 0, count: max(0, width))
    }

    /// Appends a bar and drops the oldest, so the waveform reads left to right
    /// with the newest sample at the end.
    static func scrolling(_ levels: [Int], adding bar: Int, width: Int) -> [Int] {
        (levels + [bar]).suffix(max(1, width))
    }
}
