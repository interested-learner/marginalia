import SwiftUI
import SwiftData

/// `[+] add a thought`, in the room a thought needs.
///
/// This is what replaced keep/skip/later — instead of judging a note you grow
/// it. The note being answered sits at the top of the sheet, because a thought
/// written without the passage in front of you answers the wrong thing.
struct FollowUpSheet: View {
    let note: Note

    @State private var text = ""

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header

            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        answering

                        BodyField(placeholder: "what you think now…", text: $text)

                        MarkerButton(title: "save thought", enabled: canSave) { save() }
                    }
                    .padding(20)
                    .frame(minHeight: proxy.size.height, alignment: .top)
                }
            }
        }
        .background(Theme.canvas)
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("add a thought")
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

    /// The note being answered, in the margin the stream uses — here it *is* one
    /// of many rather than the whole screen, so the id belongs beside it.
    private var answering: some View {
        VStack(alignment: .leading, spacing: 0) {
            MarginColumn(label: note.idLabel, inset: 0) {
                Text(note.text)
                    .font(Typography.noteBody)
                    .lineSpacing(Typography.bodyLeading)
                    .foregroundStyle(note.kind == .quote ? Theme.ink : Theme.textBody)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        guard (try? ReviewWriter.followUp(text, on: note, in: context)) != nil else { return }
        dismiss()
    }
}
