import SwiftUI
import SwiftData

/// The map, and **it is a summary before it is a drawing.**
///
/// `docs/decisions.md` §20 has the reasoning. A node labelled `n.07` is an
/// opaque handle, so a canvas of forty-six of them was a picture nobody could
/// read: no region was named, every fact had to be decoded one tap at a time,
/// and the collapsed hub view was a picture of the bookshelf that the books tab
/// already gives with full titles. §11 wrote the escape clause itself — *"if the
/// map doesn't earn its place in use, it moves back inside Books"* — and this is
/// that call, answered by rebuilding rather than by demoting.
///
/// Three sections, down one scroll:
///
/// - **themes** — what the reader keeps coming back to, ranked, each named and
///   each quoting the note at its centre
/// - **crossings** — the connections that span two books, which is the most
///   concrete form of what this app is for
/// - **loose** — the notes in no theme, shown rather than hidden
///
/// The canvas survives at the two sizes where a graph is legible, and `GraphView`
/// is where it lives now.
struct MapView: View {
    /// A note handed over from another tab — `[◇] connections` on a stream row
    /// or a review card. Cleared once it's been shown, so coming back to the map
    /// later opens on the overview.
    @Binding var note: Int?

    let onOpenNote: (Int) -> Void
    let onOpenBook: (Book) -> Void

    @Query private var notes: [Note]
    @Query private var books: [Book]
    @Query private var edges: [NoteEdge]

    @Environment(\.modelContext) private var context

    @State private var path = NavigationPath()
    /// The themes, held rather than recomputed.
    ///
    /// **Nothing expensive in a `body`.** Grouping is an O(n²) pass and naming
    /// is O(themes × library); either one inside a redraw is the defect
    /// `ConnectionIndex.build` had on three screens and `ImageRenderer` had on
    /// the review card. See `reading` and `.task(id:)` below.
    @State private var reading = Reading()
    @State private var erasing: Erasure?
    /// `-mapTheme` and `-mapThemeGraph` can only fire once the themes exist, and
    /// they must fire exactly once — see `openThemeAtLaunch`.
    @State private var launched = false

