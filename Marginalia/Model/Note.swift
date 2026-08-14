import Foundation
import SwiftData

/// How a note was captured. Raw strings, for the same reason as `BookStatus`.
nonisolated enum NoteKind: String, CaseIterable, Sendable {
    case quote, thought, voice, scan

    var marker: String {
        switch self {
        case .quote: Glyphs.quote
        case .thought: Glyphs.thought
        case .voice: Glyphs.voice
        case .scan: Glyphs.scan
        }
    }

    var label: String { rawValue }

    /// Somebody else's words, off a page — drawn with the quote rule wherever
    /// the note is shown.
    ///
    /// A scan is one as much as a typed quote is: it was read off a printed
    /// page and it isn't the reader's own sentence. The marker still says how
    /// it arrived — `[s] scan`, never `[q] quote` — because how a note was
    /// captured is a fact about the note, which is the same rule an edited
    /// transcript follows.
    var isPassage: Bool { self == .quote || self == .scan }
}

/// A note. Zettel-style: it carries an id, connects to other notes, and
/// accumulates threaded follow-ups.
@Model
final class Note {
    /// Rendered `n.11`. Allocated by `ShortIDCounter` and never reused.
    var shortID: Int = 0
    var kindRaw: String = NoteKind.thought.rawValue
    var text: String = ""
    var page: Int?
    /// Stored bare — `systems`, not `#systems`. The hash is presentation.
    var tags: [String] = []
    var createdAt: Date = Date.now

    /// Written only when a review card is actually paged past, never when the
    /// day's set is built. Building a set must not change future sets.
    var lastSurfacedAt: Date?
    var surfaceCount: Int = 0
    var isStarred: Bool = false

    /// Packed `Float32`, not `[Float]` — CloudKit takes `Data`.
    var embedding: Data?
    /// `nil` means the note still needs embedding.
    var embeddedAt: Date?
    /// Which vectorizer produced `embedding`, as a raw string for the same
    /// reason as `kindRaw`.
    ///
    /// Vectors from two different models are not comparable, so a note carrying
    /// one the app is no longer using is stale — the second way into the
    /// embedding queue, after `embeddedAt == nil`, and the one that empties a
    /// whole library into it the day Apple's contextual assets finish
    /// downloading. See `EmbeddingSource`.
    var embeddingSourceRaw: String = ""

    var book: Book?

    @Relationship(deleteRule: .cascade, inverse: \FollowUp.note)
    var followUps: [FollowUp]? = []

    init(
        shortID: Int = 0,
        kind: NoteKind = .thought,
        text: String = "",
        page: Int? = nil,
        tags: [String] = [],
        createdAt: Date = .now,
        isStarred: Bool = false,
        book: Book? = nil
    ) {
        self.shortID = shortID
        self.kindRaw = kind.rawValue
        self.text = text
        self.page = page
        self.tags = tags
        self.createdAt = createdAt
        self.isStarred = isStarred
        self.book = book
    }

    var kind: NoteKind {
        get { NoteKind(rawValue: kindRaw) ?? .thought }
        set { kindRaw = newValue.rawValue }
    }

    var embeddingSource: EmbeddingSource? {
        get { EmbeddingSource(rawValue: embeddingSourceRaw) }
        set { embeddingSourceRaw = newValue?.rawValue ?? "" }
    }

    /// The vector as `AffinityEngine` wants it, or `nil` when this note has
    /// none the app can still compare — never embedded, or embedded by a model
    /// it has since stopped using.
    func vector(from source: EmbeddingSource) -> [Float]? {
        guard embeddingSource == source, let embedding else { return nil }
        let values = NoteEmbedding.unpack(embedding)
        return values.isEmpty ? nil : values
    }

    /// `n.11`
    var idLabel: String { Glyphs.noteID(shortID) }
}
