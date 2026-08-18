import SwiftUI

/// Which lines the canvas draws. Not which lines *exist*.
///
/// Two kinds of line meet on a graph and they are not the same fact. A
/// **connection** is note-to-note, scored on meaning by `AffinityEngine`, and it
/// crosses books freely — same-book is deliberately not boosted, so a line
/// between two books means something. An **attachment** is a note to the book it
/// was written from: structure, not something the app found.
/// `docs/decisions.md` §15 draws both at the same hairline, because there is one
/// line weight in this system, and that stands.
///
/// But undifferentiated they read as one shape — a star per book — so the reader
/// can **subtract** the half that isn't a connection. That adds no vocabulary:
/// no dash, no second weight, no color. It only stops drawing. §19.
nonisolated enum LineFilter {
    case all
    case connections
}

/// The graph itself: nodes, lines, and a finger.
///
/// **It touches no store.** It is handed a built `MapGraph.Web` and reports what
/// was tapped or held; resolving any of that back to a `Note` or a `NoteEdge` is
/// `GraphView`'s job. That seam is what phase 11 wanted and declined to cut on a
/// pass that was already changing the least-verified file in the app — the
/// rebuild is the right pass for it.
///
/// Positions live here because they are geometry: the layout is keyed on the
/// graph *and* the shape of the box, and only this view knows the second.
struct GraphCanvas: View {
    let web: MapGraph.Web
    let lines: LineFilter

    @Binding var selection: MapGraph.ID?

    /// A second tap on the already-selected node. On a book that's the book's
    /// own graph; on a note it's the note.
    var onOpen: (MapGraph.ID) -> Void
    /// A line held down on. Attachments never arrive here — they aren't
    /// connections and there is nothing about them to suppress.
    var onHold: (MapGraph.Edge) -> Void

    /// Cached positions, recomputed only when the graph or its room changes —
    /// which is the cache the spec asks for, without a cache.
    @State private var placed: [MapGraph.ID: CGPoint] = [:]
    /// The size the graph last drew at. A gesture reports a point in the
    /// canvas's own space, and putting a node back in that space needs the same
    /// box `point(_:in:)` used coming out of it.
    @State private var drawn: CGSize = .zero
    /// Where the finger currently is. A `LongPressGesture` reports *that* it
    /// fired and never *where*, so the location comes off a zero-distance drag
    /// running alongside it — the only way to know which line was held.
    @State private var touch: CGPoint = .zero
    @State private var held = false

    var body: some View {
        GeometryReader { geo in
            let box = box(in: geo.size)

            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    for edge in web.edges {
                        // Filtered here, at the stroke, and deliberately not in
                        // `web`. `GraphLayout` goes on being told about every
                        // edge, so nothing moves when the filter changes — and
                        // an attachment is what gathers a book's notes around
                        // its hub in the first place. Take them out of the
                        // layout and the hubs stop hubbing.
                        if lines == .connections && edge.isAttachment { continue }
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
        .task(id: plan) { await lay(out: plan) }
    }

    // MARK: A node

    private func label(for node: MapGraph.Node) -> some View {
        let chosen = node.id == selection
        return Text(node.label)
            .font(font(for: node))
            // **A node is a marker, not prose.** `GraphLayout` is told how much
            // room each label needs in *characters* — mono makes that an exact
            // ratio — so type that keeps growing while the box doesn't turns
            // the graph into a pile of overlapping words. At the largest
            // accessibility size the graph was illegible. Same rule as the tab
            // bar's, and for the same reason.
            .chromeTypeSize()
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

    // MARK: The box

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
        /// Rounded, so a point of safe-area drift doesn't relayout the graph.
        let aspect: Double
    }

    private var plan: Plan {
        let box = box(in: drawn)
        return Plan(web: web, aspect: (box.height / box.width * 20).rounded() / 20)
    }

    /// Off the main actor, and only when the graph or its room changed.
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
        // layout can land after the new one and win. It showed up as a graph
        // drawn at somebody else's coordinates: opening one book laid its nine
        // notes out exactly where they had been sitting in the library, in a
        // clump at the bottom of an otherwise empty screen.
        guard !Task.isCancelled else { return }

        // A relayout means the graph itself changed, or the reader changed what
        // they're looking at. Those are worth showing as a movement rather than
        // a cut: a node that slides to its new place can be followed, and one
        // that teleports can only be re-found.
        withAnimation(.snappy(duration: 0.35)) {
            placed = Dictionary(uniqueKeysWithValues: zip(ids, layout.positions))
        }
    }

    // MARK: The finger

    /// Tapping a node selects it. Tapping the one already selected follows it
    /// through — a hub expands to that book, a note opens.
    private func tap(_ node: MapGraph.Node) {
        guard selection == node.id else {
            selection = node.id
            return
        }
        onOpen(node.id)
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

    private func hold() {
        guard let line = nearestEdge(to: touch) else { return }
        held = true
        onHold(line)
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
}
