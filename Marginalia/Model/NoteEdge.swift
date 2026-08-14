import Foundation
import SwiftData

/// A connection between two notes.
///
/// Its own model rather than a bare `[Note]` relationship, because it carries a
/// score and the two override flags.
///
/// Direction is stored but **never displayed** — the UI shows an edge from both
/// ends, or half of every note's connections are invisible.
@Model
final class NoteEdge {
    var from: Note?
    var to: Note?
    /// `0` for a manually created link.
    var score: Double = 0
    /// User-created. Never pruned by a recompute.
    var isPinned: Bool = false
    /// User-deleted. Never re-suggested.
    var isSuppressed: Bool = false
    var createdAt: Date = Date.now

    init(
        from: Note? = nil,
        to: Note? = nil,
        score: Double = 0,
        isPinned: Bool = false,
        isSuppressed: Bool = false,
        createdAt: Date = .now
    ) {
        self.from = from
        self.to = to
        self.score = score
        self.isPinned = isPinned
        self.isSuppressed = isSuppressed
        self.createdAt = createdAt
    }
}
