import SwiftUI
import SwiftData

/// The full capture: type, book, body, page, tags.
///
/// The stream bar is the fast path and takes none of this — a thought filed in
/// two taps. This is the other one, reached from a book, where the note already
/// has a home and a page number worth keeping — and reached from the bar's
/// `→ full note`, which arrives with `text` already typed and nothing else
/// answered. Escalating is never destructive: the bar keeps its draft until
/// this sheet actually writes a note, so cancelling puts the reader back where
/// they were with what they wrote still there.
struct CaptureSheet: View {
    /// Pre-filled from wherever the sheet was opened. Still changeable here,
    /// because the wrong book is the most common thing to notice mid-note.
    @State private var book: Book?
    @State private var draft: CaptureDraft
    @State private var voice = VoiceCapture(width: 22)
    @State private var scanning = false

    @Query private var books: [Book]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// Told when a note was written, so the surface that opened this one can
    /// clear itself. A cancelled sheet never calls it.
    private let onSaved: () -> Void

    init(book: Book? = nil, kind: NoteKind = .thought, text: String = "",
         onSaved: @escaping () -> Void = {}) {
        self._book = State(initialValue: book)
        self._draft = State(initialValue: CaptureDraft(kind: kind, text: text))
        self.onSaved = onSaved
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

                        BookPickerField(book: $book, books: shelf)

                        if let problem = voice.problem {
                            CaptureProblem(message: problem, inset: 0)
                        }

                        if draft.kind == .voice {
                            // The recording box is a fixed 150 and sits at the
                            // top of the space; the transcript field fills it.
                            VoicePanel(voice: voice, text: $draft.text)
                                .frame(maxHeight: .infinity, alignment: .top)
                        } else if draft.kind == .scan {
                            ScanPanel(text: $draft.text) { scanning = true }
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
        // Full screen, like the barcode: a camera in a corner of a sheet is
        // aimed by guesswork, and the passage has to be readable through it.
        .fullScreenCover(isPresented: $scanning) {
            TextScannerScreen(
                onDone: { passage in
                    scanning = false
                    // Appended, not assigned — a passage that runs over a page
                    // turn is two scans, and the second continues the first.
                    draft.text = ScannedPassage.appending(passage, to: draft.text)
                },
                onCancel: { scanning = false }
            )
        }
        .onDisappear { voice.cancel() }
        .task { openScannerAtLaunch() }
    }

    /// `-scanner 1` opens the scanner over the sheet — the simulator has no
    /// camera and can't be tapped either, so this is the only way to see it.
    private func openScannerAtLaunch() {
        let defaults = UserDefaults.standard
        guard draft.kind == .scan else { return }
        if defaults.bool(forKey: "scanner") { scanning = true }
        // `-scanned "<text>"` without `-scanner` lands the passage straight in
        // the field, which is the state after a scan rather than during one.
        else if let text = defaults.string(forKey: "scanned"), !text.isEmpty {
            draft.text = ScannedPassage.appending(text, to: draft.text)
        }
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

    private var shelf: [Book] { BookShelf.ordered(books) }

    /// There are no field labels in this system — the placeholder carries it.
    fileprivate static func placeholder(for kind: NoteKind) -> String {
        kind.isPassage ? "the passage, as written…" : "what you thought…"
    }

    private func save() {
        guard (try? NoteWriter.save(draft, to: book, in: context)) != nil else { return }
        Haptics.saved()
        onSaved()
        dismiss()
    }
}

// MARK: Fields

/// `[q] quote` · `[t] thought` over `[v] voice` · `[s] scan`.
///
/// **Two rows of two, not four across.** A fourth segment at 13pt mono clips
/// its own label at the default text size — the same arithmetic that gave the
/// review card two rows of actions rather than one row of four.
private struct TypeSelector: View {
    @Binding var kind: NoteKind

    private let offered: [NoteKind] = [.quote, .thought, .voice, .scan]

    var body: some View {
        SegmentedRow(options: offered, selection: $kind, perRow: 2) {
            "\($0.marker) \($0.label)"
        }
    }
}

// MARK: Scan

/// Point the camera at the page, tap the passage, correct what OCR fumbled.
///
/// The same shape the voice panel has, and for the same reason: capture happens
/// somewhere else — a camera, a microphone — and what comes back lands in an
/// editable field before it's a note. **A scan is never saved unseen**, which
/// is the rule a transcript already follows.
///
/// The page number is typed into the field below, never read off the page.
private struct ScanPanel: View {
    @Binding var text: String
    let onScan: () -> Void

    var body: some View {
        if text.isEmpty {
            CaptureBox {
                Button(action: onScan) {
                    HStack(spacing: 8) {
                        Text(Glyphs.scan).foregroundStyle(Theme.ink)
                        Text("scan a page").foregroundStyle(Theme.ink)
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
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(Glyphs.scan) scanned · edit before saving")
                        .font(Typography.meta)
                        .foregroundStyle(Theme.textAsh)

                    Spacer(minLength: 8)

                    // A passage that runs over a page turn is two scans. A link,
                    // because it's the second-best thing on this panel and the
                    // field below it is the first.
                    MarkerButton(title: "scan more", kind: .link, action: onScan)
                }

                BodyField(placeholder: CaptureSheet.placeholder(for: .scan),
                          text: $text, minHeight: 120)
            }
        }
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
            CaptureBox {
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
            CaptureBox(bordered: true) {
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
            CaptureBox {
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

}

/// The 150pt box every capture that happens somewhere else waits inside — the
/// three recording states and the one before a scan.
///
/// Fixed, so the sheet doesn't resize under the reader's thumb as it moves
/// between them and `save note` stays where it was.
private struct CaptureBox<Content: View>: View {
    var bordered = false
    @ViewBuilder let content: Content

    var body: some View {
        content
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
