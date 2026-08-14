import Foundation
import SwiftData

/// A later thought threaded under a note. This is what `[+] add a thought` on a
/// review card produces, and it replaces the prototype's keep/skip/later
/// entirely — see `docs/decisions.md` §4.
@Model
final class FollowUp {
    var text: String = ""
    var createdAt: Date = Date.now
    var note: Note?

    init(text: String = "", createdAt: Date = .now, note: Note? = nil) {
        self.text = text
        self.createdAt = createdAt
        self.note = note
    }
}
