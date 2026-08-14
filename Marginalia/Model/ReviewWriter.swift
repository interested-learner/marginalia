import Foundation
import SwiftData

/// What a review card writes: a follow-up, a star, and the fact that a note was
/// seen. The one path each of those takes, for the same reason `NoteWriter` and
/// `BookWriter` exist — a second one would drift.
enum ReviewWriter {

    /// `[+] add a thought` — a later thought threaded under the note it answers.
    ///
    /// This is what replaces keep/skip/later: instead of judging a note you grow
    /// it, and the good ones accumulate a conversation with yourself. Empty
    /// writes nothing, and the text is trimmed the way a capture's is.
    @discardableResult
    static func followUp(
        _ text: String,
        on note: Note,
        in context: ModelContext,
        now: Date = .now
    ) throws -> FollowUp? {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return nil }

        let followUp = FollowUp(text: body, createdAt: now, note: note)
        context.insert(followUp)
        try context.save()
        return followUp
    }

    /// `[ ] star` / `[*] starred`. Returns the state it left the note in — the
    /// honest version of "keep", and starred notes score higher in future sets.
    @discardableResult
    static func star(_ note: Note, in context: ModelContext) throws -> Bool {
        note.isStarred.toggle()
        try context.save()
        return note.isStarred
    }

    /// Records that a card was actually paged past.
    ///
    /// **Never called when the set is built** — `ReviewSetBuilder` reads these
    /// two fields, so writing them at build time would mean opening review
    /// changed tomorrow's set without anyone reading a word.
    ///
    /// Once per day per note: swiping back and forth through the day's set is
    /// one reading of each card, not six, and an inflated `surfaceCount` would
    /// quietly bury a note for months.
    static func surface(
        _ note: Note,
        in context: ModelContext,
        at now: Date = .now,
        calendar: Calendar = .current
    ) throws {
        if let last = note.lastSurfacedAt, calendar.isDate(last, inSameDayAs: now) { return }

        note.lastSurfacedAt = now
        note.surfaceCount += 1
        try context.save()
    }
}
