import SwiftUI
import SwiftData

/// The graph, one level down from the map's overview.
///
/// **Every view it can show is bounded** — one theme's notes, two hops from one
/// note, or one book. The whole-library canvas and the book-hub collapse came
/// out in `docs/decisions.md` §20: a canvas of forty-six opaque handles was a
/// picture nobody could read, and no amount of drawing was going to fix it.
///
/// This is the half that touches the store. `GraphCanvas` is handed a built
/// graph and hands back what was tapped or held; turning that into a `Note`, a
/// `Book` or a `NoteEdge` happens here.
struct GraphView: View {
    /// What the reader arrived looking at.
    let start: MapGraph.Focus
    /// What to call it, when the focus can't say for itself. A theme's name is
    /// the overview's to know, not this file's.
    var themeLabel: String = ""

    let onOpenNote: (Int) -> Void
    let onOpenBook: (Book) -> Void
    /// Back to the overview. **Always the overview**, even when the panel has
    /// narrowed the view in place — one label may only mean one thing, and the
    /// label says `map`.
    let onBack: () -> Void

    @Query private var notes: [Note]
    @Query private var books: [Book]
    @Query private var edges: [NoteEdge]

    @Environment(\.modelContext) private var context

    /// Held rather than taken straight from `start`, because the panel's
    /// `[◇] connections` and `[◇] only this book` narrow the view **in place**
    /// rather than pushing another screen — one back link is enough on a screen
    /// whose whole job is looking around.
    @State private var focus: MapGraph.Focus
    @State private var selection: MapGraph.ID?
    @State private var lines: LineFilter = launchLines
    /// What a held line asked to disconnect, waiting on the confirmation.
    @State private var erasing: Erasure?

    init(
        start: MapGraph.Focus,
        themeLabel: String = "",
        onOpenNote: @escaping (Int) -> Void,
        onOpenBook: @escaping (Book) -> Void,
        onBack: @escaping () -> Void
    ) {
        self.start = start
        self.themeLabel = themeLabel
        self.onOpenNote = onOpenNote
        self.onOpenBook = onOpenBook
        self.onBack = onBack
        _focus = State(initialValue: start)
        _selection = State(initialValue: Self.launchSelection(for: start))
    }

    /// The height of the foot, whatever is in it.
    ///
    /// **Constant, and that is the fix for the jolt.** The panel used to be an
    /// `EmptyView` until something was selected, so a tap took ~120pt away from
    /// the canvas — which changed the aspect, which re-ran the entire
    /// force-directed layout, which moved every node on screen. Two notes with
    /// different-length previews reshuffled it differently. None of that was a
    /// layout bug; the layout was being asked a new question every time.
    ///
    /// Grows with the reader's type and then stops, like the type inside it.
    /// Uncapped at the accessibility sizes it took roughly three quarters of the
    /// screen and left the graph a strip: a panel that previews the thing you
    /// tapped cannot be bigger than the thing you tapped it in.
    @ScaledMetric private var footHeight: CGFloat = 202
    private let footCeiling: CGFloat = 300

    var body: some View {
        VStack(spacing: 0) {
            header

            if web.isEmpty {
                EmptyState(message: emptyMessage)
                Spacer(minLength: 0)
            } else {
                lineFilter
                GraphCanvas(
                    web: web,
                    lines: lines,
                    selection: $selection,
                    onOpen: open,
                    onHold: disconnect
                )
            }

            foot
        }
        .background(Theme.canvas)
        // Disconnecting frees degree budget on both notes, and the next pass is
        // what hands it to somebody else — the same reason a delete triggers
        // one. Nothing else would notice: `.linking()` watches the note count,
        // and suppressing an edge doesn't change it.
        .confirming($erasing, in: context, after: relink)
        .onAppear(perform: openAtLaunch)
    }

    // MARK: Chrome