    var body: some View {
        NavigationStack(path: $path) {
            overview
                .background(Theme.canvas)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                        .toolbar(.hidden, for: .navigationBar)
                }
        }
        .confirming($erasing, in: context, after: relink)
        .task(id: signature) { await read() }
        .onAppear(perform: openAtLaunch)
    }

    // MARK: The overview

    private var overview: some View {
        VStack(spacing: 0) {
            ScreenHeader(style: .title("map"), trailing: Glyphs.count(notes.count)) {
                Text(orientation)
                    .font(Typography.source)
                    .foregroundStyle(Theme.textMute)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollViewReader { scroll in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if themeRows.isEmpty && looseRows.isEmpty {
                            EmptyState(message: emptyMessage)
                        }

                        ForEach(themeRows) { theme in
                            Button { path.append(Route.theme(theme.id)) } label: {
                                ThemeRow(theme: theme)
                            }
                            .buttonStyle(PressedRow())
                            Hairline()
                        }

                        crossings

                        loose
                    }
                }
                // `-mapCrossings 1`. The overview is one long scroll and the
                // simulator can't be swiped, so the lower two sections are
                // otherwise unscreenshottable — which on this project means
                // unverifiable. `docs/issues.md` §12.
                .task(id: reading) { scrollToLaunchSection(scroll) }
            }
        }
    }

    private func scrollToLaunchSection(_ scroll: ScrollViewProxy) {
        guard UserDefaults.standard.bool(forKey: "mapCrossings") else { return }
        scroll.scrollTo(Self.crossingsAnchor, anchor: .top)
    }

    private static let crossingsAnchor = "crossings"
    private static let looseAnchor = "loose"

    /// One line, and the whole of the "library at a glance" idea.
    ///
    /// A quotes-versus-thoughts bar and a most-thought-with ranking were both
    /// considered and cut: they answer *what are my books like*, which is a
    /// different question, and a counter is not a takeaway. §20.
    private var orientation: String {
        let notes = "\(self.notes.count) \(self.notes.count == 1 ? "note" : "notes")"
        let shelf = BookShelf.ordered(books)
        let books = "\(shelf.count) \(shelf.count == 1 ? "book" : "books")"
        let count = reading.themes.count
        let themes = "\(count) \(count == 1 ? "theme" : "themes")"
        return "\(notes) · \(books) · \(themes)"
    }

    private var emptyMessage: String {
        notes.isEmpty
            ? "no notes yet — capture the first one"
            : "no themes yet — a few more notes and they start to show"
    }

    @ViewBuilder
    private var crossings: some View {
        if !crossingRows.isEmpty {
            GroupHeader(label: "crossings")
                .id(Self.crossingsAnchor)

            ForEach(crossingRows.prefix(Self.shown)) { crossing in
                CrossingRow(crossing: crossing)
                    .contentShape(Rectangle())
                    .onTapGesture { onOpenNote(crossing.a.id) }
                    // **The gesture that came in from the cold.** Holding a line
                    // on the canvas was the app's only destructive gesture with
                    // nothing on screen to suggest it existed. Here it is the
                    // same long-press menu every other listed row in the app
                    // already uses to delete.
                    .contextMenu {
                        Button("disconnect", role: .destructive) {
                            disconnect(crossing)
                        }
                    }
                Hairline()
            }

            overflow(crossingRows.count)
        }
    }

    @ViewBuilder
    private var loose: some View {
        if !looseRows.isEmpty {
            GroupHeader(label: "loose")
                .id(Self.looseAnchor)

            ForEach(looseRows.prefix(Self.shown)) { note in
                Button { onOpenNote(note.id) } label: { LooseRow(note: note) }
                    .buttonStyle(PressedRow())
                Hairline()
            }

            overflow(looseRows.count)
        }
    }

    /// How many rows a section shows before it stops.
    ///
    /// A summary that ran to four hundred rows would have stopped being one. The
    /// line below states a fact rather than offering a door — there is nowhere
    /// for it to lead that search and the stream don't already serve better, and
    /// a link to nowhere is worse than a sentence.
    private static let shown = 8

    @ViewBuilder
    private func overflow(_ total: Int) -> some View {
        if total > Self.shown {
            Text("and \(total - Self.shown) more")
                .font(Typography.meta)
                .foregroundStyle(Theme.textAsh)
                .chromeTypeSize()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
    }

    // MARK: Where a tap goes

    private enum Route: Hashable {
        /// A theme's notes, by exemplar id.
        case theme(Int)
        /// That theme's own graph.
        case themeGraph(Int)
        /// Two hops from one note — where `[◇] connections` lands from any tab.
        case noteGraph(Int)
        /// One book alone, by shelf index. `-mapBook` only.
        case bookGraph(Int)
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .theme(let exemplar):
            if let theme = reading.themes.first(where: { $0.exemplar == exemplar }) {
                ThemeDetailView(
                    name: (reading.names[exemplar] ?? .none).text,
                    notes: rows(for: theme.members),
                    books: theme.books.count,
                    onBack: { path.removeLast() },
                    onGraph: { path.append(Route.themeGraph(exemplar)) },
                    onOpenNote: { path.append(Route.noteGraph($0)) }
                )
            }

        case .themeGraph(let exemplar):
            if let theme = reading.themes.first(where: { $0.exemplar == exemplar }) {
                let name = reading.names[exemplar] ?? .none
                GraphView(
                    start: .theme(theme.members),
                    themeLabel: name.isEmpty ? Glyphs.noteID(exemplar) : name.text,
                    onOpenNote: onOpenNote,
                    onOpenBook: onOpenBook,
                    onBack: back
                )
            }

        case .noteGraph(let id):
            GraphView(start: .note(id), onOpenNote: onOpenNote,
                      onOpenBook: onOpenBook, onBack: back)

        case .bookGraph(let index):
            GraphView(start: .book(index), onOpenNote: onOpenNote,
                      onOpenBook: onOpenBook, onBack: back)
        }
    }

    /// Back to the overview from wherever the reader got to. `path` is a
    /// `NavigationPath`, so this pops one level — a theme's graph goes back to
    /// its theme, and a theme goes back to the map.
    private func back() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    // MARK: The reading, off the main actor

    /// Themes, and what each is called. Plain values, so the whole of it crosses
    /// back from a detached task without a model in sight.
    private struct Reading: Equatable {
        var themes: [ThemeEngine.Theme] = []
        /// Keyed by exemplar, which is a theme's identity.
        var names: [Int: ThemeName.Name] = [:]
    }

    /// What would make the themes different. The same shape `LinkWriter`'s
    /// `Queue` uses, and for the same reason: a `.task(id:)` needs something
    /// cheap and `Equatable` to compare, not the library itself.
    ///
    /// A note can't be edited yet. When editing arrives, whatever clears
    /// `embeddedAt` will move this too — the queue is the only thing that would
    /// notice, and so is this.
    /// A note's text on its way to a detached task. `Note` is a model and can't
    /// cross; a string can.
    private struct Passage: Sendable {
        let id: Int
        let text: String
    }

    private struct Signature: Equatable {
        let count: Int
        let embedded: Int
        let latest: Date?
    }

    private var signature: Signature {
        Signature(
            count: notes.count,
            embedded: notes.count { $0.embeddedAt != nil },
            latest: notes.compactMap(\.embeddedAt).max()
        )
    }

    private func read() async {
        let source = notes.compactMap(\.embeddingSource).first
        let shelf = BookShelf.ordered(books)
        let index = Dictionary(
            uniqueKeysWithValues: shelf.enumerated().map { ($1.persistentModelID, $0) }
        )

        // Everything `ThemeEngine` and `ThemeName` need, flattened here — they
        // never see a model, exactly as `AffinityEngine` never does.
        let subjects = notes.map { note in
            ThemeEngine.Subject(
                id: note.shortID,
                vector: source.flatMap { note.vector(from: $0) } ?? [],
                tags: note.tags,
                book: note.book.flatMap { index[$0.persistentModelID] }
            )
        }
        // Just the text, so the expensive part happens off the main actor.
        // `NounPhrases` runs `NLTagger` over every note, which is real work —
        // the rule that took `ImageRenderer` out of `ReviewCard`'s body applies
        // just as well to a linguistic tagger in a view's `.task`.
        let texts = notes.map { Passage(id: $0.shortID, text: $0.text) }

        let found = await Task.detached(priority: .userInitiated) { () -> Reading in
            let grouped = ThemeEngine.reading(subjects)
            let documents = texts.map {
                ThemeName.Document(id: $0.id, phrases: NounPhrases.in($0.text))
            }
            let byID = Dictionary(uniqueKeysWithValues: documents.map { ($0.id, $0) })

            var names: [Int: ThemeName.Name] = [:]
            for theme in grouped.themes {
                let members = theme.members.compactMap { byID[$0] }
                names[theme.exemplar] = ThemeName.name(for: members, in: documents)
            }
            return Reading(themes: grouped.themes, names: names)
        }.value

        // **The pass that was superseded must not write.** `.task(id:)` cancels
        // this one when the signature changes, but the detached work it awaits
        // is not cancellable and finishes anyway — so without this an older
        // reading can land after a newer one and win. The map is the screen that
        // taught this project the rule.
        guard !Task.isCancelled else { return }
        reading = found
        openThemeAtLaunch()
    }

    // MARK: Models → rows
    //
    // Cheap: dictionary lookups over a reading that was already computed off the
    // main actor. The expensive halves — grouping and naming — are in `read()`.

    private var byID: [Int: Note] {
        Dictionary(notes.map { ($0.shortID, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func rows(for ids: [Int]) -> [NoteRowData] {
        let notes = byID
        return ids.compactMap { notes[$0] }.map { NoteRowData($0) }
    }

    private var themeRows: [ThemeRowData] {
        let notes = byID

        return reading.themes.compactMap { theme in
            guard let exemplar = notes[theme.exemplar] else { return nil }
            return ThemeRowData(
                id: theme.exemplar,
                name: (reading.names[theme.exemplar] ?? .none).text,
                count: theme.count,
                books: theme.books.count,
                exemplar: NoteRowData(exemplar)
            )
        }
    }

    /// Connections whose two ends were written from **different** books.
    ///
    /// One pass over the edges, which is what `ties` already costs on the graph
    /// screen — the thing phase 11 forbade was rebuilding an index *per row*,
    /// not reading the store once per redraw.
    private var crossingRows: [CrossingRowData] {
        let shelf = BookShelf.ordered(books)
        let index = Dictionary(
            uniqueKeysWithValues: shelf.enumerated().map { ($1.persistentModelID, $0) }
        )

        var found: [(row: CrossingRowData, score: Double)] = []
        for edge in edges {
            guard !edge.isSuppressed, let from = edge.from, let to = edge.to else { continue }
            let left = from.book.flatMap { index[$0.persistentModelID] }
            let right = to.book.flatMap { index[$0.persistentModelID] }
            guard let left, let right, left != right else { continue }
            found.append(
                (CrossingRowData(a: NoteRowData(from), b: NoteRowData(to)), edge.score)
            )
        }

        // Strongest first, then by the pair, so the list is stable between
        // redraws — the same tie-break `AffinityEngine` and `MapGraph` use.
        found.sort { $0.score != $1.score ? $0.score > $1.score : $0.row.id < $1.row.id }

        // **One appearance per note, and this is a display rule rather than a
        // claim about the data.** The first run of this screen put `n.18` in
        // three consecutive rows with its full text repeated each time — which
        // is the hub behaviour phase 6 wrote down (`n.02` and `n.13` turn up in
        // half the shortlists, and mutual k-NN does not stop it at forty notes)
        // arriving in the UI. A summary that says the same sentence three times
        // has stopped summarising. Every one of those connections still exists,
        // on the graph and on the note itself; this list just shows the
        // strongest crossing each note has, so eight rows are eight ideas.
        var used: Set<Int> = []
        var kept: [CrossingRowData] = []
        for candidate in found {
            let a = candidate.row.a.id
            let b = candidate.row.b.id
            guard !used.contains(a), !used.contains(b) else { continue }
            used.insert(a)
            used.insert(b)
            kept.append(candidate.row)
        }
        return kept
    }

    private var looseRows: [NoteRowData] {
        let grouped = Set(reading.themes.flatMap(\.members))
        return notes
            .filter { !grouped.contains($0.shortID) }
            .sorted { $0.shortID < $1.shortID }
            .map { NoteRowData($0) }
    }

    // MARK: Disconnecting a crossing

    private func disconnect(_ crossing: CrossingRowData) {
        let pair = Set([crossing.a.id, crossing.b.id])
        let match = edges.first { edge in
            guard !edge.isSuppressed, let from = edge.from?.shortID, let to = edge.to?.shortID else {
                return false
            }
            return Set([from, to]) == pair
        }
        guard let match else { return }
        erasing = .connection(match)
    }

    /// A recompute after a suppression, so the degree budget the reader just
    /// freed goes to somebody else instead of sitting unused until the next
    /// capture.
    private func relink() {
        Task { try? await LinkWriter.relink(in: context) }
    }

    // MARK: Launch arguments
    //
    // The simulator can't be tapped, so every state this screen reaches by
    // finger has one. The full table is in `CLAUDE.md`.

    private func openAtLaunch() {
        // Arriving from another tab. Switching tabs rebuilds this view, so the
        // handover happens here rather than in an `onChange` that never fires —
        // the same reason `BooksView` pushes its book in `onAppear`.
        if let arriving = note {
            note = nil
            path.append(Route.noteGraph(arriving))
            return
        }

        let defaults = UserDefaults.standard

        // `-mapNote 7` opens the graph two hops out from `n.07`.
        let hop = defaults.integer(forKey: "mapNote")
        if hop > 0 {
            path.append(Route.noteGraph(hop))
            return
        }

        // `-mapBook "Med"` opens that book alone, matched on any part of the
        // title like `-openBook`.
        if let wanted = defaults.string(forKey: "mapBook"), !wanted.isEmpty,
           let match = BookShelf.ordered(books).firstIndex(where: {
               $0.title.localizedCaseInsensitiveContains(wanted)
           }) {
            path.append(Route.bookGraph(match))
        }
    }

    /// `-mapTheme <id>` opens the theme whose exemplar is `n.<id>`, and
    /// `-mapThemeGraph <id>` opens that theme's graph.
    ///
    /// **These can't live in `onAppear` with the others.** A theme doesn't exist
    /// until the detached grouping pass has finished, so this is called from the
    /// end of `read()` instead — and guarded, because `read()` runs again
    /// whenever the signature changes and a launch argument is a thing that
    /// happens once.
    ///
    /// The id is an **exemplar**, not an index: a theme's identity is the note at
    /// its centre, so `-mapTheme 5` names the same theme however the library
    /// grows around it, which an ordinal wouldn't.
    private func openThemeAtLaunch() {
        guard !launched else { return }
        launched = true

        let defaults = UserDefaults.standard
        let graph = defaults.integer(forKey: "mapThemeGraph")
        if graph > 0, reading.themes.contains(where: { $0.exemplar == graph }) {
            path.append(Route.themeGraph(graph))
            return
        }

        let theme = defaults.integer(forKey: "mapTheme")
        if theme > 0, reading.themes.contains(where: { $0.exemplar == theme }) {
            path.append(Route.theme(theme))
        }
    }
}
