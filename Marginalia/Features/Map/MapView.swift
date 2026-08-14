import SwiftUI
import SwiftData

/// The library as a graph. Nodes are the note ids themselves in mono type,
/// books are bracketed hubs, edges are hairlines, selection inverts to filled
/// ink. No color, no circles — see `docs/design-system.md` under *Map*.
///
/// Three views over one renderer: the whole library, two hops out from one
/// note, and one book on its own. `MapGraph` decides which nodes belong in each
/// and `GraphLayout` decides where they go; both are pure, and this file is the
/// part that reads the store, draws, and listens for a finger.
struct MapView: View {
    /// Tapping through from the panel at the foot. Both routes already exist —
    /// the stream takes a note id, the library takes a book — and the map is
    /// the third thing to use them.
    let onOpenNote: (Int) -> Void
    let onOpenBook: (Book) -> Void

    @Query private var notes: [Note]
    @Query private var books: [Book]
    @Query private var edges: [NoteEdge]

    @Environment(\.modelContext) private var context

    @State private var focus: MapGraph.Focus = launchFocus
    @State private var selection: MapGraph.ID? = launchSelection
    /// Cached positions, recomputed only when the graph changes — the `.task`
    /// below is keyed on the graph itself.
    @State private var placed: [MapGraph.ID: CGPoint] = [:]
    /// What a held edge asked to disconnect, waiting on the confirmation.
    @State private var erasing: Erasure?
    /// Where the finger currently is. A `LongPressGesture` reports *that* it
    /// fired and never *where*, so the location comes off a zero-distance drag
    /// running alongside it — the only way to know which line was held.
    @State private var touch: CGPoint = .zero
    @State private var held = false
    /// The size the graph last drew at. A gesture reports a point in the
    /// canvas's own space, and putting a node back in that space needs the same
    /// box `point(_:in:)` used coming out of it.
    @State private var drawn: CGSize = .zero

    var body: some View {
        VStack(spacing: 0) {
            header

            if web.isEmpty {
                EmptyState(message: emptyMessage)
                Spacer(minLength: 0)
            } else {
                canvas
            }

            panel
        }
        .background(Theme.canvas)
        // Disconnecting frees degree budget on both notes, and the next pass is
        // what hands it to somebody else — the same reason a delete triggers
        // one. Nothing else in the app would notice: `.linking()` watches the
        // note count, and suppressing an edge doesn't change it.
        .confirming($erasing, in: context, after: relink)
        .task(id: plan) { await lay(out: plan) }
        .onAppear { openAtLaunch() }
    }

    // MARK: Chrome

