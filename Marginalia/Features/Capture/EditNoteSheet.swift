import SwiftUI
import SwiftData

/// `edit` — the one place a note's own words can be changed after it was
/// written.
///
/// **Why this exists at all.** Until phase 15 nothing in the app could correct
/// a note. A typo was permanent; so was a transcription the recognizer got
/// wrong, and so was a line of OCR that read a printed page badly — and the
/// app is careful to land both of those in an editable field *before* the save
/// and then offered nothing after it. For an app whose whole premise is that a
/// note is worth meeting again in six weeks, a note you can't correct is the
/// wrong kind of permanent.
///
/// **The type selector, the recorder and the scanner are all missing on
/// purpose.** They are capture-time controls, and how a note was captured is a
/// fact about the note rather than about the keystrokes — the same rule that
/// already keeps an edited transcript a `voice`. A voice note edited here is
/// still a voice note, and it still says so.
///
/// **The book isn't here either.** `move to book…` is its own path through
/// `NoteWriter.refile` and sits on the same long press; folding it in would be
/// a second way to do one thing.
///
/// An edit is silent: the note keeps its id, its kind, its thread and its
/// `createdAt`, so it holds its place in the stream and nothing anywhere says
/// `edited`. `docs/decisions.md` §22 — the app doesn't spend a line saying what
/// the reader already knows they just did.
struct EditNoteSheet: View {
    let note: Note

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var draft = CaptureDraft()

    var body: some View {
        VStack(spacing: 0) {
            header

            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        BodyField(placeholder: placeholder, text: $draft.text)

                        HStack(spacing: 8) {
                            InputField(placeholder: "p.", text: $draft.page, keyboard: .numberPad)
                                .frame(width: 90)
                            InputField(placeholder: "#tag", text: $draft.tags)
                        }

                        MarkerButton(title: "save changes", enabled: draft.canSave) { save() }
                    }
                    .padding(20)
                    .frame(minHeight: proxy.size.height)
                }
            }
        }
        .background(Theme.canvas)
        // The fields open on what the note actually says. A sheet that opened
        // empty would read as a new note and would erase one on save.
        .task { draft = Self.draft(from: note) }
    }

    // MARK: Chrome

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                // The id, because this is the one sheet that acts on a note the
                // reader already has on screen and has to say which.
                Text("edit \(note.idLabel)")
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
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 8)

            Hairline()
        }
    }

    /// The same placeholder the capture sheet uses, keyed the same way — a scan
    /// and a quote are somebody else's words on both screens.
    private var placeholder: String {
        note.kind.isPassage ? "the passage, as written…" : "what you thought…"
    }

    // MARK: Writing

    /// What the note stores → what the fields show. The mirror of
    /// `CaptureDraft`'s own direction, and the reason the page comes back as
    /// text: `TypedPage` parses `"p. 214"` on the way in, so the way out is a
    /// bare number in a field labelled `p.`.
    private static func draft(from note: Note) -> CaptureDraft {
        CaptureDraft(
            kind: note.kind,
            text: note.text,
            page: note.page.map(String.init) ?? "",
            tags: note.tags.joined(separator: " ")
        )
    }

    private func save() {
        guard (try? NoteWriter.update(note, to: draft, in: context)) != nil else { return }
        Haptics.saved()
        dismiss()
    }
}
