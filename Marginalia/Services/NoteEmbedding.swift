import Foundation
import NaturalLanguage

/// Which vectorizer produced a stored embedding.
///
/// It has to be stored alongside the vector, because **vectors from two
/// different models are not comparable.** A cosine between a contextual vector
/// and a sentence-embedding vector is a number with no meaning, and mixing them
/// would silently poison every score in `AffinityEngine`. So a note whose stored
/// source isn't the one in use today is stale and gets re-embedded — which is
/// exactly what happens the first time Apple's contextual assets finish
/// downloading, on a library that was embedded by the fallback before them.
nonisolated enum EmbeddingSource: String, Sendable, CaseIterable {
    /// `NLContextualEmbedding`. Meaning rather than vocabulary, and what the
    /// app wants. Needs a one-time asset download.
    case contextual
    /// `NLEmbedding.sentenceEmbedding`. Lower quality, present since iOS 14,
    /// and what makes the app work on first launch before the assets arrive.
    case sentence
}

/// Turns a note's text into one vector.
///
/// `nonisolated` for the reason in `docs/issues.md` §1: the project builds with
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, and both `enumerateTokenVectors`
/// and `requestEmbeddingAssets` hand a closure to a system framework that calls
/// it back on its own thread. A `@MainActor` closure entered from there is a
/// `SIGTRAP`, not a compile error.
///
/// **Not `Sendable`, on purpose.** The `NL` model objects it holds make no
/// thread-safety promise, so this is built inside whatever task is going to use
/// it and only the `[Float]` it produces crosses back. See `LinkWriter`.
nonisolated struct NoteEmbedding {

    /// Which of the two is actually loaded. Written onto every note this
    /// instance embeds.
    let source: EmbeddingSource

    private let contextual: NLContextualEmbedding?
    private let sentence: NLEmbedding?

    /// Loads the best vectorizer available **right now**, contextual first.
    ///
    /// `nil` when neither loads — a language pack that isn't there, an OS that
    /// won't hand over the sentence model. That's a library with no connections
    /// rather than a crash, which is the right failure for a feature nobody
    /// asked for.
    init?() {
        if let model = NLContextualEmbedding(language: .english),
           model.hasAvailableAssets,
           (try? model.load()) != nil {
            source = .contextual
            contextual = model
            sentence = nil
            return
        }

        guard let model = NLEmbedding.sentenceEmbedding(for: .english) else { return nil }
        source = .sentence
        contextual = nil
        sentence = model
    }

    /// One unit-length vector for a note, or `nil` when the text carries nothing
    /// to embed.
    ///
    /// Unit length is not a detail: `AffinityEngine` scores on cosine, and
    /// normalizing once here is the difference between a dot product and a
    /// square root per pair.
    func vector(for text: String) -> [Float]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let values = contextual.map { pooled(trimmed, with: $0) } ?? sentence.flatMap { pooled(trimmed, with: $0) }
        guard let values, !values.isEmpty else { return nil }
        return Self.normalized(values.map(Float.init))
    }

    /// Mean-pooled over every token vector the model produces. A note is a
    /// paragraph, and the model speaks in tokens.
    private func pooled(_ text: String, with model: NLContextualEmbedding) -> [Double]? {
        guard let result = try? model.embeddingResult(for: text, language: .english) else { return nil }

        var total = [Double](repeating: 0, count: model.dimension)
        var count = 0
        result.enumerateTokenVectors(in: text.startIndex..<text.endIndex) { vector, _ in
            guard vector.count == total.count else { return true }
            for index in vector.indices { total[index] += vector[index] }
            count += 1
            return true
        }

        guard count > 0 else { return nil }
        return total.map { $0 / Double(count) }
    }

    /// The fallback path. `sentenceEmbedding` takes a whole string, but it was
    /// trained on sentences and returns `nil` on some longer ones — so a note it
    /// won't take whole is averaged over its sentences rather than dropped.
    private func pooled(_ text: String, with model: NLEmbedding) -> [Double]? {
        if let vector = model.vector(for: text) { return vector }

        var total = [Double](repeating: 0, count: model.dimension)
        var count = 0
        for sentence in Self.sentences(in: text) {
            guard let vector = model.vector(for: sentence), vector.count == total.count else { continue }
            for index in vector.indices { total[index] += vector[index] }
            count += 1
        }

        guard count > 0 else { return nil }
        return total.map { $0 / Double(count) }
    }

    private static func sentences(in text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        return tokenizer.tokens(for: text.startIndex..<text.endIndex).map { String(text[$0]) }
    }

    static func normalized(_ values: [Float]) -> [Float] {
        let magnitude = values.reduce(into: Float(0)) { $0 += $1 * $1 }.squareRoot()
        guard magnitude > 0 else { return values }
        return values.map { $0 / magnitude }
    }

    // MARK: The assets

    /// Asks for the contextual assets, once.
    ///
    /// **Call this from a task nothing is waiting on.** `requestAssets()` is
    /// async-only — the completion-handler form isn't imported — and it doesn't
    /// return until the download does. The app embeds with the fallback
    /// meanwhile and re-embeds when the better model turns up; nothing on screen
    /// mentions any of it, because a reader told their connections were
    /// "provisional" would have no action to take.
    static func requestAssetsIfNeeded() async {
        guard let model = NLContextualEmbedding(language: .english), !model.hasAvailableAssets else { return }
        _ = try? await model.requestAssets()
    }

    // MARK: Storage

    /// Packed little-endian `Float32`, which is what `Note.embedding` holds —
    /// `[Float]` isn't a type CloudKit will take, and `Data` is.
    ///
    /// The byte order is written out rather than assumed. Every Apple platform
    /// is little-endian today, but a vector that crosses devices through sync
    /// and comes back reversed would read as a note that connects to nothing,
    /// which is not a bug anyone would find quickly.
    static func pack(_ values: [Float]) -> Data {
        var data = Data(capacity: values.count * 4)
        for value in values {
            withUnsafeBytes(of: value.bitPattern.littleEndian) { data.append(contentsOf: $0) }
        }
        return data
    }

    static func unpack(_ data: Data) -> [Float] {
        guard data.count % 4 == 0 else { return [] }
        return stride(from: 0, to: data.count, by: 4).map { offset in
            let bits = data[data.startIndex + offset ..< data.startIndex + offset + 4]
                .reversed()
                .reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            return Float(bitPattern: bits)
        }
    }
}
