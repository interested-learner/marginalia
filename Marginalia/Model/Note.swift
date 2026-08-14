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

    /// `n.11`
    var idLabel: String { Glyphs.noteID(shortID) }
}
