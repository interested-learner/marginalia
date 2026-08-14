import Foundation

/// What the map is looking at, and what that turns into on screen.
///
/// **Pure.** Plain values in, nodes and edges out — no `ModelContext`, no
/// `Note`, no `Book`. `MapView` reads the store and hands this the three lists
/// it needs; everything about *which* nodes belong in a view and *which* lines
/// join them is decided here, where a test can ask.
///
/// Three views over one renderer, exactly as the spec has it:
///
/// - **library** — everything, or the book hubs alone once the whole thing stops
///   being legible
/// - **note** — two hops out from one note, capped, which reads clearly at any
///   library size
/// - **book** — one book and what was written from it, which is where a tapped
///   hub expands to
nonisolated enum MapGraph {

    // MARK: The constants

    /// Above this many nodes the library view collapses to book hubs. A graph
    /// is only legible in a band: sparse and sad at twelve nodes, an unreadable
    /// hairball at five thousand. See `docs/decisions.md` §11.
    static let collapseAbove = 150

    /// How far a local view reaches. Two hops is the answer to "what is this
    /// note near", and three is most of the library again.
    static let localHops = 2

    /// And how much of it it will draw. A well-connected note two hops out can
    /// reach thirty-six others under a degree cap of six; the strongest
    /// connections are the ones worth the room.
    static let localLimit = 25

    // MARK: What a node is

    /// A node's identity. Books have no short id of their own, so a hub is
    /// named by its **position in `BookShelf.ordered`** — stable for as long as
    /// the shelf is, which is exactly as long as any one graph lives.
    enum ID: Hashable, Sendable {
        case note(Int)
        case book(Int)
    }

    /// What the map is centred on.
    enum Focus: Hashable, Sendable {
        case library
        case note(Int)
        case book(Int)
    }

    struct Node: Identifiable, Equatable, Sendable {
        let id: ID
        /// `n.07`, or `[Meditations]`.
        let label: String
        /// Connections — not attachments. This is what the design system draws
        /// as weight, and a note's line to the book it came from is structure
        /// rather than something the app found.
        let degree: Int
        let isHub: Bool
    }

    struct Edge: Hashable, Sendable {
        let a: ID
        let b: ID
        /// A note to the book it was written from. Drawn like any other line —
        /// there is one line weight in this system — but it can't be deleted,
        /// because it isn't a connection anybody suggested.
        let isAttachment: Bool

        func touches(_ id: ID) -> Bool { a == id || b == id }
    }

    /// A built graph. Equatable so the view can hang a layout off it and
    /// recompute only when the shape actually changed — which is the whole of
    /// "positions are cached".
    struct Web: Equatable, Sendable {
        var nodes: [Node] = []
        var edges: [Edge] = []

        var isEmpty: Bool { nodes.isEmpty }
    }

    // MARK: What it's built from

    /// A note, reduced to what a map needs of it.
    struct Subject: Equatable, Sendable {
        let id: Int
        /// Index into the shelf, or `nil` for a note whose book has gone.
        let book: Int?

        init(id: Int, book: Int? = nil) {
            self.id = id
            self.book = book
        }
    }

    struct Shelf: Equatable, Sendable {
        let index: Int
        let title: String
    }

    /// One connection the app found, by note id.
    struct Tie: Equatable, Sendable {
        let a: Int
        let b: Int
        let score: Double

        init(_ a: Int, _ b: Int, score: Double = 0) {
            self.a = a
            self.b = b
            self.score = score
        }

        func contains(_ id: Int) -> Bool { a == id || b == id }
        func other(_ id: Int) -> Int { id == a ? b : a }
    }

    // MARK: The builder

    /// `collapsing` overrides the node-count rule — `-mapCollapse 1` is the only
    /// way to see the hub view without a library of two hundred notes, the same
    /// device as `-tinyLibrary` at the other end of the range.
    static func web(
        _ focus: Focus,
        subjects: [Subject],
        shelves: [Shelf],
        ties: [Tie],
        collapsing: Bool? = nil
    ) -> Web {
        switch focus {
        case .library:
            let collapse = collapsing ?? (subjects.count + occupied(shelves, subjects).count > collapseAbove)
            return collapse
                ? hubs(subjects: subjects, shelves: shelves, ties: ties)
                : full(subjects: subjects, shelves: shelves, ties: ties)

        case .note(let id):
            return full(subjects: neighbourhood(of: id, subjects: subjects, ties: ties),
                        shelves: shelves,
                        ties: ties)

        case .book(let index):
            return full(subjects: subjects.filter { $0.book == index },
                        shelves: shelves.filter { $0.index == index },
                        ties: ties)
        }
    }

    // MARK: Every note, and the books they hang off

    /// Notes as nodes, books as hubs, connections and attachments as lines.
    ///
    /// Ties are kept only where **both** ends are on screen, which is what makes
    /// this the one builder behind all three views: a local view is this over a
    /// smaller set of notes, and so is an expanded book.
    private static func full(subjects: [Subject], shelves: [Shelf], ties: [Tie]) -> Web {
        let present = Set(subjects.map(\.id))
        let kept = ties.filter { $0.a != $0.b && present.contains($0.a) && present.contains($0.b) }

        var degree: [Int: Int] = [:]
        for tie in kept {
            degree[tie.a, default: 0] += 1
            degree[tie.b, default: 0] += 1
        }

        var web = Web()

        for subject in subjects.sorted(by: { $0.id < $1.id }) {
            web.nodes.append(
                Node(
                    id: .note(subject.id),
                    label: Glyphs.noteID(subject.id),
                    degree: degree[subject.id] ?? 0,
                    isHub: false
                )
            )
        }

        // Only books something on screen was written from, and only ones still
        // on the shelf. An empty book drawn as a lonely bracket says nothing
        // about the library's shape, and a line to a hub that was never drawn
        // is a line to nowhere.
        let shown = Set(subjects.compactMap(\.book)).intersection(shelves.map(\.index))
        for shelf in shelves.sorted(by: { $0.index < $1.index }) where shown.contains(shelf.index) {
            web.nodes.append(
                Node(id: .book(shelf.index), label: Glyphs.bookHub(shelf.title), degree: 0, isHub: true)
            )
        }

        for tie in kept.sorted(by: strongestFirst) {
            web.edges.append(Edge(a: .note(tie.a), b: .note(tie.b), isAttachment: false))
        }
        for subject in subjects.sorted(by: { $0.id < $1.id }) {
            guard let book = subject.book, shown.contains(book) else { continue }
            web.edges.append(Edge(a: .note(subject.id), b: .book(book), isAttachment: true))
        }

        return web
    }

    // MARK: The hub view

    /// The library once it stops fitting: book hubs alone, joined where a
    /// connection crosses between them.
    ///
    /// The answer to the hairball, and it has to exist before the map ships
    /// rather than after — `docs/decisions.md` §11.
    private static func hubs(subjects: [Subject], shelves: [Shelf], ties: [Tie]) -> Web {
        let shelf = Dictionary(subjects.compactMap { subject in
            subject.book.map { (subject.id, $0) }
        }, uniquingKeysWith: { first, _ in first })

        var crossings: Set<Edge> = []
        for tie in ties {
            guard let left = shelf[tie.a], let right = shelf[tie.b], left != right else { continue }
            crossings.insert(Edge(a: .book(min(left, right)), b: .book(max(left, right)), isAttachment: false))
        }

        var degree: [ID: Int] = [:]
        for edge in crossings {
            degree[edge.a, default: 0] += 1
            degree[edge.b, default: 0] += 1
        }

        var web = Web()
        for shelf in occupied(shelves, subjects) {
            web.nodes.append(
                Node(
                    id: .book(shelf.index),
                    label: Glyphs.bookHub(shelf.title),
                    degree: degree[.book(shelf.index)] ?? 0,
                    isHub: true
                )
            )
        }
        web.edges = crossings.sorted { left, right in
            order(left.a) == order(right.a) ? order(left.b) < order(right.b) : order(left.a) < order(right.a)
        }
        return web
    }

    // MARK: The local view

    /// Two hops out from one note, strongest connections first, capped.
    ///
    /// Books are **not** walked through. A hop through a hub would pull in every
    /// note in the book and the view would stop being local — hubs come back at
    /// the end, attached to whatever notes were actually reached.
    private static func neighbourhood(of id: Int, subjects: [Subject], ties: [Tie]) -> [Subject] {
        let known = Dictionary(subjects.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        guard let start = known[id] else { return [] }

        var reached: [Subject] = [start]
        var seen: Set<Int> = [id]
        var frontier: [Int] = [id]

        for _ in 0..<localHops {
            guard reached.count < localLimit else { break }
            var next: [Int] = []
            let outward = ties
                .filter { tie in frontier.contains(where: tie.contains) }
                .sorted(by: strongestFirst)

            for tie in outward where reached.count < localLimit {
                for end in [tie.a, tie.b]
                where !seen.contains(end) && reached.count < localLimit {
                    guard let subject = known[end] else { continue }
                    seen.insert(end)
                    reached.append(subject)
                    next.append(end)
                }
            }
            guard !next.isEmpty else { break }
            frontier = next
        }

        return reached
    }

    // MARK: Small shared rules

    /// Books something was actually written from, in shelf order.
    private static func occupied(_ shelves: [Shelf], _ subjects: [Subject]) -> [Shelf] {
        let shown = Set(subjects.compactMap(\.book))
        return shelves.filter { shown.contains($0.index) }.sorted { $0.index < $1.index }
    }

    /// Ties break on the note ids, so a graph built twice comes out the same
    /// way twice — the same rule `AffinityEngine` sorts its links by, and for
    /// the same reason.
    private static func strongestFirst(_ left: Tie, _ right: Tie) -> Bool {
        if left.score != right.score { return left.score > right.score }
        if left.a != right.a { return left.a < right.a }
        return left.b < right.b
    }

    private static func order(_ id: ID) -> Int {
        switch id {
        case .note(let value): value
        case .book(let value): value
        }
    }
}
