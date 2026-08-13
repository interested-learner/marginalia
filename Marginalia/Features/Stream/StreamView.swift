import SwiftUI

/// Every note across every book, newest first. The capture bar is pinned at the
/// foot and present the whole time — that persistence is the point.
///
/// Phase 1: static content, and the capture bar doesn't save yet.
struct StreamView: View {
    @State private var tag = "all"
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(style: .wordmark(subtitle: "stream"))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SampleData.tags, id: \.self) { t in
                        TagChip(label: t, selected: t == tag) { tag = t }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            Hairline()

            ScrollView {
                LazyVStack(spacing: 0) {
                    GroupHeader(label: "today · wed aug 13")
                    ForEach(SampleData.streamToday) { NoteRow(note: $0) }
                    GroupHeader(label: "yesterday")
                    ForEach(SampleData.streamYesterday) { NoteRow(note: $0) }
                }
            }

            CaptureBar(draft: $draft)
        }
        .background(Theme.canvas)
    }
}

/// Text or voice, always within reach. Focus moves the input from `surfaceSoft`
/// to `canvas` and its border to `ink`.
struct CaptureBar: View {
    @Binding var draft: String
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Hairline()
            HStack(spacing: 8) {
                TextField("add a thought…", text: $draft, axis: .vertical)
                    .font(Typography.input)
                    .foregroundStyle(Theme.ink)
                    .tint(Theme.ink)
                    .lineLimit(1...4)
                    .focused($focused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(focused ? Theme.canvas : Theme.surfaceSoft)
                    .overlay(
                        RoundedRectangle(cornerRadius: interactiveRadius)
                            .stroke(focused ? Theme.ink : Theme.hairline, lineWidth: 1)
                    )
                    .clipShape(.rect(cornerRadius: interactiveRadius))

                Button {} label: {
                    Text(Glyphs.add)
                        .font(Typography.button)
                        .foregroundStyle(Theme.onInk)
                        .frame(width: 48, height: 48)
                        .background(draft.isEmpty ? Theme.disabled : Theme.ink)
                        .clipShape(.rect(cornerRadius: interactiveRadius))
                }
                .buttonStyle(.plain)
                .disabled(draft.isEmpty)

                Button {} label: {
                    RecordGlyph()
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
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Theme.canvas)
    }
}
