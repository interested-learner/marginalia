import SwiftUI
import SwiftData

/// Adding a book, and correcting one.
///
/// **The form is the screen; search and the barcode are two ways to fill it.**
/// That's what keeps manual entry always available rather than a fallback
/// buried behind a failure — typing the book in is the same three fields
/// whether Open Library answered or not.
struct BookFormSheet: View {
    private let existing: Book?

    @State private var draft: BookDraft
    @State private var query = ""
    @State private var results: [BookCandidate] = []
    @State private var lookup: Lookup = .idle
    @State private var scanning = false
    /// A book already on the shelf that this one would be a second copy of.
    /// Set by the first `add book`; the second one goes through anyway.
    @State private var duplicate: Book?

    @Query private var shelf: [Book]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private enum Lookup: Equatable {
        case idle, searching
        /// In the app's own words. A failed lookup is a sentence, not an alert.
        case failed(String)
    }

    init(editing book: Book? = nil) {
        self.existing = book
        self._draft = State(initialValue: book.map(BookDraft.init) ?? BookDraft())
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            // The form fills the sheet rather than floating at the top of it,
            // so `add book` sits where `save note` does. It scrolls instead
            // once a result list or Dynamic Type needs the room.
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        finder
                        if !results.isEmpty { resultList }

                        Hairline()

                        InputField(placeholder: "title", text: $draft.title, autocapitalize: .words)
                        InputField(placeholder: "author", text: $draft.author, autocapitalize: .words)

                        HStack(spacing: 8) {
                            InputField(placeholder: "pages", text: $draft.pages, keyboard: .numberPad)
                                .frame(width: 110)
                            InputField(placeholder: "on p.", text: $draft.current, keyboard: .numberPad)
                        }

                        SegmentedRow(options: offered, selection: $draft.status) {
                            "\($0.marker) \($0.label)"
                        }

                        Spacer(minLength: 12)

                        // A sentence, not an alert — the same treatment a failed
                        // lookup gets. The button below it changes its own label
                        // rather than the form growing a second one.
                        if let duplicate {
                            CaptureProblem(message: alreadyHave(duplicate), inset: 0)
                        }

                        MarkerButton(title: saveTitle, enabled: draft.canSave) { save() }
                    }
                    .padding(20)
                    .frame(minHeight: proxy.size.height)
                }
            }
        }
        .background(Theme.canvas)
        .fullScreenCover(isPresented: $scanning) {
            BarcodeScannerScreen(
                onFound: { isbn in
                    scanning = false
                    Task { await fill(isbn: isbn) }
                },
                onCancel: { scanning = false }
            )
        }
        // Changing the title is the reader answering the warning. Leaving it up
        // would leave `add it anyway` on a book that isn't a duplicate anymore.
        .onChange(of: draft) { duplicate = nil }
        .task { searchAtLaunch() }
    }

    /// Reading, queued, finished — the three a reader chooses between. `inbox`
    /// is not a reading state and is never offered.
    private var offered: [BookStatus] { [.reading, .queued, .finished] }

    private var saveTitle: String {
        if duplicate != nil { return "add it anyway" }
        return existing == nil ? "add book" : "save"
    }

    /// `you already have Meditations · Marcus Aurelius`, closing up around an
    /// author nobody filled in.
    private func alreadyHave(_ book: Book) -> String {
        let name = book.author.isEmpty ? book.title : "\(book.title) · \(book.author)"
        return "you already have \(name)"
    }

    // MARK: Chrome

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(existing == nil ? "add book" : "edit book")
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

    // MARK: Lookup

    private var finder: some View {
        VStack(spacing: 12) {
            InputField(
                placeholder: "find a title…",
                text: $query,
                autocapitalize: .words,
                onSubmit: { Task { await search() } }
            )

            HStack(spacing: 8) {
                MarkerButton(title: "search", kind: .secondary) {
                    Task { await search() }
                }
                MarkerButton(title: "\(Glyphs.scan) scan isbn", kind: .secondary) {
                    scanning = true
                }
            }

            switch lookup {
            case .searching:
                Text("\(Glyphs.refresh) searching…")
                    .font(Typography.source)
                    .foregroundStyle(Theme.textMute)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .failed(let message):
                CaptureProblem(message: message, inset: 0)
            case .idle:
                EmptyView()
            }
        }
    }

    /// Drawn with the app's own rows, expanding beneath the field — the same
    /// move the capture sheet's book picker makes. A wheel or a system list
    /// would be the one piece of iOS chrome in the app.
    private var resultList: some View {
        VStack(spacing: 0) {
            ForEach(results) { candidate in
                Button { choose(candidate) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(candidate.title)
                            .font(Typography.bookTitle)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Text(description(of: candidate))
                            .font(Typography.source)
                            .foregroundStyle(Theme.textMute)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Theme.canvas)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if candidate.id != results.last?.id { Hairline() }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: interactiveRadius)
                .stroke(Theme.hairline, lineWidth: 1)
        )
        .clipShape(.rect(cornerRadius: interactiveRadius))
    }

    /// `Daniel Kahneman · 499pp`, closing up around whatever Open Library
    /// didn't know — which is routinely one of the two.
    private func description(of candidate: BookCandidate) -> String {
        var segments: [String] = []
        if !candidate.author.isEmpty { segments.append(candidate.author) }
        if candidate.pageCount > 0 { segments.append("\(candidate.pageCount)pp") }
        return segments.isEmpty ? "no author listed" : segments.joined(separator: " · ")
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func search() async {
        guard !trimmedQuery.isEmpty else { return }
        lookup = .searching
        results = []
        do {
            let found = try await BookLookup.search(trimmedQuery)
            results = found
            lookup = found.isEmpty ? .failed(BookLookup.Failure.notFound.message) : .idle
        } catch let failure as BookLookup.Failure {
            lookup = .failed(failure.message)
        } catch {
            lookup = .failed(BookLookup.Failure.unreachable.message)
        }
    }

    private func fill(isbn: String) async {
        lookup = .searching
        results = []
        do {
            choose(try await BookLookup.edition(isbn: isbn))
        } catch let failure as BookLookup.Failure {
            // The isbn is still worth keeping even when the lookup missed —
            // it's the one fact the barcode is certain about.
            draft.isbn = ISBN.normalized(isbn) ?? draft.isbn
            lookup = .failed(failure.message)
        } catch {
            lookup = .failed(BookLookup.Failure.unreachable.message)
        }
    }

    /// A result **fills the form** rather than saving straight through. Open
    /// Library gets authors and page counts wrong often enough that the last
    /// word belongs to the reader.
    private func choose(_ candidate: BookCandidate) {
        draft.fill(from: candidate)
        results = []
        lookup = .idle
        query = ""
    }

    // MARK: Saving

    /// **A duplicate is reported once and then allowed.** Two copies of a book
    /// is a mistake often enough to be worth naming, and a deliberate second
    /// copy — a re-read, a different translation — is legitimate often enough
    /// that refusing it outright would be the app overruling the reader. So the
    /// first tap says what's already on the shelf and the second one adds it.
    private func save() {
        if duplicate == nil, let existing = onTheShelf {
            duplicate = existing
            return
        }

        do {
            if let existing {
                guard try BookWriter.apply(draft, to: existing, in: context) else { return }
            } else {
                guard try BookWriter.add(draft, in: context) != nil else { return }
            }
        } catch {
            return
        }
        dismiss()
    }

    private var onTheShelf: Book? {
        BookShelf.duplicate(title: draft.bookTitle, author: draft.bookAuthor,
                            in: shelf, excluding: existing)
    }

    /// `-bookSearch "meditations"` fills the field and runs the search, which
    /// is the only way to screenshot a result list — the simulator can't be
    /// typed into from the command line.
    private func searchAtLaunch() {
        guard existing == nil,
              let seeded = UserDefaults.standard.string(forKey: "bookSearch"),
              !seeded.isEmpty
        else { return }
        query = seeded
        Task { await search() }
    }
}
