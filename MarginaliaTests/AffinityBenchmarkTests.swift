import Foundation
import Testing
@testable import Marginalia

/// **The measurement `docs/issues.md` §15 asked for.**
///
/// The recompute is O(N²) and nobody had ever timed it. The paragraph that
/// stood in for a number said "seconds at five thousand notes, on a background
/// actor" — this is what replaces it, and the numbers it prints belong in
/// `docs/planning.md` rather than in anybody's memory.
///
/// Off by default, like `AffinityDumpTests`, because it belongs to a decision
/// rather than to a regression — and because the largest size takes long enough
/// to notice:
///
/// ```bash
/// TEST_RUNNER_MARGINALIA_BENCH=1 xcodebuild -scheme Marginalia \
///   -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath .build \
///   test -only-testing:MarginaliaTests/AffinityBenchmarkTests 2>&1 | grep '^|'
/// ```
///
/// **It measures the scoring, not the embedding.** `AffinityEngine` is the
/// quadratic half and the one whose cost is a function of library size alone;
/// embedding is linear, runs once per note, and on this machine can only be
/// measured through the fallback model (`docs/issues.md` §14), so a number from
/// it would be a number about the wrong model.
///
/// Every line starts with `|`, so it survives an `xcodebuild` log.
struct AffinityBenchmarkTests {

    /// 512, which is what `NLContextualEmbedding` returns — measuring against
    /// the fallback's width would flatter the result by a factor of four.
    private let width = 512

    private let sizes = [100, 250, 500, 1_000]

    @Test(.enabled(if: benchmarkWasAskedFor()))
    func timeAFullRecompute() {
        say("")
        say("AffinityEngine.links · \(width)d vectors · \(build) · simulator")
        say("")
        say("| notes |     pairs |    ms |  µs/pair | edges |")
        say("|------:|----------:|------:|---------:|------:|")

        for count in sizes {
            let subjects = library(of: count)

            let started = Date.now
            let links = AffinityEngine.links(among: subjects)
            let elapsed = Date.now.timeIntervalSince(started)

            let pairs = count * (count - 1) / 2
            say(String(format: "| %5d | %9d | %5.0f | %8.2f | %5d |",
                       count, pairs, elapsed * 1_000,
                       elapsed * 1_000_000 / Double(pairs), links.count))
        }

        say("")
        say("the pass runs off the main actor in `LinkWriter`, so this is latency")
        say("before the graph updates, not time the app is frozen for.")
        say("")
    }

    // MARK: A library that isn't real but is the right shape

    /// Deterministic, and deliberately not random: the same run twice should
    /// produce the same number, or a comparison between two of them means
    /// nothing. The same reason `GraphLayout` starts on a phyllotaxis spiral.
    ///
    /// Vectors are spread over a handful of directions with noise on top, so the
    /// scores land in a plausible spread rather than all at zero — an engine
    /// scoring orthogonal noise would take the same time but prune everything,
    /// and the edge count in the table would say nothing.
    private func library(of count: Int) -> [AffinityEngine.Subject] {
        let themes = 8
        let vocabulary = ["attention", "error", "quality", "memory", "systems", "craft"]

        return (0..<count).map { id in
            let theme = id % themes
            var vector = [Float](repeating: 0, count: width)
            var seed = UInt64(id &+ 1)

            for slot in 0..<width {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                let noise = Float(Int(seed >> 33) % 2_000 - 1_000) / 1_000
                // The theme is the signal; the noise is everything else about
                // one note. Two notes on a theme are close but never identical.
                vector[slot] = (slot % themes == theme ? 1 : 0) + noise * 0.35
            }

            let length = sqrt(vector.reduce(0) { $0 + $1 * $1 })
            if length > 0 { for slot in 0..<width { vector[slot] /= length } }

            return AffinityEngine.Subject(
                id: id,
                vector: vector,
                tags: [vocabulary[id % vocabulary.count], vocabulary[(id / 7) % vocabulary.count]]
            )
        }
    }

    /// **Which build this was matters more than anything else in the table.**
    /// The same pass is 62× slower unoptimized, so a number taken from a plain
    /// `test` run says nothing about the app anybody installs. Release needs
    /// `SWIFT_ENABLE_TESTABILITY=YES` to let `@testable` through:
    ///
    /// ```bash
    /// TEST_RUNNER_MARGINALIA_BENCH=1 xcodebuild -scheme Marginalia \
    ///   -configuration Release SWIFT_ENABLE_TESTABILITY=YES \
    ///   -destination 'platform=iOS Simulator,name=iPhone 17' \
    ///   -derivedDataPath .build-release \
    ///   test -only-testing:MarginaliaTests/AffinityBenchmarkTests 2>&1 | grep '^|'
    /// ```
    private var build: String {
        #if DEBUG
        "debug — 60× slower than what ships, see the doc comment"
        #else
        "release, -O"
        #endif
    }

    private func say(_ line: String) { print("| \(line)") }
}

private nonisolated func benchmarkWasAskedFor() -> Bool {
    ProcessInfo.processInfo.environment["MARGINALIA_BENCH"] == "1"
}
