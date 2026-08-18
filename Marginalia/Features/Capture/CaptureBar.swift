import SwiftUI

/// Pinned to the foot of the stream, present the whole time — that persistence
/// is the point. Text or voice, no book, no page, no tag; the note lands in the
/// Inbox to be filed later.
///
/// Three rows, one at a time: the input, the live waveform, and transcribing.
/// Each replaces the whole row rather than appearing beside it.
///
/// **The fast path is not allowed to get slower**, which is why the book,
/// the page and the tags aren't here. Phase 11 put a `BookPickerField` in this
/// bar and took it back out a day later: a picker squeezed between the field
/// and the keyboard was too small to use, and its closed state answered a
/// question — `book · Inbox` — that the reader had never been asked. The way
/// out is `→ full note`, which carries whatever is typed into `CaptureSheet`
/// and gives it the whole screen. Two taps for a thought, three for a note
/// with a book on it. See `docs/decisions.md` §18.
struct CaptureBar: View {
    @Binding var draft: String
    /// Mirrors the field's focus outward. `RootView` takes the tab bar off the
    /// screen while it's true — see the comment on `RootView.capturing`.
    @Binding var focusedOut: Bool
    /// Returns true when the note was written, so the field can clear.
    let onSave: (NoteKind) -> Bool
    /// `→ full note`: hand what's typed to the full sheet and get out of the
    /// way. The kind goes with it, so a transcript arrives there as `[v] voice`
    /// rather than as text somebody happened to type.
    let onEscalate: (NoteKind) -> Void
    /// Set by `-captureDraft`, so the focused field and the bar's position
    /// above the keyboard can be screenshot. Never true in a normal launch.
    var focusAtLaunch = false

    @State private var voice: VoiceCapture
    /// Whether what's in the field was spoken. How a note was captured is a
    /// fact about the note, so editing a transcript leaves it `[v] voice`.
    @State private var spoken = false

    @FocusState private var focused: Bool

    init(
        draft: Binding<String>,
        focusedOut: Binding<Bool>,
        voice: VoiceCapture? = nil,
        focusAtLaunch: Bool = false,
        onSave: @escaping (NoteKind) -> Bool,
        onEscalate: @escaping (NoteKind) -> Void
    ) {
        self._draft = draft
        self._focusedOut = focusedOut
        self.onSave = onSave
        self.onEscalate = onEscalate
        self.focusAtLaunch = focusAtLaunch
        self._voice = State(initialValue: voice ?? VoiceCapture())
    }

    var body: some View {
        VStack(spacing: 0) {
            Hairline()

            if let problem = voice.problem {
                CaptureProblem(message: problem)
            }

            switch voice.phase {
            case .idle: input
            case .recording: recording
            case .transcribing: transcribing
            }
        }
        .background(Theme.canvas)
        .task { if focusAtLaunch { focused = true } }
        .onChange(of: focused) { _, isFocused in focusedOut = isFocused }
        // The stream clears focus by tapping off the field; the bar has to
        // notice when it does.
        .onChange(of: focusedOut) { _, wanted in if !wanted { focused = false } }
    }

    // MARK: Idle

    private var input: some View {
        VStack(spacing: 8) {
            row

            // **Only while the field has focus.** Unfocused, the bar is exactly
            // what it has always been — one line and two buttons, two taps from
            // launch to a filed thought. A link rather than a third 48pt
            // button: the field and `[+]` are the first two things on this row
            // and a third box would say they were all equals.
            if focused {
                HStack {
                    MarkerButton(title: "\(Glyphs.forward) full note", kind: .link) {
                        onEscalate(spoken ? .voice : .thought)
                    }
                    Spacer(minLength: 0)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .animation(.snappy(duration: 0.15), value: focused)
    }

    private var row: some View {
        HStack(spacing: 8) {
            TextField("add a thought…", text: $draft, axis: .vertical)
                .font(Typography.input)
                .foregroundStyle(Theme.ink)
                .tint(Theme.ink)
                .lineLimit(1...4)
                .focused($focused)
                .onChange(of: draft) { _, text in
                    voice.clearProblem()
                    if text.isEmpty { spoken = false }   // cleared past the transcript
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(focused ? Theme.canvas : Theme.surfaceSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: interactiveRadius)
                        .stroke(focused ? Theme.ink : Theme.hairline, lineWidth: 1)
                )
                .clipShape(.rect(cornerRadius: interactiveRadius))

            Button {
                save()
            } label: {
                Text(Glyphs.add)
                    .font(Typography.button)
                    // **The marker stops growing; the note never does.** These
                    // two are 48pt boxes by the design system, and at the
                    // accessibility sizes `[+]` rendered as `…` inside its own
                    // button while `[●]` burst its brackets. A marker that has
                    // been truncated to an ellipsis has stopped being a marker.
                    // The field beside them is uncapped, which is the half that
                    // matters — see `chromeTypeSize()`.
                    .chromeTypeSize()
                    .foregroundStyle(Theme.onInk)
                    .frame(width: 48, height: 48)
                    .background(canSave ? Theme.ink : Theme.disabled)
                    .clipShape(.rect(cornerRadius: interactiveRadius))
            }
            .buttonStyle(.plain)
            .disabled(!canSave)

            Button {
                Task { await voice.record() }
            } label: {
                RecordGlyph()
                    .chromeTypeSize()
                    .frame(width: 48, height: 48)
                    .background(Theme.canvas)
                    .overlay(
                        RoundedRectangle(cornerRadius: interactiveRadius)
                            .stroke(Theme.hairline, lineWidth: 1)
                    )
                    .clipShape(.rect(cornerRadius: interactiveRadius))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Recording

    private var recording: some View {
        HStack(spacing: 12) {
            Waveform(levels: voice.levels)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                Text(Glyphs.dot).foregroundStyle(Theme.danger)
                Text(RelativeTime.elapsed(voice.elapsed)).foregroundStyle(Theme.textMute)
            }
            .font(Typography.meta)
            .monospacedDigit()

            Button {
                voice.cancel()
            } label: {
                Text("cancel")
                    .font(Typography.buttonSmall)
                    .foregroundStyle(Theme.textMute)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            Button {
                Task { await transcribe() }
            } label: {
                Text("\(Glyphs.stop) stop")
                    .font(Typography.buttonSmall)
                    .foregroundStyle(Theme.onInk)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.ink)
                    .clipShape(.rect(cornerRadius: interactiveRadius))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var transcribing: some View {
        Text("\(Glyphs.refresh) transcribing…")
            .font(Typography.input)
            .foregroundStyle(Theme.textMute)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 22)
    }

    // MARK: Saving

    private var canSave: Bool { CaptureDraft(text: draft).canSave }

    private func save() {
        guard onSave(spoken ? .voice : .thought) else { return }
        draft = ""
        spoken = false
    }

    /// The transcript lands in the field rather than in the store: on-device
    /// recognition is wrong often enough that saving it unseen would be a
    /// worse note than not capturing one.
    private func transcribe() async {
        let text = await voice.stop()
        guard !text.isEmpty else { return }
        draft = draft.isEmpty ? text : draft + " " + text
        spoken = true
        focused = true
    }
}

/// A permission that's off, or a recording that heard nothing. Sits above the
/// row it explains and clears the moment anything else happens.
struct CaptureProblem: View {
    let message: String
    /// The bar sets its own screen padding; the sheet has already applied it.
    var inset: CGFloat = 20

    var body: some View {
        Text("\(Glyphs.close) \(message)")
            .font(Typography.source)
            .foregroundStyle(Theme.textMute)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, inset)
            .padding(.top, 12)
    }
}