    private var header: some View {
        ScreenHeader(
            style: .title("map"),
            trailing: Glyphs.count(web.nodes.count),
            back: BackLink(label: "map", action: onBack)
        ) {
            if !caption.isEmpty {
                Text(caption)
                    .font(Typography.source)
                    .foregroundStyle(Theme.textMute)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// What this view is. Every focus is a narrowing now, so unlike the old
    /// library view there is always something worth saying.
    private var caption: String {
        switch focus {
        case .theme:
            themeLabel
        case .note(let id):
            "two hops from \(Glyphs.noteID(id))"
        case .book(let index):
            shelves.first { $0.index == index }?.title ?? ""
        }
    }

    /// The one control on this screen, and the same chip row the library and
    /// the stream already use for their filters.
    ///
    /// **It never appears or disappears.** It sits inside the branch that draws
    /// a graph, so it exists for exactly as long as any one layout does. A row
    /// that came and went would change the canvas's height, which changes the
    /// aspect `GraphLayout` is told, which re-lays out every node — the loop
    /// phase 11 took off this screen and is not putting back.
    private var lineFilter: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TagChip(label: "all lines", selected: lines == .all) { lines = .all }
                TagChip(label: "connections only", selected: lines == .connections) {
                    lines = .connections
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Hairline()
        }
        .chromeTypeSize()
    }

    private var emptyMessage: String {
        switch focus {
        case .theme: "nothing left of this theme"
        case .note(let id): "\(Glyphs.noteID(id)) isn't in the library any more"
        case .book: "no notes from this book yet"
        }
    }

    // MARK: What the canvas reports

    private func open(_ id: MapGraph.ID) {
        switch id {
        case .book(let index): show(.book(index))
        case .note(let note): onOpenNote(note)
        }
    }

    /// Holding a line deletes that connection. Attachments never reach here —
    /// `GraphCanvas` won't offer one, because nobody suggested it and there is
    /// nothing to suppress.
    private func disconnect(_ line: MapGraph.Edge) {
        guard case .note(let a) = line.a, case .note(let b) = line.b else { return }
        guard let edge = stored(between: a, and: b) else { return }
        erasing = .connection(edge)
    }

    private func stored(between a: Int, and b: Int) -> NoteEdge? {
        edges.first { edge in
            guard !edge.isSuppressed, let from = edge.from?.shortID, let to = edge.to?.shortID else {
                return false
            }
            return Set([from, to]) == Set([a, b])
        }
    }

    private func show(_ next: MapGraph.Focus) {
        focus = next
        selection = nil
        if case .note(let id) = next { selection = .note(id) }
    }

    /// A recompute after a suppression, so the degree budget the reader just
    /// freed goes to somebody else instead of sitting unused until the next
    /// capture.
    private func relink() {
        Task { try? await LinkWriter.relink(in: context) }
    }

    // MARK: The foot

    /// The foot, and **it is always there.**
    ///
    /// It carries the selected node's preview when there is one and a line about
    /// what the screen does when there isn't. The second half is not filler:
    /// this is the most gestural screen in the app and, until phase 11, the only
    /// one that never said so. Selecting a node, expanding a book and holding a
    /// line to disconnect it were three interactions with no affordance between
    /// them — the reader who found the second one found it by accident.
    private var foot: some View {
        VStack(spacing: 0) {
            Hairline()

            panel
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
        }
        .frame(height: min(footHeight, footCeiling))
        .background(Theme.canvas)
        // The note itself is read by tapping `→ open note`, on a surface that
        // has no ceiling — so this one is a signpost, and signposts stop growing.
        .chromeTypeSize()
    }

    @ViewBuilder
    private var panel: some View {
        switch selection {
        case .note(let id):
            if let note = notes.first(where: { $0.shortID == id }) {
                preview {
                    notePreview(NoteRowData(note))
                    actions {
                        MarkerButton(title: "\(Glyphs.forward) open note", kind: .link) {
                            onOpenNote(id)
                        }
                        if focus != .note(id) {
                            MarkerButton(title: "\(Glyphs.tabMap) connections", kind: .link) {
                                show(.note(id))
                            }
                        }
                    }
                }
            } else {
                hint
            }

        case .book(let index):
            if let book = book(at: index) {
                preview {
                    bookPreview(book)
                    actions {
                        MarkerButton(title: "\(Glyphs.forward) open book", kind: .link) {
                            onOpenBook(book)
                        }
                        if focus != .book(index) {
                            MarkerButton(title: "\(Glyphs.tabMap) only this book", kind: .link) {
                                show(.book(index))
                            }
                        }
                    }
                }
            } else {
                hint
            }

        case .none:
            hint
        }
    }

    /// What the screen does, said once, where the preview will be.
    ///
    /// Two sentences at rest and no more: the tap is how anyone gets anywhere
    /// from here, and the hold is the app's only remaining destructive gesture
    /// on a canvas. A third appears **only while the lines are filtered**, and
    /// it isn't a fourth thing to learn — it describes a state the reader chose,
    /// and says the one thing this screen never said: that a line to a book was
    /// never a connection. Nothing moves when it appears; `foot` is a fixed
    /// frame.
    private var hint: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("tap a note to preview it, again to open it")
                .foregroundStyle(Theme.textMute)
            Text("hold a line to disconnect two notes")
                .foregroundStyle(Theme.textAsh)
            if lines == .connections {
                Text("book lines hidden — every line is a connection the app found")
                    .foregroundStyle(Theme.textAsh)
            }
        }
        .font(Typography.source)
        .fixedSize(horizontal: false, vertical: true)
        // Centred in the room the preview will take, like every other empty
        // state in the app. Pinned to the top it read as a preview that had
        // failed to load the rest of itself.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func preview<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Link buttons, never filled ones — the same row the review card uses.
    private func actions<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 20) {
            content()
            Spacer(minLength: 0)
        }
    }

    private func notePreview(_ row: NoteRowData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(row.idLabel) · \(row.meta)")
                .font(Typography.meta)
                .foregroundStyle(Theme.textAsh)
            Text(row.text)
                .font(Typography.noteBody)
                .lineSpacing(Typography.bodyLeading)
                .foregroundStyle(row.isQuote ? Theme.ink : Theme.textBody)
                .lineLimit(3)
            if !row.source.isEmpty {
                Text(row.source)
                    .font(Typography.source)
                    .foregroundStyle(Theme.textMute)
                    .lineLimit(1)
            }
        }
    }

    /// The hub carries one word of the title on the graph; this is where the
    /// whole of it is.
    private func bookPreview(_ book: Book) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(book.status.marker) \(book.title)")
                .font(Typography.bookTitle)
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
            Text(byline(for: book))
                .font(Typography.source)
                .foregroundStyle(Theme.textMute)
                .lineLimit(1)
        }
    }

    private func byline(for book: Book) -> String {
        let count = "\(book.noteCount) \(book.noteCount == 1 ? "note" : "notes")"
        return book.author.isEmpty
            ? "\(book.status.label) · \(count)"
            : "\(book.author) · \(book.status.label) · \(count)"
    }

    // MARK: The library, as plain values
    //
    // `MapGraph` never sees a model, so this is where the store is flattened
    // into the three lists it takes.

    private var shelf: [Book] { BookShelf.ordered(books) }

    private var shelves: [MapGraph.Shelf] {
        shelf.enumerated().map { MapGraph.Shelf(index: $0.offset, title: $0.element.title) }
    }

    private func book(at index: Int) -> Book? {
        shelf.indices.contains(index) ? shelf[index] : nil
    }

    private var subjects: [MapGraph.Subject] {
        let index = Dictionary(
            uniqueKeysWithValues: shelf.enumerated().map { ($1.persistentModelID, $0) }
        )
        return notes.map { note in
            MapGraph.Subject(id: note.shortID, book: note.book.flatMap { index[$0.persistentModelID] })
        }
    }

    /// Edges as stored → ties, both ends, suppressed ones dropped. The same
    /// reading `ConnectionIndex` gives the stream and book detail.
    private var ties: [MapGraph.Tie] {
        edges.compactMap { edge in
            guard !edge.isSuppressed, let from = edge.from, let to = edge.to else { return nil }
            return MapGraph.Tie(from.shortID, to.shortID, score: edge.score)
        }
    }

    private var web: MapGraph.Web {
        MapGraph.web(focus, subjects: subjects, shelves: shelves, ties: ties)
    }

    // MARK: Launch arguments
    //
    // The simulator can't be tapped or held from the command line, so every
    // state this screen reaches by finger has one. The full table is in
    // `CLAUDE.md`.

    /// `-mapSelect 7` opens with `n.07` selected, which is the only way to
    /// screenshot an inverted node and the panel at the foot. A `-mapNote` view
    /// selects the note it is centred on, so it arrives already showing one.
    private static func launchSelection(for focus: MapGraph.Focus) -> MapGraph.ID? {
        if case .note(let id) = focus { return .note(id) }
        let chosen = UserDefaults.standard.integer(forKey: "mapSelect")
        return chosen > 0 ? .note(chosen) : nil
    }

    /// `-mapLines connections` opens with the book attachments subtracted, which
    /// is the only way to screenshot the filtered graph and the third line of
    /// the foot's hint. A chip can only be tapped with a finger.
    private static var launchLines: LineFilter {
        UserDefaults.standard.string(forKey: "mapLines") == "connections" ? .connections : .all
    }

    /// `-confirmDelete connection` opens the disconnect sheet over the first
    /// connection on the graph. A line can only be held down on with a finger,
    /// so this is the same device `-confirmDelete book` is on book detail.
    private func openAtLaunch() {
        guard UserDefaults.standard.string(forKey: "confirmDelete") == "connection" else { return }
        erasing = web.edges
            .lazy
            .filter { !$0.isAttachment }
            .compactMap { edge -> NoteEdge? in
                guard case .note(let a) = edge.a, case .note(let b) = edge.b else { return nil }
                return stored(between: a, and: b)
            }
            .first
            .map(Erasure.connection)
    }
}