    private var header: some View {
        ScreenHeader(
            style: .title("map"),
            trailing: Glyphs.count(web.nodes.count),
            back: focus == .library ? nil : BackLink(label: "map", action: { show(.library) })
        ) {
            if let caption {
                Text(caption)
                    .font(Typography.source)
                    .foregroundStyle(Theme.textMute)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// What this view is, when it isn't simply the whole library. The plain
    /// global graph says nothing here — the count in the header is the only
    /// thing worth saying about it.
    private var caption: String? {
        switch focus {
        case .library:
            collapsed ? "books only — tap one to open it" : nil
        case .note(let id):
            "two hops from \(Glyphs.noteID(id))"
        case .book(let index):
            shelves.first { $0.index == index }?.title
        }
    }

    private var emptyMessage: String {
        switch focus {
        case .library: "no notes yet — capture the first one"
        case .note(let id): "\(Glyphs.noteID(id)) isn't in the library any more"
        case .book: "no notes from this book yet"
        }
    }

    // MARK: The graph

    private var canvas: some View {
        GeometryReader { geo in
            let box = box(in: geo.size)

            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    for edge in web.edges {
                        guard let from = placed[edge.a], let to = placed[edge.b] else { continue }
                        var line = Path()
                        line.move(to: point(from, in: box))
                        line.addLine(to: point(to, in: box))
                        // The whole interaction vocabulary: a selected node
                        // brings its own lines to full ink and leaves every
                        // other line at the same 12% as every divider in the app.
                        let lit = selection.map(edge.touches) ?? false
                        ctx.stroke(line, with: .color(lit ? Theme.ink : Theme.hairline), lineWidth: 1)
                    }
                }
                .contentShape(Rectangle())
                .gesture(press)

                ForEach(web.nodes) { node in
                    if let at = placed[node.id] {
                        label(for: node)
                            .position(point(at, in: box))
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { drawn = $0 }
        }
    }

    private func label(for node: MapGraph.Node) -> some View {
        let chosen = node.id == selection
        return Text(node.label)
            .font(font(for: node))
            .foregroundStyle(chosen ? Theme.onInk : Theme.ink)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            // Opaque even when it isn't selected, so a label that lands over a
            // line stays readable. There is no shadow doing this work.
            .background(chosen ? Theme.ink : Theme.canvas)
            // Drawn at 13pt, tapped at 44 — the design system's rule, and the
            // reason nodes are views rather than more marks on the canvas.
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .onTapGesture { tap(node) }
    }

    /// Connection count as weight, 400 → 500 → 700. Never as size: node size
    /// would be a visual dimension the rest of the app doesn't have.
    private func font(for node: MapGraph.Node) -> Font {
        if node.isHub { return Typography.mapHub }
        switch node.degree {
        case 0...1: return Typography.mapNode
        case 2...3: return Typography.mapNodeStrong
        default: return Typography.mapNodeHeavy
        }
    }

    /// A little air at the edges. Most of the work of keeping a label on screen
    /// is `GraphLayout`'s — it holds each node back from the walls by its own
    /// width — so this is a backstop rather than the mechanism.
    private let inset = CGSize(width: 16, height: 24)

    private func box(in size: CGSize) -> CGSize {
        CGSize(
            width: max(1, size.width - inset.width * 2),
            height: max(1, size.height - inset.height * 2)
        )
    }

    /// The layout comes back in a box one wide and `aspect` tall, so **both**
    /// coordinates scale by the same number. Multiplying y by the height
    /// instead would stretch the graph back out of shape on the way to the
    /// screen, which is the whole reason the aspect went in.
    private func point(_ unit: CGPoint, in box: CGSize) -> CGPoint {
        CGPoint(
            x: inset.width + unit.x * box.width,
            y: inset.height + unit.y * box.width
        )
    }

    // MARK: Layout

    /// The graph, and the shape of the room it has to go in. Both are reasons
    /// to lay out again and neither is a reason on its own, so they travel
    /// together as the `.task` id.
    private struct Plan: Equatable {
        let web: MapGraph.Web
        /// Rounded, so a point of safe-area drift doesn't relayout the library.
        let aspect: Double
    }

    private var plan: Plan {
        let box = box(in: drawn)
        return Plan(web: web, aspect: (box.height / box.width * 20).rounded() / 20)
    }

    /// Off the main actor, and only when the graph or its room changed — which
    /// is the cache the spec asks for, without a cache.
    private func lay(out plan: Plan) async {
        guard !plan.web.isEmpty, drawn.width > 0 else {
            placed = [:]
            return
        }

        let ids = plan.web.nodes.map(\.id)
        let index = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        let links = plan.web.edges.compactMap { edge -> GraphLayout.Edge? in
            guard let a = index[edge.a], let b = index[edge.b] else { return nil }
            return GraphLayout.Edge(a, b)
        }

        // How much room each label needs, relative to a note id. `n.05` is four
        // characters and one unit; `[Meditations]` is thirteen and three, and
        // gets three times the elbow room. Mono makes this an exact ratio rather
        // than a guess — every character is the same width.
        let sizes = plan.web.nodes.map { Double($0.label.count) / 4 }
        let count = ids.count
        let aspect = plan.aspect
        let layout = await Task.detached(priority: .userInitiated) {
            GraphLayout.positions(count: count, edges: links, aspect: aspect, sizes: sizes)
        }.value

        // **The pass that was superseded must not write.** `.task(id:)` cancels
        // this one when the plan changes, but the detached work it's waiting on
        // is not cancellable and finishes anyway — so without this the old
        // layout can land after the new one and win. It shows up as a graph
        // drawn at somebody else's coordinates: opening one book laid its nine
        // notes out exactly where they had been sitting in the library, in a
        // clump at the bottom of an otherwise empty screen.
        guard !Task.isCancelled else { return }
        placed = Dictionary(uniqueKeysWithValues: zip(ids, layout.positions))
    }

    // MARK: The finger

    /// Tapping a node selects it. Tapping the one already selected is how a hub
    /// opens — a second tap on a book expands it to that book alone, which is
    /// the way back down from the collapsed view.
    private func tap(_ node: MapGraph.Node) {
        guard selection == node.id else {
            selection = node.id
            return
        }
        if case .book(let index) = node.id { show(.book(index)) }
    }

    /// The location comes from the drag; the timing comes from the long press.
    /// Neither gesture can do the job alone, and a tap on a node is caught by
    /// the node itself, which sits above this.
    private var press: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { touch = $0.location }
            .onEnded { value in
                let travelled = value.translation.width.magnitude + value.translation.height.magnitude
                // A tap on nothing clears the selection. A tap that was really
                // the end of a hold does not, or the confirmation would arrive
                // over a panel that had just emptied.
                if !held, travelled < 10 { selection = nil }
                held = false
            }
            .simultaneously(with: LongPressGesture(minimumDuration: 0.5).onEnded { _ in hold() })
    }

    /// Holding a line deletes that connection. Attachments — a note to the book
    /// it came from — are not connections and don't answer: nobody suggested
    /// them and there's nothing to suppress.
    private func hold() {
        guard let line = nearestEdge(to: touch) else { return }
        guard case .note(let a) = line.a, case .note(let b) = line.b else { return }
        guard let edge = stored(between: a, and: b) else { return }
        held = true
        erasing = .connection(edge)
    }

    /// Within a thumb's width of a line, and the nearest one if several qualify.
    /// Attachments never enter the search — they aren't connections and there is
    /// nothing about them to suppress.
    private func nearestEdge(to location: CGPoint) -> MapGraph.Edge? {
        guard drawn.width > 0 else { return nil }
        let box = box(in: drawn)

        var best: MapGraph.Edge?
        var closest = CGFloat.greatestFiniteMagnitude
        for edge in web.edges where !edge.isAttachment {
            guard let a = placed[edge.a], let b = placed[edge.b] else { continue }
            let gap = gap(from: location, to: point(a, in: box), point(b, in: box))
            guard gap <= 22, gap < closest else { continue }
            closest = gap
            best = edge
        }
        return best
    }

    /// How far a point is from a line **segment** — not from the infinite line
    /// it lies on, or holding well past the end of a short edge would delete it.
    private func gap(from location: CGPoint, to a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let squared = dx * dx + dy * dy
        guard squared > 0 else { return hypot(location.x - a.x, location.y - a.y) }

        let along = max(0, min(1, ((location.x - a.x) * dx + (location.y - a.y) * dy) / squared))
        return hypot(location.x - (a.x + along * dx), location.y - (a.y + along * dy))
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

    // MARK: The panel at the foot

    /// A selected node previews what it is, above the tab bar and behind a
    /// hairline. It's the only text on this screen and the only way off it.
    ///
    /// **The hairline belongs to the panel, not to the selection.** A node that
    /// has gone — deleted from another tab while the map still held its id —
    /// would otherwise leave a rule across the screen with nothing under it.
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
                        MarkerButton(title: "\(Glyphs.tabMap) connections", kind: .link) {
                            show(.note(id))
                        }
                    }
                }
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
            }

        case .none:
            EmptyView()
        }
    }

    private func preview<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            Hairline()
            VStack(alignment: .leading, spacing: 10, content: content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
        }
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
    // into the three lists it takes. Cheap enough to do on a redraw — it's a
    // pass over the notes and a pass over the edges — and it keeps the seam in
    // one place rather than threading a view model through.

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
        MapGraph.web(focus, subjects: subjects, shelves: shelves, ties: ties, collapsing: forcedCollapse)
    }

    private var collapsed: Bool {
        web.nodes.allSatisfy(\.isHub) && !web.isEmpty
    }

    // MARK: Launch arguments
    //
    // The simulator can't be tapped or held from the command line, so every
    // state this screen reaches by finger has one. Same device as `-startTab`;
    // the full table is in `CLAUDE.md`.

    /// `-mapNote 7` opens the local view around `n.07`.
    private static var launchFocus: MapGraph.Focus {
        let note = UserDefaults.standard.integer(forKey: "mapNote")
        return note > 0 ? .note(note) : .library
    }

    /// `-mapBook "Med"` opens the expanded hub for that book, matched on any
    /// part of the title like `-openBook`. It waits for `onAppear` rather than
    /// sitting in the state's initial value, because the shelf it has to look
    /// the title up in is a `@Query` and doesn't exist yet.
    ///
    /// `-confirmDelete connection` opens the disconnect sheet over the first
    /// connection on the graph. A line can only be held down on with a finger,
    /// so this is the same device `-confirmDelete book` is on book detail.
    private func openAtLaunch() {
        if let wanted = UserDefaults.standard.string(forKey: "mapBook"),
           !wanted.isEmpty, focus == .library,
           let match = shelf.firstIndex(where: {
               $0.title.localizedCaseInsensitiveContains(wanted)
           }) {
            show(.book(match))
        }

        if UserDefaults.standard.string(forKey: "confirmDelete") == "connection" {
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

    /// `-mapSelect 7` opens the library view with `n.07` selected, which is the
    /// only way to screenshot an inverted node and the panel at the foot.
    private static var launchSelection: MapGraph.ID? {
        let note = UserDefaults.standard.integer(forKey: "mapNote")
        if note > 0 { return .note(note) }
        let chosen = UserDefaults.standard.integer(forKey: "mapSelect")
        return chosen > 0 ? .note(chosen) : nil
    }

    /// `-mapCollapse 1` forces the hub view. The rule is a node count of 150 and
    /// the seed library has forty-six, so this state is otherwise unreachable
    /// without typing a hundred notes first.
    private var forcedCollapse: Bool? {
        UserDefaults.standard.bool(forKey: "mapCollapse") ? true : nil
    }
}
