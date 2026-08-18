import SwiftUI

/// `book · Meditations ▼`, and the library underneath it when it opens.
///
/// **The Inbox is the absence of a book here, not one of the choices.** It is a
/// real `Book` in the library — that is what keeps unfiled captures visible on
/// the books screen — but a note reaches it two indistinguishable ways: `nil`,
/// and the Inbox row itself. Offering both made `book · Inbox` read as a book
/// the reader had chosen when they had chosen nothing at all. So the row says
/// `— no book —`, the closed field says `book · none`, and the Inbox is filtered
/// out of the list. Where the note lands is unchanged.
///
/// Lifted out of `CaptureSheet`, where it lived privately for six phases,
/// because two places now need the same control and a second copy would drift
/// the way a second write path would: the full sheet, and `move to book…` on a
/// note that was filed to the Inbox and shouldn't have to stay there.
///
/// It briefly lived in the stream's capture bar too, and came back out — see
/// `docs/decisions.md` §18. The bar is the fast path; naming a book is what
/// `→ full note` is for.
///
/// **The library opens inline, not in a system picker.** A wheel or a menu would
/// be the one piece of iOS chrome in the app.
///
/// This is a `Features/` component rather than a `Design/` one on purpose: it
/// takes `Book` models, and `Design/` doesn't know SwiftData exists.
struct BookPickerField: View {
    @Binding var book: Book?
    /// Already in shelf order — the caller owns the `@Query`.
    let books: [Book]

    /// What the closed field says before the title. `book` in the capture
    /// surfaces, `move to` when the note already exists.
    var label = "book"

    @State private var open = false

    /// `-bookPicker 1` opens the list at launch. The simulator can't be tapped,
    /// and the list is the half of this control a closed field never shows.
    private static var openAtLaunch: Bool {
        UserDefaults.standard.bool(forKey: "bookPicker")
    }

    /// What the closed field says when no book is named, and — bracketed by
    /// em dashes so it can't be mistaken for a title — what the first row says.
    private static let unfiled = "none"
    private static let unfiledLabel = "— no book —"

    /// The Inbox is represented by `nil`, so it never appears twice.
    private var choices: [Book] { books.filter { $0.status != .inbox } }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.snappy(duration: 0.15)) { open.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Text("\(label) · \(book?.title ?? Self.unfiled)")
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
                        .stroke(open ? Theme.ink : Theme.hairline, lineWidth: 1)
                )
                .clipShape(.rect(cornerRadius: interactiveRadius))
            }
            .buttonStyle(.plain)

            if open {
                // Tall libraries scroll rather than pushing the field they
                // belong to off the screen. 240 is five rows and a hint of a
                // sixth, so there is always something cut off to swipe at.
                ScrollView {
                    VStack(spacing: 0) {
                        unfiledRow
                        Hairline()
                        ForEach(choices) { choice in
                            row(choice)
                            Hairline()
                        }
                    }
                }
                .frame(maxHeight: 240)
                .scrollBounceBehavior(.basedOnSize)
                .overlay(
                    RoundedRectangle(cornerRadius: interactiveRadius)
                        .stroke(Theme.hairline, lineWidth: 1)
                )
                .clipShape(.rect(cornerRadius: interactiveRadius))
                .padding(.top, 8)
            }
        }
        .task { if Self.openAtLaunch { open = true } }
    }

    /// Always first, and always present — a note can be un-filed as well as
    /// filed, which is how `move to book…` puts one back in the drawer.
    private var unfiledRow: some View {
        Button {
            book = nil
            withAnimation(.snappy(duration: 0.15)) { open = false }
        } label: {
            HStack(spacing: 10) {
                Text(Self.unfiledLabel)
                    .foregroundStyle(book == nil ? Theme.ink : Theme.textMute)
                    .lineLimit(1)
                Spacer(minLength: 8)
            }
            .font(Typography.source)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(book == nil ? Theme.surfaceSoft : Theme.canvas)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func row(_ choice: Book) -> some View {
        Button {
            book = choice
            withAnimation(.snappy(duration: 0.15)) { open = false }
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
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(choice == book ? Theme.surfaceSoft : Theme.canvas)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
