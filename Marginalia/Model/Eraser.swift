import SwiftUI
import SwiftData

/// The one path anything takes to stop existing.
///
/// The mirror of `NoteWriter` and `BookWriter`, and here for the same reason:
/// deleting a note is not `context.delete(note)`. A note owns edges that are
/// **not** cascaded — `NoteEdge.from` and `.to` are plain optionals with no
/// inverse, so SwiftData nils them rather than removing the edge, and an edge
/// with one end missing is a connection that can never be drawn and never be
/// cleaned up. Written out at each call site that would drift immediately.
///
/// Follow-ups are cascaded by the model (`Note.followUps`) and so are a book's
/// notes (`Book.notes`), so those are left to SwiftData — but the edges of every
/// note a book takes with it still have to be swept by hand.
enum Eraser {

    /// Removes a note, its thread, and every edge that touched it.
    ///
    /// The id is **not** returned to the counter. A gap in the sequence reads as
    /// a deleted note, which is exactly what it is; a reused id would make an
    /// old `→ n.07` point at a different note than the one it was written about.
    static func delete(_ note: Note, in context: ModelContext) throws {
        try prune(edgesTouching: [note], in: context)
        context.delete(note)
        try context.save()
    }

    /// Removes a book **and everything written from it** — the notes cascade,
    /// and their threads cascade behind them. This is the destructive one, and
    /// the only reason `Theme.danger` exists outside the recording dot.
    ///
    /// Returns `false` for the Inbox, which is refused for the same reason
    /// `BookWriter.apply` refuses to restatus it: it's found by status and it's
    /// where every unfiled capture lands. Deleting it would take every quick
    /// capture with it and the next one would silently build a second drawer.
    @discardableResult
    static func delete(_ book: Book, in context: ModelContext) throws -> Bool {
        guard book.status != .inbox else { return false }

        try prune(edgesTouching: book.notes ?? [], in: context)
        context.delete(book)
        try context.save()
        return true
    }

    /// Removes one later thought, leaving the note it hung under alone.
    static func delete(_ followUp: FollowUp, in context: ModelContext) throws {
        context.delete(followUp)
        try context.save()
    }

    /// Edges are not cascaded by the schema, so they're swept here.
    ///
    /// Dangling edges — both ends already gone — are swept at the same time.
    /// They can only have arrived from a delete that happened before this file
    /// existed, and nothing else will ever remove them.
    private static func prune(edgesTouching notes: [Note], in context: ModelContext) throws {
        guard !notes.isEmpty else { return }
        let doomed = Set(notes.map(ObjectIdentifier.init))

        for edge in try context.fetch(FetchDescriptor<NoteEdge>()) {
            let ends = [edge.from, edge.to]
            let touched = ends.contains { end in
                guard let end else { return false }
                return doomed.contains(ObjectIdentifier(end))
            }
            if touched || ends.allSatisfy({ $0 == nil }) { context.delete(edge) }
        }
    }
}

/// Something a confirmation is about to erase, and what the app says about it.
///
/// One value rather than three `@State` optionals per screen: two `.sheet(item:)`
/// modifiers on the same view is a SwiftUI coin flip, and the wording written
/// out at each call site would drift the way two write paths would.
///
/// This is the second file that knows about both the models and the design
/// system — `RowMapping` is the other, and for the same reason. The views below
/// still never build a sentence about a `Book`.
enum Erasure: Identifiable {
    case note(Note)
    case followUp(FollowUp)
    case book(Book)

    var id: PersistentIdentifier {
        switch self {
        case .note(let note): note.persistentModelID
        case .followUp(let followUp): followUp.persistentModelID
        case .book(let book): book.persistentModelID
        }
    }

    var title: String {
        switch self {
        case .note(let note): "delete \(note.idLabel)?"
        case .followUp: "delete this thought?"
        case .book(let book): "delete \(book.title)?"
        }
    }

    /// What goes with it. The whole reason for asking is that the answer isn't
    /// obvious — a book takes everything written from it, and an id never comes
    /// back.
    var consequence: String {
        switch self {
        case .note(let note):
            "the note and any thread under it go with it. "
                + "\(note.idLabel) is retired rather than reused, so an old \(Glyphs.forward) \(note.idLabel) "
                + "will never point at a different note."
        case .followUp:
            "just this thought. the note it hangs under stays where it is."
        case .book(let book):
            book.noteCount == 0
                ? "no notes were written from it, so it goes on its own."
                : "\(book.noteCount) \(book.noteCount == 1 ? "note" : "notes") written from it "
                    + "go with it, and their threads go with them. this can't be undone."
        }
    }

    var confirmTitle: String { "\(Glyphs.close) delete" }

    /// A thread row identifies itself by its **position in the thread**, so this
    /// indexes into `Note.thread` — the same order `NoteRowData` built the rows
    /// from. `nil` if the thread changed underneath the long press.
    static func thought(_ position: Int, of note: Note) -> Erasure? {
        let thread = note.thread
        guard thread.indices.contains(position) else { return nil }
        return .followUp(thread[position])
    }

    func perform(in context: ModelContext) throws {
        switch self {
        case .note(let note): try Eraser.delete(note, in: context)
        case .followUp(let followUp): try Eraser.delete(followUp, in: context)
        case .book(let book): try Eraser.delete(book, in: context)
        }
    }
}

extension View {

    /// The confirmation every delete in the app goes through. Bound to whatever
    /// the screen last long-pressed, and dismissed by `ConfirmSheet` itself.
    ///
    /// `after` is where a screen that just deleted the thing it was showing goes
    /// — book detail pops back to the library rather than sitting on a book that
    /// no longer exists.
    func confirming(
        _ erasure: Binding<Erasure?>,
        in context: ModelContext,
        after: @escaping () -> Void = {}
    ) -> some View {
        sheet(item: erasure) { pending in
            ConfirmSheet(
                title: pending.title,
                consequence: pending.consequence,
                confirmTitle: pending.confirmTitle
            ) {
                try? pending.perform(in: context)
                after()
            }
            .confirmSheetChrome()
        }
    }
}
