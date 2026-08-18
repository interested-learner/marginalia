import SwiftUI
import SwiftData

/// `move to book…` — the later that "to be filed later" always promised.
///
/// The stream's capture bar files to the Inbox when nobody names a book, and
/// `docs/specs` has described that as a note "to be filed later" since phase 3.
/// Until now there was no later: nothing in the app could change a note's book
/// after it was written, so the Inbox was a drawer that only opened one way.
///
/// It is the same picker the capture surfaces use, over the same shelf, writing
/// through `NoteWriter.refile` — one control, one write path.
struct MoveNoteSheet: View {
    let note: Note
    let books: [Book]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var book: Book?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("move \(note.idLabel)")
                    .font(Typography.screenTitle)
                    .foregroundStyle(Theme.ink)

                Spacer(minLength: 8)

                Button { dismiss() } label: {
                    Text(Glyphs.close)
                        .font(Typography.meta)
                        .foregroundStyle(Theme.textMute)
                        .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Text("the note keeps its id, its page, its tags and anything written under it.")
                .font(Typography.source)
                .foregroundStyle(Theme.textMute)
                .fixedSize(horizontal: false, vertical: true)

            BookPickerField(book: $book, books: books, label: "move to")

            MarkerButton(title: "move note", enabled: book != note.book) { move() }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.canvas)
        .presentationDetents([.height(340)])
        // The book it's in now, Inbox included — the field opens on the truth,
        // and `move note` stays inert until the reader has actually changed the
        // answer. The Inbox is in the shelf like any other book, so moving a
        // note *back* into it is available too.
        .task { book = note.book }
    }

    private func move() {
        try? NoteWriter.refile(note, to: book, in: context)
        Haptics.saved()
        dismiss()
    }
}
