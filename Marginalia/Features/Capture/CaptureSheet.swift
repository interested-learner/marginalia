import SwiftUI
import SwiftData

/// The full capture: type, book, body, page, tags.
///
/// The stream bar is the fast path and takes none of this — a thought filed in
/// two taps. This is the other one, reached from a book, where the note already
/// has a home and a page number worth keeping.
struct CaptureSheet: View {
    /// Pre-filled from wherever the sheet was opened. Still changeable here,
    /// because the wrong book is the most common thing to notice mid-note.
    @State private var book: Book?
    @State private var draft: CaptureDraft
    @State private var pickingBook = false
    @State private var voice = VoiceCapture(width: 22)

    @Query private var books: [Book]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    init(book: Book? = nil, kind: NoteKind = .thought) {
        self._book = State(initialValue: book)
        self._draft = State(initialValue: CaptureDraft(kind: kind))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            // The body field takes whatever height is left, so the sheet is
            // full rather than half empty and the reader gets the room. It
            // scrolls instead once the type is large enough to need it.
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        TypeSelector(kind: $draft.kind)

                        bookField

                        if let problem = voice.problem {
                            CaptureProblem(message: problem, inset: 0)
                        }

                        if draft.kind == .voice {
                            // The recording box is a fixed 150 and sits at the
                            // top of the space; the transcript field fills it.
                            VoicePanel(voice: voice, text: $draft.text)
                                .frame(maxHeight: .infinity, alignment: .top)
                        } else {
                            BodyField(placeholder: Self.placeholder(for: draft.kind),
                                      text: $draft.text)
                        }

                        HStack(spacing: 8) {
                            InputField(placeholder: "p.", text: $draft.page, keyboard: .numberPad)
                                .frame(width: 90)
                            InputField(placeholder: "#tag", text: $draft.tags)
                        }

                        MarkerButton(title: "save note", enabled: draft.canSave) { save() }
                    }
                    .padding(20)
                    .frame(minHeight: proxy.size.height)
                }
            }
        }
        .background(Theme.canvas)
        .onDisappear { voice.cancel() }
    }

    // MARK: Chrome

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("new note")
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

    /// Tapping opens the library inline rather than in a system picker — a
    /// wheel or a menu would be the one piece of iOS chrome in the app.
    private var bookField: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.snappy(duration: 0.15)) { pickingBook.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Text("book · \(book?.title ?? Inbox.title)")
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(Glyphs.disclosure)
                        .foregroundStyle(Theme.textMute)
                }
                .font(Typography.input)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.canvas)
                .overlay(
                    RoundedRectangle(cornerRadius: interactiveRadius)
                        .stroke(pickingBook ? Theme.ink : Theme.hairline, lineWidth: 1)
                )
                .clipShape(.rect(cornerRadius: interactiveRadius))
            }
            .buttonStyle(.plain)

            if pickingBook {
                VStack(spacing: 0) {
                    ForEach(shelf) { choice in
                        Button {
                            book = choice
                            withAnimation(.snappy(duration: 0.15)) { pickingBook = false }
                        } label: {
                            HStack(spacing: 10) {
                                Text(choice.status.marker)
                                    .foregroundStyle(Theme.textMute)
                                Text(choice.title)
                                    .foregroundStyle(choice == book ? Theme.ink : Theme.textBody)
                                    .lineLimit(1)
                                Spacer(minLength: 8)
                            }
                            .font(Typography.source)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(choice == book ? Theme.surfaceSoft : Theme.canvas)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Hairline()
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: interactiveRadius)
                        .stroke(Theme.hairline, lineWidth: 1)
                )
                .clipShape(.rect(cornerRadius: interactiveRadius))
                .padding(.top, 8)
            }
        }
    }

    private var shelf: [Book] { BookShelf.ordered(books) }

    /// There are no field labels in this system — the placeholder carries it.
    fileprivate static func placeholder(for kind: NoteKind) -> String {
        kind == .quote ? "the passage, as written…" : "what you thought…"
    }

    private func save() {
        guard (try? NoteWriter.save(draft, to: book, in: context)) != nil else { return }
        dismiss()
    }
}

// MARK: Fields

/// `[q] quote` · `[t] thought` · `[v] voice`.
///
/// `[s] scan` is the fourth capture type and belongs here, but it opens the
/// camera — it arrives with the scanner in phase 9 rather than as a segment
/// that does nothing.
private struct TypeSelector: View {
    @Binding var kind: NoteKind

    private let offered: [NoteKind] = [.quote, .thought, .voice]

    var body: some View {
        SegmentedRow(options: offered, selection: $kind) { "\($0.marker) \($0.label)" }
    }
}

// MARK: Voice

/// The same flow as the capture bar, in the room the sheet has for it: record,
/// waveform and timer, transcribing, then the text in an editable field.
private struct VoicePanel: View {
    let voice: VoiceCapture
    @Binding var text: String

    var body: some View {
        switch voice.phase {
        case .idle where text.isEmpty:
            panel {
                Button { Task { await voice.record() } } label: {
                    HStack(spacing: 8) {
                        Text(Glyphs.dot).foregroundStyle(Theme.danger)
                        Text("record").foregroundStyle(Theme.ink)
                    }
                    .font(Typography.button)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Theme.canvas)
                    .overlay(
                        RoundedRectangle(cornerRadius: interactiveRadius)
                            .stroke(Theme.hairline, lineWidth: 1)
                    )
                    .clipShape(.rect(cornerRadius: interactiveRadius))
                }
                .buttonStyle(.plain)
            }

        case .recording:
            panel(bordered: true) {
                VStack(spacing: 12) {
                    Waveform(levels: voice.levels)
                    HStack(spacing: 4) {
                        Text(Glyphs.dot).foregroundStyle(Theme.danger)
                        Text("recording · \(RelativeTime.elapsed(voice.elapsed))")
                            .foregroundStyle(Theme.textMute)
                            .monospacedDigit()
                    }
                    .font(Typography.meta)

                    Button { Task { text = await transcript() } } label: {
                        Text("\(Glyphs.stop) stop")
                            .font(Typography.buttonSmall)
                            .foregroundStyle(Theme.onInk)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(Theme.ink)
                            .clipShape(.rect(cornerRadius: interactiveRadius))
                    }
                    .buttonStyle(.plain)
                }
            }

        case .transcribing:
            panel {
                Text("\(Glyphs.refresh) transcribing…")
                    .font(Typography.input)
                    .foregroundStyle(Theme.textMute)
            }

        case .idle:
            VStack(alignment: .leading, spacing: 8) {
                Text("\(Glyphs.voice) transcribed · edit before saving")
                    .font(Typography.meta)
                    .foregroundStyle(Theme.textAsh)
                BodyField(placeholder: CaptureSheet.placeholder(for: .voice),
                          text: $text, minHeight: 120)
            }
        }
    }

    private func transcript() async -> String {
        let spoken = await voice.stop()
        return text.isEmpty ? spoken : text + " " + spoken
    }

    /// The 150pt box the three recording states share, so the sheet doesn't
    /// resize under the reader's thumb as it moves between them.
    private func panel<Content: View>(
        bordered: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .background(Theme.surfaceSoft)
            .overlay(
                RoundedRectangle(cornerRadius: interactiveRadius)
                    .stroke(bordered ? Theme.ink : Theme.hairline, lineWidth: 1)
            )
            .clipShape(.rect(cornerRadius: interactiveRadius))
    }
}
